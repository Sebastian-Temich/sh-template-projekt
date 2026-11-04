#!/usr/bin/env bash
# Przenosi stan issue, PR i CI z GitHuba do plików wspólnych:
#   docs/06-zadania/index.md  tabela między znacznikami sync-status
#   docs/status.md            we frontmatterze: liczniki, wstrzymania z /Users/Shared/sh/limity.md i
#                             ostatnie_decyzje z docs/decyzje.md (dla DQL w docs/_dashboard.md)
# Tylko dla orkiestratora, na main. Nic nie commituje. Bez zmian stanu nie zmienia plików.
# Użycie: scripts/sync-status.sh [--dry-run] [--repo WLASCICIEL/NAZWA]
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
INDEKS="$ROOT/docs/06-zadania/index.md"
STATUS="$ROOT/docs/status.md"
DECYZJE="$ROOT/docs/decyzje.md"
ILE_DECYZJI=5
LIMITY="${SH_DIR:-/Users/Shared/sh}/limity.md"
START='<!-- sync-status:start -->'
KONIEC='<!-- sync-status:end -->'

DRY=0
REPO_ARGS=()
while [ $# -gt 0 ]; do
  case "$1" in
    --dry-run) DRY=1 ;;
    --repo)
      [ $# -ge 2 ] || { echo "BŁĄD: --repo wymaga wartości" >&2; exit 2; }
      REPO_ARGS=(--repo "$2")
      shift
      ;;
    *) echo "Użycie: $0 [--dry-run] [--repo WLASCICIEL/NAZWA]" >&2; exit 2 ;;
  esac
  shift
done

for narzedzie in gh jq; do
  command -v "$narzedzie" >/dev/null || { echo "BŁĄD: brak narzędzia $narzedzie" >&2; exit 1; }
done
for plik in "$INDEKS" "$STATUS"; do
  [ -f "$plik" ] || { echo "BŁĄD: brak $plik" >&2; exit 1; }
done
if ! grep -qxF "$START" "$INDEKS" || ! grep -qxF "$KONIEC" "$INDEKS"; then
  echo "BŁĄD: index.md nie ma znaczników sync-status" >&2
  exit 1
fi

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

gh issue list --state all --limit 1000 ${REPO_ARGS[@]+"${REPO_ARGS[@]}"} \
  --json number,title,state,stateReason,labels,milestone >"$TMP/issues.json"
gh pr list --state all --limit 1000 ${REPO_ARGS[@]+"${REPO_ARGS[@]}"} \
  --json number,state,headRefName,closingIssuesReferences,statusCheckRollup >"$TMP/prs.json"

