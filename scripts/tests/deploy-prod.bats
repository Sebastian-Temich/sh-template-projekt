#!/usr/bin/env bats
# Testy scripts/deploy-prod.sh na atrapach gh, supabase, vercel, curl i docker.
# Uruchomienie: bats scripts/tests/deploy-prod.bats

SKRYPT="$BATS_TEST_DIRNAME/../deploy-prod.sh"

atrapa() {
  printf '#!/bin/bash\n%s\n' "$2" >"$ATRAPY/$1"
  chmod +x "$ATRAPY/$1"
}

setup() {
  ATRAPY="$BATS_TEST_TMPDIR/bin"
  LOG="$BATS_TEST_TMPDIR/log"
  mkdir -p "$ATRAPY" "$BATS_TEST_TMPDIR/home"
  : >"$LOG"
  export LOG

  atrapa gh 'echo "${CI_WYNIK-success}"'
  atrapa docker 'exit 0'
  atrapa curl 'echo "curl $*" >>"$LOG"; exit "${CURL_RC:-0}"'
  atrapa supabase 'echo "supabase $*" >>"$LOG"
case "$*" in *--role-only*) exit "${DUMP_RC:-0}" ;; esac
exit 0'
  atrapa vercel 'echo "vercel $*" >>"$LOG"
case "$1" in
  list)
    if [ -n "${BRAK_PREVIEW:-}" ]; then
      echo "{\"deployments\":[]}"
    else
      echo "{\"deployments\":[{\"url\":\"kandydat.vercel.app\"}]}"
    fi
    ;;
  inspect) echo "{\"url\":\"poprzedni.vercel.app\"}" ;;
  promote) exit "${PROMOTE_RC:-0}" ;;
esac
exit 0'

  export HOME="$BATS_TEST_TMPDIR/home"
  # Testy nie mogą widzieć prawdziwego /Users/Shared/sh na serwerze.
  export SH_DIR="$BATS_TEST_TMPDIR/sh"
  export PATH="$ATRAPY:$PATH"
  export VERCEL_TOKEN=token-vercel VERCEL_ORG_ID=org VERCEL_PROJECT_ID=projekt
  export PROD_DB_URL=postgresql://prod-sekret PROD_DOMAIN=example.com
  export STAGING_DB_URL=postgresql://staging-sekret STAGING_DOMAIN=staging.example.com
  unset SMOKE_PATH BACKUP_DIR CI_WYNIK CURL_RC BRAK_PREVIEW PROMOTE_RC DUMP_RC

  git init -q --bare "$BATS_TEST_TMPDIR/origin.git"
  git clone -q "$BATS_TEST_TMPDIR/origin.git" "$BATS_TEST_TMPDIR/repo" 2>/dev/null
  cd "$BATS_TEST_TMPDIR/repo"
  git switch -q -c main
  cp "$SKRYPT" deploy-prod.sh
  git add .
  git -c user.name=test -c user.email=test@example.com commit -qm start
  git push -q origin main
  git tag v1.2.3
  git push -q origin v1.2.3
}

# Pełny przebieg z potwierdzeniem w prawdziwym terminalu.
z_potwierdzeniem() {
  command -v expect >/dev/null || skip "brak expect"
  # Sandbox Claude Code nie daje pseudoterminala („The system has no more ptys”): test sprawdza CI.
  # expect kończy się kodem 0 także po nieudanym spawn, stąd catch.
  expect -c 'if {[catch {spawn true}]} {exit 1}; expect eof' >/dev/null 2>&1 || skip "brak pty (sandbox), sprawdza CI"
  run expect -c "
    set timeout 30
    log_user 1
    spawn bash deploy-prod.sh $*
    expect \"potwierdzić: \"
    send \"v1.2.3\r\"
    expect eof
    exit [lindex [wait] 3]"
}

# Sam `! polecenie` nie przerywa testu, a `[[ ]]` nie przerywa go w bash 3.2, stąd `nie` i `|| false`.
nie() {
  if "$@"; then
    return 1
  fi
}

kolejnosc() {
  grep -vE 'migration list|--dry-run|^vercel (list|inspect)' "$LOG" | sed -E 's/ .*(--role-only|schema.sql|data.sql).*/ \1/'
}

