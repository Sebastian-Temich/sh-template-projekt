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

@test "edycja .env.example dozwolona, także w podkatalogu (E-002, E-004)" {
  [ "$(edycja .env.example)" = allow ]
  [ "$(edycja apps/web/.env.example)" = allow ]
}

@test "edycja i odczyt .env z sekretami zablokowane" {
  for f in .env .env.local .env.development .env.development.local .env.test .env.e2e.local .env.production \
    .env.prod.local .env.staging apps/web/.env.local apps/web/.env; do
    [ "$(edycja "$f")" = deny ] || { echo "dozwolone: $f"; false; }
  done
}

@test "bez wzorcow [!x]: Claude Code nie traktuje ich jako negacji (E-002)" {
  ! jq -r '.permissions.deny[]' "$PROFIL" | grep -q '\[!'
}

@test "edycja katalogu supabase i kodu dozwolona" {
  for f in supabase/config.toml supabase/migrations/20261102120000_init.sql src/a.ts e2e/a.spec.ts; do
    [ "$(edycja "$f")" = allow ] || { echo "zablokowane: $f"; false; }
  done
}

@test "pliki wspolne i konfiguracja produkcji zablokowane" {
  for f in docs/Projekt.md docs/historia.md docs/decyzje.md docs/06-zadania/index.md CHANGELOG.md \
    .github/workflows/deploy-prod.yml scripts/deploy-prod.sh .claude/roles/worker/settings.json; do
    [ "$(edycja "$f")" = deny ] || { echo "dozwolone: $f"; false; }
  done
}

@test "rutynowe git, gh, pnpm, npm i npx w prostej formie dozwolone" {
  for c in "git status --short" "git add src/a.ts" "git commit -q -m opis" "git push" "git push -q" \
    "git push -u origin task/1-slug" "git push --force-with-lease origin task/1-slug" "git fetch origin" \
    "git merge --no-edit origin/main" "git merge origin/main" "git rebase origin/main" "git cherry-pick abc123" \
    "git check-ignore -v dist" "git reset -q --hard ae4438b" "git show --stat 6c67d48" \
    "gh pr create --base main --head task/1 --title x --body-file p.md" "gh pr edit 31 --body-file p.md" \
    "gh pr view 31" "gh pr checks 31 --watch" "gh pr list --head task/1" "gh run list --branch main" \
    "gh run view 1 --log-failed" "gh run rerun 1 --failed" "gh run watch 1 --exit-status" "gh issue view 5" \
    "gh issue list --state open" "gh api repos/a/b/releases/latest --jq .tag_name" \
    "pnpm install --frozen-lockfile" "pnpm build" "npm view astro version" "npx -y lighthouse@12.8.2 http://localhost:1" \
    "npx vitest run" "node scripts/a.mjs" "bash scripts/check-dod.sh" "gitleaks git --redact --no-banner ." \
    "cat package.json" "diff a b" "mkdir -p src/lib" "rm -rf dist"; do
    [ "$(bash_regula "$c")" = allow ] || { echo "nie dozwolone: $c ($(bash_regula "$c"))"; false; }
  done
}

@test "deny: production i main, force push, refspec z +, usuwanie galezi" {
  for c in "git push origin main" "git push -q origin HEAD:main" "git push origin task/1:refs/heads/main" \
    "git push origin HEAD:production" "git push origin production" "git push --force origin task/1" \
    "git push origin task/1 --force" "git push -f origin task/1" "git push origin +task/1" "git push origin +HEAD:task/1" \
    "git push origin --delete task/1" "git push origin :main" "git push --mirror origin"; do
    [ "$(bash_regula "$c")" = deny ] || { echo "nie zablokowane: $c ($(bash_regula "$c"))"; false; }
  done
}