# Jeden obiekt na zadanie, posortowane po numerze issue. PR wiążemy przez „Closes #NR”
# albo gałąź task/NR-slug; przy kilku bierzemy najnowszy.
jq -n --slurpfile issues "$TMP/issues.json" --slurpfile prs "$TMP/prs.json" '
  def ci:
    (.statusCheckRollup // []) as $c
    | if ($c | length) == 0 then "-"
      elif any($c[]; (.conclusion // .state // "")
        | IN("FAILURE", "ERROR", "CANCELLED", "TIMED_OUT", "ACTION_REQUIRED", "STARTUP_FAILURE"))
        then "fail"
      elif any($c[]; (.status // "") as $s | (.state // "") as $t
        | ($s != "" and $s != "COMPLETED") or $t == "PENDING" or $t == "EXPECTED")
        then "pending"
      else "pass" end;
  def status_zadania:
    [.labels[].name] as $e
    | if .state == "CLOSED" then
        (if .stateReason == "NOT_PLANNED" then "anulowane" else "done" end)
      else
        first(("escalated", "blocked", "review", "in-progress", "todo")
          | select(("status:" + .) as $n | $e | index($n))) // "todo"
      end;
  def iteracja:
    [.labels[].name | select(startswith("iter:")) | ltrimstr("iter:")] | sort | last // "0";

  ($prs[0] | map(. + {ci: ci})) as $prs
  | $issues[0]
  | map(
      .number as $nr
      | ($prs
          | map(select(
              ([.closingIssuesReferences[]?.number] | index($nr)) != null
              or (.headRefName | startswith("task/\($nr)-"))))
          | max_by(.number)) as $pr
      | {
          nr: $nr,
          tytul: (.title | gsub("\\|"; "\\|")),
          status: status_zadania,
          iter: iteracja,
          kamien: (.milestone.title // "-"),
          pr: (if $pr then "#\($pr.number) \($pr.state | ascii_downcase)" else "-" end),
          ci: ($pr.ci // "-")
        })
  | sort_by(.nr)' >"$TMP/zadania.json"

{
  echo "$START"
  echo "| Zadanie | Tytuł | Status | Iteracja | Kamień milowy | PR | CI |"
  echo "|---|---|---|---|---|---|---|"
  jq -r '.[] | "| #\(.nr) | \(.tytul) | \(.status) | \(.iter) | \(.kamien) | \(.pr) | \(.ci) |"' \
    "$TMP/zadania.json"
  echo "$KONIEC"
} >"$TMP/tabela.md"

awk -v start="$START" -v koniec="$KONIEC" -v tabela="$TMP/tabela.md" '
  $0 == start {
    while ((getline linia < tabela) > 0) print linia
    close(tabela)
    pomin = 1
    next
  }
  $0 == koniec { pomin = 0; next }
  !pomin { print }' "$INDEKS" >"$TMP/index.md"

jq -r --slurpfile prs "$TMP/prs.json" '
  def ile($s): map(select(.status == $s)) | length;
  ([$prs[0][] | select(.state == "OPEN")]) as $otwarte
  | "zadania_todo=\(ile("todo"))",
    "zadania_in_progress=\(ile("in-progress"))",
    "zadania_review=\(ile("review"))",
    "zadania_blocked=\(ile("blocked"))",
    "zadania_escalated=\(ile("escalated"))",
    "zadania_done=\(ile("done"))",
    "zadania_anulowane=\(ile("anulowane"))",
    "pr_otwarte=\($otwarte | length)",
    "ci_fail=\(map(select(.ci == "fail" and (.pr | endswith(" open")))) | length)"
' "$TMP/zadania.json" >"$TMP/liczniki"

# Wstrzymania jak w shctl (lib/zadania.sh, „wstrzymania”): pozycje list i wiersze tabel bez
# nagłówka, „brak” się nie liczy. Zapis jako lista JSON w jednej linii, czyli poprawny YAML.
{
  if [ -f "$LIMITY" ]; then
    grep -E '^(- |\| )' "$LIMITY" | grep -vE '^\|[- |:]*$' | awk '!/^\| / || n++' |
      grep -viE '^(- |\| )[*_(]*(brak|nic|none)[*_)]*[ |]*$' || true
  fi
} | jq -Rsr '
  split("\n")
  | map(gsub("^\\s+|\\s+$"; "") | select(length > 0)
      | if startswith("- ") then ltrimstr("- ")
        else ltrimstr("|") | rtrimstr("|") | split("|") | map(gsub("^\\s+|\\s+$"; "")) | join(" · ")
        end)
  | "wstrzymania=\(tojson)"' >>"$TMP/liczniki"

# Ostatnie decyzje z tabeli decyzje.md, najnowsza pierwsza, dla zapytań DQL w _dashboard.md.
# Zapis jako lista map YAML w jednej linii, z odstępem po „:” i „,” (zgodny z YAML 1.1 i 1.2).
{
  if [ -f "$DECYZJE" ]; then
    grep -E '^\| ' "$DECYZJE" | grep -vE '^\|[- |:]*$' | awk 'n++' || true
  fi
} | jq -Rsr --argjson ile "$ILE_DECYZJI" '
  def mapa: "{" + (to_entries | map("\(.key | tojson): \(.value | tojson)") | join(", ")) + "}";
  split("\n")
  | map(gsub("^\\s+|\\s+$"; "") | select(length > 0)
      | ltrimstr("|") | rtrimstr("|")
      | [splits("(?<!\\\\)\\|") | gsub("^\\s+|\\s+$"; "") | gsub("\\\\\\|"; "|")]
      | {data: .[0], zrodlo: .[1], pytanie: .[2], decyzja: .[3]}
      | map_values(. // ""))
  | .[-$ile:] | reverse
  | "ostatnie_decyzje=[\(map(mapa) | join(", "))]"' >>"$TMP/liczniki"

# Podmienia klucze wyłącznie we frontmatterze; brakujące dopisuje na jego końcu.
wstaw_liczniki() {
  awk -v liczniki="$TMP/liczniki" -v znacznik="$1" '
    BEGIN {
      while ((getline linia < liczniki) > 0) {
        p = index(linia, "=")
        k = substr(linia, 1, p - 1)
        wart[k] = substr(linia, p + 1)
        kolejnosc[++n] = k
      }
      if (znacznik != "") { k = "ostatnia_synchronizacja"; wart[k] = znacznik; kolejnosc[++n] = k }
    }
    NR == 1 && $0 == "---" { fm = 1; print; next }
    fm && $0 == "---" {
      for (i = 1; i <= n; i++)
        if (!(kolejnosc[i] in byl)) print kolejnosc[i] ": " wart[kolejnosc[i]]
      fm = 0
      print
      next
    }
    fm {
      k = $0
      sub(/:.*/, "", k)
      if (k in wart) { print k ": " wart[k]; byl[k] = 1; next }
    }
    { print }' "$STATUS"
}

wstaw_liczniki "" >"$TMP/status.md"

zmiany=0
cmp -s "$TMP/index.md" "$INDEKS" || zmiany=1
cmp -s "$TMP/status.md" "$STATUS" || zmiany=1

if [ "$DRY" -eq 1 ]; then
  cat "$TMP/tabela.md" "$TMP/liczniki"
  echo "sync-status: dry-run, zmiany: $zmiany"
  exit 0
fi

if [ "$zmiany" -eq 0 ]; then
  echo "sync-status: bez zmian"
  exit 0
fi

wstaw_liczniki "$(date -u +%Y-%m-%dT%H:%M:%SZ)" >"$TMP/status.md"
cat "$TMP/index.md" >"$INDEKS"
cat "$TMP/status.md" >"$STATUS"
echo "sync-status: zaktualizowano index.md i status.md"