@test "dry-run: sukces bez zmian stanu" {
  run bash deploy-prod.sh v1.2.3 --dry-run
  [ "$status" -eq 0 ]
  [[ "$output" == *"[dry-run] migracje bazy prod"* ]] || false
  [[ "$output" == *"[dry-run] wdrożenie kandydat.vercel.app na prod"* ]] || false
  [[ "$output" == *"dry-run zakończony"* ]] || false
  nie grep -qE 'db dump|promote|rollback|alias' "$LOG"
  [ -z "$(grep 'supabase db push' "$LOG" | grep -v -- '--dry-run')" ]
}

@test "dry-run: brak zielonego CI" {
  CI_WYNIK=failure run bash deploy-prod.sh v1.2.3 --dry-run
  [ "$status" -eq 1 ]
  [[ "$output" == *"CI na"*"nie jest zielone"* ]] || false
  [ ! -s "$LOG" ]
}

@test "dry-run: brak uruchomienia CI" {
  CI_WYNIK= run bash deploy-prod.sh v1.2.3 --dry-run
  [ "$status" -eq 1 ]
  [[ "$output" == *"wynik: 'brak'"* ]] || false
}

@test "dry-run: brak tagu" {
  run bash deploy-prod.sh v9.9.9 --dry-run
  [ "$status" -eq 1 ]
  [[ "$output" == *"tagu v9.9.9 nie ma na origin"* ]] || false
  [ ! -s "$LOG" ]
}

@test "dry-run: tag spoza semver" {
  run bash deploy-prod.sh wydanie --dry-run
  [ "$status" -eq 1 ]
  [[ "$output" == *"nie jest wersją semver"* ]] || false
}

@test "dry-run: blad smoke testu pokazuje rollback" {
  CURL_RC=22 run bash deploy-prod.sh v1.2.3 --dry-run
  [ "$status" -eq 1 ]
  [[ "$output" == *"smoke test nie przeszedł"* ]] || false
  [[ "$output" == *"[dry-run] rollback aplikacji do poprzedni.vercel.app"* ]] || false
  nie grep -q rollback "$LOG"
}

@test "brak wdrozenia preview dla commita przerywa przed baza" {
  BRAK_PREVIEW=1 run bash deploy-prod.sh v1.2.3 --dry-run
  [ "$status" -eq 1 ]
  [[ "$output" == *"brak gotowego wdrożenia preview dla $(git rev-parse HEAD)"* ]] || false
  grep -q "vercel list --environment preview --status READY --meta githubCommitSha=$(git rev-parse HEAD)" "$LOG"
  nie grep -qE 'supabase|promote' "$LOG"
}

@test "dry-run: wyjscie nie ujawnia poswiadczen" {
  CURL_RC=22 run bash deploy-prod.sh v1.2.3 --dry-run
  [[ "$output" != *"prod-sekret"* ]] || false
  [[ "$output" != *"token-vercel"* ]] || false
}

@test "bez terminala nic nie wdraza" {
  run bash deploy-prod.sh v1.2.3
  [ "$status" -eq 1 ]
  [[ "$output" == *"potwierdzenie wymaga terminala"* ]] || false
  nie grep -qE 'db dump|promote' "$LOG"
}

@test "na serwerze agentow odmawia" {
  mkdir -p "$SH_DIR/sh-system"
  run bash deploy-prod.sh v1.2.3 --dry-run
  [ "$status" -eq 1 ]
  [[ "$output" == *"serwer agentów"* ]] || false
}

@test "na serwerze agentow z dawnym ~/sh odmawia" {
  mkdir -p "$HOME/sh/sh-system"
  run bash deploy-prod.sh v1.2.3 --dry-run
  [ "$status" -eq 1 ]
  [[ "$output" == *"serwer agentów"* ]] || false
}

@test "prod: kolejnosc backup, migracje, promocja, smoke" {
  z_potwierdzeniem v1.2.3
  [ "$status" -eq 0 ]
  [[ "$output" == *"wdrożono v1.2.3 na prod"* ]] || false
  [[ "$output" != *"prod-sekret"* ]] || false
  [[ "$output" != *"token-vercel"* ]] || false
  run kolejnosc
  [ "${lines[0]}" = "supabase --role-only" ]
  [ "${lines[1]}" = "supabase schema.sql" ]
  [ "${lines[2]}" = "supabase data.sql" ]
  [[ "${lines[3]}" == "supabase db push"*"--yes" ]] || false
  [[ "${lines[4]}" == "vercel promote kandydat.vercel.app --yes"* ]] || false
  [[ "${lines[5]}" == "curl "*"https://example.com/" ]] || false
  [ "${#lines[@]}" -eq 6 ]
}