@test "deny: gh api z metoda albo polami, gh secret, auth, repo delete" {
  for c in "gh api -X DELETE repos/a/b" "gh api repos/a/b/issues -X POST" "gh api --method PATCH repos/a/b" \
    "gh api repos/a/b/labels -f name=x" "gh api graphql -F q=1" "gh api repos/a/b --field x=1" \
    "gh api repos/a/b --raw-field x=1" "gh api repos/a/b --input p.json" "gh secret list" "gh secret set X" \
    "gh auth token" "gh auth status" "gh repo delete a/b --yes" "gh repo edit --visibility public"; do
    [ "$(bash_regula "$c")" = deny ] || { echo "nie zablokowane: $c ($(bash_regula "$c"))"; false; }
  done
}

@test "deny: git -c, git config, git -C i rola orkiestratora" {
  for c in "git -c core.editor=true rebase --continue" "git -c alias.x=!sh x" "git config alias.x !sh" \
    "git -C /Users/Shared/sh/projekty/a commit -m x" "gh pr merge 7" "gh issue close 1" "gh issue edit 1 --add-label x" \
    "gh workflow run deploy-prod.yml" "gh alias set x --shell y"; do
    [ "$(bash_regula "$c")" = deny ] || { echo "nie zablokowane: $c ($(bash_regula "$c"))"; false; }
  done
}

@test "deny: wdrozenia, sekrety w komendach, sudo i rm poza worktree" {
  for c in "vercel deploy --prod" "npx vercel --prod" "pnpm exec vercel deploy" "supabase link --project-ref x" \
    "supabase db push" "npx supabase db push" "supabase secrets set X=1" "supabase functions deploy f" \
    "cat .env" "cat .env.local" "grep KEY .env.prod.local" "cp .env.example .env.local" "rm .env" \
    "sudo rm -rf /" "rm -rf /Users/Shared/sh" "rm -rf ~/x" "rm -rf ../inne"; do
    [ "$(bash_regula "$c")" = deny ] || { echo "nie zablokowane: $c ($(bash_regula "$c"))"; false; }
  done
}

@test "odczyt .env.example dozwolony w komendach" {
  for c in "cat .env.example" "grep -n LH_ .env.example"; do
    [ "$(bash_regula "$c")" = allow ] || { echo "nie dozwolone: $c ($(bash_regula "$c"))"; false; }
  done
}

@test "poza lista: supabase zdalnie, inne programy" {
  [ "$(bash_regula "supabase init")" = allow ]
  [ "$(bash_regula "supabase initx")" = brak ]
  [ "$(bash_regula "python3 a.py")" = brak ]
  [ "$(bash_regula "curl https://example.com")" = brak ]
}

@test "fnm: list, current i exec dozwolone, install i use nie (wersje Node zmienia dispatch)" {
  for c in "fnm list" "fnm list --help" "fnm current" "fnm exec --using=22 pnpm build" "fnm exec --using=.nvmrc node -v"; do
    [ "$(bash_regula "$c")" = allow ] || { echo "nie dozwolone: $c"; false; }
  done
  [ "$(bash_regula "fnm install 22")" = brak ]
  [ "$(bash_regula "fnm use 22")" = brak ]
}

@test "odczyt: bez ogolnego Read, Glob i Grep; zakres pilnuje hook odczyt-hook.sh" {
  for p in "$PROFIL"; do
    run jq -e '.permissions.allow | (index("Read") // index("Glob") // index("Grep"))' "$p"
    [ "$status" -ne 0 ] || { echo "ogolne Read/Glob/Grep w $p"; false; }
    jq -e '.hooks.PreToolUse[] | select(.matcher == "Read|Glob|Grep")
      | .hooks[] | select(.command == "/Users/Shared/sh/bin/odczyt-hook.sh || exit 2")' "$p" >/dev/null
  done
}

@test "pliki .env: hook env-hook.sh na odczyt, edycje, wyszukiwanie i Bash (wyjatek .env.example)" {
  jq -e '.hooks.PreToolUse[] | select(.matcher == "Read|Edit|Write|MultiEdit|NotebookEdit|Glob|Grep|Bash")
    | .hooks[] | select(.command == "/Users/Shared/sh/bin/env-hook.sh || exit 2")' "$PROFIL" >/dev/null
}

@test "reguly bez koncowego :* (Claude Code czyta je doslownie i ignoruje)" {
  [ "$(jq -r '[.permissions.allow[], .permissions.deny[]] | map(select(endswith(":*)"))) | length' "$PROFIL")" -eq 0 ]
}

