#!/usr/bin/env bats
# Sprawdzenie profilu .claude/roles/worker/settings.json na atrapie oceny uprawnień Claude Code.
# Atrapa: deny ma pierwszeństwo przed allow; reguły Edit(...) to wzorce gitignore (ocenia je
# git check-ignore), reguły Bash(X *) pasują do "X" i "X ...", a Bash(X) tylko do "X".
# To nie jest Claude Code: potwierdzenie na prawdziwym workerze przy pierwszym dispatchu.
# Uruchomienie: bats scripts/tests/profil-workera.bats

PROFIL="${PROFIL_WORKERA:-$BATS_TEST_DIRNAME/../../.claude/roles/worker/settings.json}"

setup() {
  command -v jq >/dev/null || skip "brak jq"
  REPO="$BATS_TEST_TMPDIR/repo"
  mkdir -p "$REPO/deny" "$REPO/allow"
  for r in deny allow; do
    git init -q "$REPO/$r"
    jq -r --arg r "$r" '.permissions[$r][] | select(startswith("Edit(")) | ltrimstr("Edit(") | rtrimstr(")")' \
      "$PROFIL" >"$REPO/$r/.git/info/exclude"
  done
}

pasuje() { (cd "$REPO/$1" && git check-ignore -q --no-index -- "$2"); }

# Wynik: allow albo deny dla edycji pliku.
edycja() {
  if pasuje deny "$1"; then echo deny; return; fi
  if jq -e '.permissions.allow | index("Edit")' "$PROFIL" >/dev/null || pasuje allow "$1"; then
    echo allow
  else
    echo deny
  fi
}

# Wynik: allow, deny albo brak (pyta, a w trybie dontAsk odmawia) dla komendy Bash.
bash_regula() {
  local cmd="$1" r
  for r in deny allow; do
    if jq -e --arg c "$cmd" --arg r "$r" '.permissions[$r] | map(select(startswith("Bash(")) | ltrimstr("Bash(") | rtrimstr(")"))
      | any(. as $w | if ($w | endswith(" *")) then ($c == ($w | rtrimstr(" *")) or ($c | startswith($w | rtrimstr("*"))))
          else $c == $w end)' \
      "$PROFIL" >/dev/null; then
      echo "$r"
      return
    fi
  done
  echo brak
}

@test "profil to poprawny JSON" {
  jq -e '.permissions.allow and .permissions.deny' "$PROFIL"
}

@test "edycja .env.example dozwolona, także w podkatalogu" {
  [ "$(edycja .env.example)" = allow ]
  [ "$(edycja apps/web/.env.example)" = allow ]
}

@test "edycja .env, .env.local i innych plikow .env* zablokowana" {
  for f in .env .env.local .env.development .env.development.local .env.test .env.e2e .env.production \
    .env.prod.local .env.staging .env.examples .env.example.bak .env.exampl .env.e .envrc .env.x \
    apps/web/.env.local; do
    [ "$(edycja "$f")" = deny ] || { echo "dozwolone: $f"; false; }
  done
}

@test "edycja katalogu supabase dozwolona" {
  for f in supabase/config.toml supabase/migrations/20261102120000_init.sql supabase/seed.sql; do
    [ "$(edycja "$f")" = allow ] || { echo "zablokowane: $f"; false; }
  done
}

@test "pliki wspolne i konfiguracja produkcji nadal zablokowane" {
  for f in docs/status.md docs/decyzje.md docs/06-zadania/index.md CHANGELOG.md \
    .github/workflows/deploy-prod.yml scripts/deploy-prod.sh .claude/roles/worker/settings.json; do
    [ "$(edycja "$f")" = deny ] || { echo "dozwolone: $f"; false; }
  done
}

@test "supabase init dozwolone, link i db push zablokowane" {
  [ "$(bash_regula "supabase init")" = allow ]
  [ "$(bash_regula "supabase init --force")" = allow ]
  [ "$(bash_regula "supabase link --project-ref x")" = deny ]
  [ "$(bash_regula "supabase db push")" = deny ]
  [ "$(bash_regula "supabase initx")" = brak ]
}
