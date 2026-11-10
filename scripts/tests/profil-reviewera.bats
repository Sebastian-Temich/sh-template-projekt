#!/usr/bin/env bats
# Sprawdzenie profilu .claude/roles/reviewer/settings.json (reviewer Claude w shctl review run) na
# atrapie oceny uprawnień Claude Code, jak w profil-workera.bats: deny ma pierwszeństwo, Bash(X *)
# pasuje do "X" i "X ...". shctl uruchamia reviewera z tym profilem z main projektu, z --tools
# Read,Grep,Glob,Bash, --setting-sources user i --strict-mcp-config (sh-system/docs/shctl.md).
# Uruchomienie: bats scripts/tests/profil-reviewera.bats

PROFIL="${PROFIL_REVIEWERA:-$BATS_TEST_DIRNAME/../../.claude/roles/reviewer/settings.json}"

setup() {
  command -v jq >/dev/null || skip "brak jq"
}

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

@test "profil reviewera to poprawny JSON w trybie dontAsk" {
  jq -e '.permissions.defaultMode == "dontAsk" and .permissions.allow and .permissions.deny' "$PROFIL"
}

@test "tylko odczyt: Edit, Write, MultiEdit, NotebookEdit, siec i subagenci zablokowani" {
  for t in Edit Write MultiEdit NotebookEdit WebFetch WebSearch Agent; do
    jq -e --arg t "$t" '.permissions.deny | index($t)' "$PROFIL" >/dev/null || { echo "brak deny $t"; false; }
    run jq -e --arg t "$t" '.permissions.allow | index($t)' "$PROFIL"
    [ "$status" -ne 0 ] || { echo "allow $t"; false; }
  done
}

@test "git tylko do odczytu dozwolony" {
  for c in "git diff abc...HEAD" "git diff --stat abc..HEAD" "git log --oneline abc..HEAD" "git show abc:src/a.ts" \
    "git status" "git ls-files src" "git grep -n foo" "git merge-base main HEAD" "git rev-parse HEAD" "ls src" "wc -l src/a.ts"; do
    [ "$(bash_regula "$c")" = allow ] || { echo "nie dozwolone: $c ($(bash_regula "$c"))"; false; }
  done
}

@test "zapis, siec, gh, shctl i git zmieniajacy stan poza lista albo w deny" {
  for c in "git commit -m x" "git push" "git checkout -b x" "git add ." "git reset --hard" "git fetch origin" \
    "pnpm test" "npm install" "node a.js" "python3 a.py" "rm -rf src" "touch x" "cat src/a.ts"; do
    [ "$(bash_regula "$c")" != allow ] || { echo "dozwolone: $c"; false; }
  done
  for c in "gh pr comment 1 --body x" "gh api repos/a/b" "shctl task close 1" "curl https://example.com" \
    "git diff --output=/tmp/x" "git diff --ext-diff" "git log --textconv" "git diff --no-index a b" \
    "git -c core.pager=sh log" "git -C /Users/x log" "git config core.pager sh" "sudo ls" \
    "git show HEAD:.env" "git diff HEAD .env.local"; do
    [ "$(bash_regula "$c")" = deny ] || { echo "nie zablokowane: $c ($(bash_regula "$c"))"; false; }
  done
}

@test "git zmieniajacy stan i siec jawnie w deny" {
  for c in "git push" "git push origin HEAD:main" "git commit -m x" "git add ." "git reset --hard" "git checkout -b x" \
    "git switch main" "git restore a" "git merge x" "git rebase main" "git fetch origin" "git pull" "git worktree add x" \
    "git stash" "git tag v1" "git branch -D x"; do
    [ "$(bash_regula "$c")" = deny ] || { echo "nie zablokowane: $c ($(bash_regula "$c"))"; false; }
  done
}

@test "hooki odczytu i plikow env jak u workera" {
  jq -e '.hooks.PreToolUse[] | select(.matcher == "Read|Glob|Grep")
    | .hooks[] | select(.command == "/Users/Shared/sh/bin/odczyt-hook.sh || exit 2")' "$PROFIL" >/dev/null
  jq -e '.hooks.PreToolUse[] | select(.matcher == "Read|Edit|Write|MultiEdit|NotebookEdit|Glob|Grep|Bash")
    | .hooks[] | select(.command == "/Users/Shared/sh/bin/env-hook.sh || exit 2")' "$PROFIL" >/dev/null
  run jq -e '.permissions.allow | (index("Read") // index("Glob") // index("Grep"))' "$PROFIL"
  [ "$status" -ne 0 ]
}

@test "sandbox bez sieci i bez wyjatkow" {
  jq -e '.sandbox.enabled == true and .sandbox.allowUnsandboxedCommands == false
    and (.sandbox.excludedCommands | length) == 0 and (.sandbox.network.allowedDomains | length) == 0' "$PROFIL" >/dev/null
}

@test "reguly bez koncowego :*" {
  [ "$(jq -r '[.permissions.allow[], .permissions.deny[]] | map(select(endswith(":*)"))) | length' "$PROFIL")" -eq 0 ]
}