@test "prod: blad smoke testu wykonuje rollback do poprzedniej wersji" {
  export CURL_RC=22
  z_potwierdzeniem v1.2.3
  [ "$status" -eq 1 ]
  grep -q 'vercel rollback poprzedni.vercel.app --yes' "$LOG"
  [[ "$output" == *"Rollback bazy"* ]] || false
}

@test "prod: nieudany zrzut bazy zatrzymuje wdrozenie przed migracjami" {
  export DUMP_RC=1
  z_potwierdzeniem v1.2.3
  [ "$status" -eq 1 ]
  [[ "$output" == *"backup się nie udał"* ]] || false
  nie grep -qE 'schema.sql|data.sql|promote' "$LOG"
  [ -z "$(grep 'supabase db push' "$LOG" | grep -v -- '--dry-run')" ]
}

@test "prod: awaria Vercela po migracjach podaje sposob ponowienia" {
  export PROMOTE_RC=1
  z_potwierdzeniem v1.2.3
  [ "$status" -eq 1 ]
  grep -q 'supabase db push --db-url postgresql://prod-sekret --yes' "$LOG"
  [[ "$output" == *"baza zaktualizowana"* ]] || false
  [[ "$output" == *"stara aplikacja działa dzięki migracjom zgodnym wstecz"* ]] || false
  [[ "$output" == *"scripts/deploy-prod.sh v1.2.3 --tylko-aplikacja"* ]] || false
  nie grep -qE '^curl|vercel rollback' "$LOG"
}

@test "prod: --tylko-aplikacja pomija backup i migracje" {
  z_potwierdzeniem v1.2.3 --tylko-aplikacja
  [ "$status" -eq 0 ]
  [[ "$output" == *"wdrożono v1.2.3 na prod"* ]] || false
  grep -q 'vercel promote kandydat.vercel.app --yes' "$LOG"
  grep -q 'supabase migration list' "$LOG"
  grep -q '^curl ' "$LOG"
  nie grep -q 'db dump' "$LOG"
  [ -z "$(grep 'supabase db push' "$LOG" | grep -v -- '--dry-run')" ]
}

@test "prod: --tylko-aplikacja cofa aplikacje po bledzie smoke testu" {
  export CURL_RC=22
  z_potwierdzeniem v1.2.3 --tylko-aplikacja
  [ "$status" -eq 1 ]
  grep -q 'vercel rollback poprzedni.vercel.app --yes' "$LOG"
  nie grep -q 'db dump' "$LOG"
}

@test "dry-run: --tylko-aplikacja opisuje tylko krok aplikacji" {
  run bash deploy-prod.sh v1.2.3 --dry-run --tylko-aplikacja
  [ "$status" -eq 0 ]
  [[ "$output" == *"[dry-run] wdrożenie kandydat.vercel.app na prod"* ]] || false
  [[ "$output" != *"[dry-run] backup"* ]] || false
  [[ "$output" != *"[dry-run] migracje"* ]] || false
}

@test "staging: awaria Vercela podaje ponowienie na stagingu" {
  atrapa vercel 'echo "vercel $*" >>"$LOG"
case "$1" in
  list) echo "{\"deployments\":[{\"url\":\"kandydat.vercel.app\"}]}" ;;
  inspect) echo "{\"url\":\"poprzedni.vercel.app\"}" ;;
  alias) exit 1 ;;
esac
exit 0'
  z_potwierdzeniem v1.2.3 --target staging
  [ "$status" -eq 1 ]
  [[ "$output" == *"v1.2.3 --tylko-aplikacja --target staging"* ]] || false
}

@test "staging: proba rollbacku przepina domene z powrotem" {
  export CURL_RC=22
  z_potwierdzeniem v1.2.3 --target staging
  [ "$status" -eq 1 ]
  grep -q 'vercel alias set kandydat.vercel.app staging.example.com' "$LOG"
  grep -q 'vercel alias set poprzedni.vercel.app staging.example.com' "$LOG"
  grep -q 'supabase db push --db-url postgresql://staging-sekret --yes' "$LOG"
  nie grep -qE 'prod-sekret|vercel (promote|rollback)' "$LOG"
}
