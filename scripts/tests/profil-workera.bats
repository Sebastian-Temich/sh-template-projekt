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

# Wynik: allow, deny albo brak (pyta, a w trybie dontAsk odmawia) dla jednej komendy Bash, bez
# potoków i && (Claude Code sprawdza każdą część osobno). * pasuje do dowolnego ciągu w każdym
# miejscu wzorca, a końcowe " *" także do samej komendy ("X *" pasuje do "X").
bash_regula() {
  local cmd="$1" r w
  for r in deny allow; do
    while IFS= read -r w; do
      # shellcheck disable=SC2053
      if [[ "$cmd" == $w ]] || { [[ "$w" == *" *" ]] && [ "$cmd" = "${w% \*}" ]; }; then
        echo "$r"
        return
      fi
    done < <(jq -r --arg r "$r" '.permissions[$r][] | select(startswith("Bash(")) | ltrimstr("Bash(") | rtrimstr(")")' "$PROFIL")
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

# Polecenia odrzucone w sh-dryrun#1 (2026-11-04), rozbite na części jak w Claude Code.
@test "polecenia z odmow w sh-dryrun#1 dozwolone" {
  for c in "git show --stat 6c67d48" "head -80" "gh pr list --head task/1-szkielet" \
    "pnpm install --frozen-lockfile" "pnpm lint" "ls dist" "rm -rf dist" \
    "git ls-remote --tags https://github.com/actions/setup-node" "tail -5" \
    'grep -rn "uses:" .github/workflows/' "readlink -f /usr/local/bin/pnpm" "command -v pnpm" \
    "bash scripts/check-dod.sh" 'echo "exit=0"' "gitleaks git --redact --no-banner ." "git status --short" \
    "git commit -q -am opis" "git push -q origin task/1-szkielet" "gh run list --branch main --workflow CI --limit 3" \
    "gh run watch 123" "bats scripts/tests/sync-status.bats" "npx vitest run" "mkdir -p src/lib" \
    "mv src/a.ts src/b.ts" "cp src/a.ts src/b.ts" "git restore src/a.ts" "git rm src/a.ts"; do
    [ "$(bash_regula "$c")" = allow ] || { echo "nie dozwolone: $c ($(bash_regula "$c"))"; false; }
  done
}

@test "push na main i production, usuwanie galezi i gh api zablokowane" {
  for c in "git push origin main" "git push -q origin HEAD:main" "git push origin task/1:main" \
    "git push origin task/1:refs/heads/main" "git push origin HEAD:production" "git push --force origin task/1" \
    "git push -f origin task/1" "git push origin --delete task/1" "git push origin :task/1" "git push --all origin" \
    "git push --mirror origin" "gh api repos/a/b/releases/latest" "gh pr merge 7" "gh workflow run deploy" \
    "gh secret list" "vercel deploy --prod" "supabase db push" "sudo rm -rf /"; do
    [ "$(bash_regula "$c")" = deny ] || { echo "nie zablokowane: $c ($(bash_regula "$c"))"; false; }
  done
}

@test "rm, mv i cp poza worktree, na plikach wspolnych i .env zablokowane" {
  for c in "rm -rf /" "rm -rf /Users/Shared/sh" "rm -rf ~/x" "rm -rf ../inne" "mv a /tmp/a" "cp ../x ." \
    "rm docs/status.md" "mv docs/decyzje.md x" "cp x docs/06-zadania/index.md" "rm CHANGELOG.md" \
    "cp x .github/workflows/deploy-prod.yml" "rm scripts/deploy-prod.sh" "rm -rf .claude/roles" \
    "cp .env.example .env.local" "rm .env" "head .env.production" "grep KEY .env.prod.local"; do
    [ "$(bash_regula "$c")" = deny ] || { echo "nie zablokowane: $c ($(bash_regula "$c"))"; false; }
  done
}

@test "gh tylko odczyt: brak zgody na edycje PR i issue" {
  for c in "gh pr edit 7 --title x" "gh issue edit 1 --add-label x" "gh issue close 1" "gh run rerun 1" "gh run cancel 1"; do
    [ "$(bash_regula "$c")" != allow ] || { echo "dozwolone: $c"; false; }
  done
}

@test "odczyt: bez ogolnego Read, Glob i Grep; zakres pilnuje hook odczyt-hook.sh" {
  for p in "$PROFIL" "$BATS_TEST_DIRNAME/../../.claude/roles/reviewer/settings.json"; do
    run jq -e '.permissions.allow | (index("Read") // index("Glob") // index("Grep"))' "$p"
    [ "$status" -ne 0 ] || { echo "ogolne Read/Glob/Grep w $p"; false; }
    jq -e '.hooks.PreToolUse[] | select(.matcher == "Read|Glob|Grep")
      | .hooks[] | select(.command == "/Users/Shared/sh/bin/odczyt-hook.sh || exit 2")' "$p" >/dev/null
  done
}