@test "katalogi domowe poza zasiegiem: Documents, Desktop, Downloads, iCloud" {
  for k in "~/Documents/**" "~/Desktop/**" "~/Downloads/**" "~/Library/Mobile Documents/**"; do
    for n in Read Edit; do
      jq -e --arg r "$n($k)" '.permissions.deny | index($r)' "$PROFIL" >/dev/null || { echo "brak deny $n($k)"; false; }
    done
  done
  for c in "gh gist create plik" "gh release upload v1 plik" "git diff --no-index a b" "git --exec-path=/tmp/x status"; do
    [ "$(bash_regula "$c")" = deny ] || { echo "nie zablokowane: $c"; false; }
  done
}

@test "sandbox: wlaczony bez wyjscia poza sandbox; git push|fetch|pull, gh i shctl escalate poza nim; siec z listy" {
  jq -e '.sandbox.enabled == true and .sandbox.allowUnsandboxedCommands == false' "$PROFIL" >/dev/null
  for c in "git push *" "git fetch *" "git pull *" "gh *" "shctl escalate *"; do
    jq -e --arg c "$c" '.sandbox.excludedCommands | index($c)' "$PROFIL" >/dev/null || { echo "brak excluded $c"; false; }
  done
  for d in github.com api.github.com registry.npmjs.org; do
    jq -e --arg d "$d" '.sandbox.network.allowedDomains | index($d)' "$PROFIL" >/dev/null || { echo "brak domeny $d"; false; }
  done
  # Interpretery (node, npx, pnpm) zostają w sandboxie: to one omijały reguły Read (test 2026-11-09).
  [ "$(jq -r '[.sandbox.excludedCommands[] | select(test("^(node|npx|pnpm|npm|python|uv|bash|cat) "))] | length' "$PROFIL")" -eq 0 ]
}

@test "sandbox: pnpm 12 trzyma blokady w /tmp/pnpm-*-UID, zapis tam dozwolony (test sh-dryrun 2026-11-09)" {
  for d in store-operation-locks dir-locks modules-swaps verify-deps-install-locks; do
    jq -e --arg d "/private/tmp/pnpm-$d-502" '.sandbox.filesystem.allowWrite | index($d)' "$PROFIL" >/dev/null || { echo "brak $d"; false; }
  done
}

@test "git czytajacy pliki spoza repo w sandboxie i w deny: --no-index, config, blame --contents, -C" {
  ! jq -e '.sandbox.excludedCommands | index("git *")' "$PROFIL" >/dev/null || false
  [ "$(jq -r '[.sandbox.excludedCommands[] | select(test("^git (diff|show|log|config|blame|grep|commit|cat-file|hash-object|-C)"))] | length' "$PROFIL")" -eq 0 ]
  for c in "git diff --no-index /Users/x/Documents/a /dev/null" "git grep --no-index sekret /Users/x/Documents" \
    "git config -f /Users/x/Documents/a --list" "git blame --contents /Users/x/Documents/a plik" \
    "git -C /Users/x/Documents status"; do
    [ "$(bash_regula "$c")" = deny ] || { echo "nie zablokowane: $c ($(bash_regula "$c"))"; false; }
  done
}

@test "hook gh-plik-hook.sh na Bash: plik tresci PR i komentarzy tylko z /Users/Shared/sh (gh poza sandboxem)" {
  jq -e '.hooks.PreToolUse | any(.matcher == "Bash" and (.hooks[0].command == "/Users/Shared/sh/bin/gh-plik-hook.sh || exit 2"))' "$PROFIL" >/dev/null
}
