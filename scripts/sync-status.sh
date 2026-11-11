#!/usr/bin/env bash
# Generuje widok projektu dla właściciela, historię i plik zadań z GitHuba i plików repo:
#   docs/Projekt.md           cały plik: krótki frontmatter (dla SH/Wszystkie projekty.md), Gdzie
#                             jesteśmy, Czeka na Ciebie, Zadania bieżącego zlecenia, Eskalacje i
#                             pytania, Dokumenty.
#   docs/historia.md          „Punkt przekazania” i „Dziennik etapów” (piszą orkiestrator i shctl) oraz
#                             blok historia:start/end z pełną listą zadań wszystkich zleceń.
#   docs/06-zadania/index.md  tabela między znacznikami sync-status
# Czysty Markdown, bez Dataview. Stary projekt: „Punkt przekazania” i „Dziennik etapów” z Projekt.md
# albo docs/status.md przechodzą do historia.md, a status.md znika (commit robi orkiestrator).
# Lista „Czeka na Ciebie” z czasem, od którego czeka, trafia do SH_DIR/stan/czeka/NAZWA.json
# (przypomnienia ntfy, shctl status show), nie do repo.
# Bieżące zlecenie: zadania od zlecenie_od z docs/konfiguracja.md albo od ostatniego „Przebieg
# dryrun” w docs/metryki.md; bez przebiegu ostatnia seria zadań tryb:S po zamkniętych zadaniach
# trybu M to osobne zlecenie S. Otwarte zadania należą do bieżącego zlecenia zawsze.
# Wywołuje go shctl po każdej zmianie stanu (orkiestrator, na main). Nic nie commituje.
# Użycie: scripts/sync-status.sh [--dry-run] [--repo WLASCICIEL/NAZWA] [--nazwa PROJEKT]
#           [--dane KATALOG] [--wyjscie KATALOG]
#   --dane     issues.json, prs.json i otwarte.json zamiast gh (testy, podgląd)
#   --wyjscie  zapis Projekt.md, historia.md, index.md i czeka.json do KATALOGU zamiast docs/ (podgląd)
# Czas: SH_TERAZ (epoka, testy). Dane serwera: SH_DIR (stan/, konfiguracja.md, limity.md).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SH_DIR="${SH_DIR:-/Users/Shared/sh}"
LIMITY="$SH_DIR/limity.md"
START='<!-- sync-status:start -->'
KONIEC='<!-- sync-status:end -->'
H_START='<!-- historia:start -->'
H_KONIEC='<!-- historia:end -->'
OSTATNICH=10

DRY=0
DANE=""
WYJSCIE=""
NAZWA=""
REPO_ARGS=()
while [ $# -gt 0 ]; do
  case "$1" in
    --dry-run) DRY=1 ;;
    --repo | --dane | --wyjscie | --nazwa)
      [ $# -ge 2 ] || { echo "BŁĄD: $1 wymaga wartości" >&2; exit 2; }
      case "$1" in
        --repo) REPO_ARGS=(--repo "$2") ;;
        --dane) DANE="$2" ;;
        --wyjscie) WYJSCIE="$2" ;;
        --nazwa) NAZWA="$2" ;;
      esac
      shift
      ;;
    *) echo "Użycie: $0 [--dry-run] [--repo WLASCICIEL/NAZWA] [--nazwa PROJEKT] [--dane KATALOG] [--wyjscie KATALOG]" >&2; exit 2 ;;
  esac
  shift
done

DOCS="$ROOT/docs"
INDEKS="$DOCS/06-zadania/index.md"
PROJEKT_MD="$DOCS/Projekt.md"
HISTORIA="$DOCS/historia.md"
STARY="$DOCS/status.md"
KONFIG="$DOCS/konfiguracja.md"
if [ -z "$NAZWA" ]; then
  w="$(git -C "$ROOT" rev-parse --path-format=absolute --git-common-dir 2>/dev/null || true)"
  if [ -n "$w" ]; then NAZWA="$(basename "$(dirname "$w")")"; else NAZWA="$(basename "$ROOT")"; fi
fi

for narzedzie in jq; do
  command -v "$narzedzie" >/dev/null || { echo "BŁĄD: brak narzędzia $narzedzie" >&2; exit 1; }
done
for plik in "$INDEKS" "$KONFIG"; do
  [ -f "$plik" ] || { echo "BŁĄD: brak $plik" >&2; exit 1; }
done
if ! grep -qxF "$START" "$INDEKS" || ! grep -qxF "$KONIEC" "$INDEKS"; then
  echo "BŁĄD: index.md nie ma znaczników sync-status" >&2
  exit 1
fi

TMP="$(mktemp -d "${TMPDIR:-/tmp}/sync-status.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT

# --- Pomocnicze ---------------------------------------------------------------------------------

# Wartość klucza z frontmattera (pierwszy blok między liniami ---), bez cudzysłowów i komentarza.
fm_get() {
  awk -v k="$2" '
    NR == 1 { if ($0 != "---") exit; next }
    $0 == "---" { exit }
    index($0, k ":") == 1 {
      v = substr($0, length(k) + 2)
      sub(/[ \t]+#.*$/, "", v)
      gsub(/^[ \t"'"'"']+|[ \t"'"'"'\r]+$/, "", v)
      print v
      exit
    }' "$1" 2>/dev/null || true
}

# Treść sekcji „## NAZWA” (do następnego nagłówka drugiego poziomu albo znacznika bloku), bez pustych
# linii na brzegach.
sekcja() {
  awk -v n="## $2" '
    $0 == n { w = 1; next }
    w && (/^## / || /^<!-- [a-z-]+:(start|end) -->$/) { exit }
    w { print }' "$1" 2>/dev/null | sed '/./,$!d' | awk 'NF { for (; p > 0; p--) print ""; print; next } { p++ }'
}

# Czas pierwszego commita pliku (UTC, ISO), a bez historii czas modyfikacji.
czas_pliku() {
  local c
  c="$(git -C "$ROOT" log --diff-filter=A --format=%ct -1 -- "$1" 2>/dev/null || true)"
  [ -n "$c" ] || c="$(stat -c %Y "$1" 2>/dev/null || stat -f %m "$1" 2>/dev/null || true)"
  [ -n "$c" ] || return 0
  date -u -r "$c" +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date -u -d "@$c" +%Y-%m-%dT%H:%M:%SZ
}

# --- Dane z GitHuba -----------------------------------------------------------------------------

if [ -n "$DANE" ]; then
  for f in issues prs otwarte; do
    if [ -f "$DANE/$f.json" ]; then cp "$DANE/$f.json" "$TMP/$f.json"; else echo '[]' >"$TMP/$f.json"; fi
  done
else
  command -v gh >/dev/null || { echo "BŁĄD: brak narzędzia gh" >&2; exit 1; }
  gh issue list --state all --limit 1000 ${REPO_ARGS[@]+"${REPO_ARGS[@]}"} \
    --json number,title,state,stateReason,labels,milestone,body,createdAt,closedAt >"$TMP/issues.json"
  gh pr list --state all --limit 1000 ${REPO_ARGS[@]+"${REPO_ARGS[@]}"} \
    --json number,state,headRefName,closingIssuesReferences,statusCheckRollup >"$TMP/prs.json"
  gh pr list --state open --limit 200 ${REPO_ARGS[@]+"${REPO_ARGS[@]}"} \
    --json number,headRefName,headRefOid,closingIssuesReferences,comments >"$TMP/otwarte.json"
fi

# --- Dane lokalne -------------------------------------------------------------------------------

TRYB="$(fm_get "$KONFIG" tryb_procesu)"
WERSJA="$(fm_get "$KONFIG" wersja_procesu)"
ODBIOR_S="$(fm_get "$KONFIG" odbior_S)"
[ -n "$ODBIOR_S" ] || ODBIOR_S=reczny
case "${WERSJA:-1}" in
  1) ETAPY="00-intake 04-architektura 05-plan 06-zadania 08-qa wydanie" ;;
  *) ETAPY="00-intake 04-plan 06-zadania 08-qa wydanie" ;;
esac
MAX_LOCAL="$(fm_get "$KONFIG" max_local)"
[ -n "$MAX_LOCAL" ] || MAX_LOCAL="$(fm_get "$SH_DIR/konfiguracja.md" max_local)"
case "$MAX_LOCAL" in "" | *[!0-9]*) MAX_LOCAL=2 ;; esac

# Początek bieżącego zlecenia (ISO UTC): zlecenie_od z konfiguracji albo ostatni przebieg dryrun
# z metryk („## Przebieg dryrun N… (RRRR-MM-DD)” i „Reset do baseline … o GG:MM UTC”).
ZLECENIE_OD="$(fm_get "$KONFIG" zlecenie_od)"
PRZEBIEG_OD=""
if [ -f "$DOCS/metryki.md" ]; then
  PRZEBIEG_OD="$(awk '
    /^## Przebieg dryrun [0-9]/ {
      d = ""; g = "00:00"; s = 1
      if (match($0, /\([0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]\)/)) d = substr($0, RSTART + 1, 10)
      next
    }
    /^## / { s = 0 }
    s && match($0, / o [0-9][0-9]:[0-9][0-9] UTC/) { g = substr($0, RSTART + 3, 5); s = 0 }
    END { if (d != "") print d "T" g ":00Z" }' "$DOCS/metryki.md")"
fi

: >"$TMP/etapy.jsonl"
for e in $ETAPY; do
  f="$DOCS/$e/DoD.md"
  [ -f "$f" ] || continue
  akc=false
  grep -qE '^[ \t]*- \[[xX]\] .*[Ww]łaściciel zaakceptował' "$f" && akc=true
  jq -nc --arg e "$e" --arg s "$(fm_get "$f" status)" --arg k "$(fm_get "$f" akceptacja_wlasciciela)" \
    --argjson a "$akc" '{etap:$e, status:$s, checkpoint:($k == "true"), zaakceptowany:$a}' >>"$TMP/etapy.jsonl"
done

: >"$TMP/eskalacje.jsonl"
for f in "$DOCS"/07-realizacja/escalations/E-[0-9]*.md; do
  [ -e "$f" ] || continue
  od="$(fm_get "$f" otwarto)"
  [ -n "$od" ] || od="$(czas_pliku "$f")"
  opcje="$(sekcja "$f" "Opcje i rekomendacja" | sed -n 's/^- //p' | jq -Rsc 'split("\n") | map(select(length > 0))')"
  jq -nc --arg i "$(basename "$f" .md)" --arg s "$(fm_get "$f" status)" --arg t "$(fm_get "$f" typ)" \
    --arg d "$(fm_get "$f" dotyczy)" --arg p "$(fm_get "$f" powod)" --arg o "$od" --argjson op "$opcje" \
    '{id:$i, status:$s, typ:(if $t == "" then "blokada" else $t end), dotyczy:$d, powod:$p, od:$o, opcje:$op}' \
    >>"$TMP/eskalacje.jsonl"
done

LISTA="$DOCS/00-intake/lista-startowa.md"
LISTA_OD=""
: >"$TMP/lista.txt"
if [ -f "$LISTA" ]; then
  awk '
    /^[ \t]*(```|~~~)/ { kod = !kod; next }
    kod { next }
    /<!--/ { kom = 1 }
    kom { if (/-->/) kom = 0; next }
    /^[ \t]*[-*+] \[ \] / { sub(/^[ \t]*[-*+] \[ \] /, ""); print }' "$LISTA" >"$TMP/lista.txt"
  LISTA_OD="$(czas_pliku "$LISTA")"
fi

# Średni czas zadania z docs/metryki.md (kolumna Czas, np. „1h 23min”, „45min”), w minutach.
SREDNIA=0
if [ -f "$DOCS/metryki.md" ]; then
  SREDNIA="$(awk -F '|' '
    /^\| Zlecenie \|/ { t = 1; next }
    t && /^\|[- |]*$/ { next }
    t && /^\| #/ {
      c = $4; m = 0
      if (match(c, /[0-9]+d/)) m += substr(c, RSTART, RLENGTH - 1) * 1440
      if (match(c, /[0-9]+h/)) m += substr(c, RSTART, RLENGTH - 1) * 60
      if (match(c, /[0-9]+min/)) m += substr(c, RSTART, RLENGTH - 3)
      if (m > 0) { s += m; n++ }
      next
    }
    !/^\|/ { t = 0 }
    END { if (n) printf "%d", s / n; else print 0 }' "$DOCS/metryki.md")"
fi

STAN_ZADAN='{}'
if [ -f "$SH_DIR/stan/$NAZWA.json" ]; then
  STAN_ZADAN="$(jq -c '.zadania // {}' "$SH_DIR/stan/$NAZWA.json" 2>/dev/null || echo '{}')"
fi

dok() { [ -f "$DOCS/$1" ] && printf '%s\n' "$1" || true; }
{
  dok 00-intake/specyfikacja.md
  for f in "$DOCS"/00-intake/funkcje/W-*.md; do [ ! -e "$f" ] || echo "00-intake/funkcje/$(basename "$f")"; done
  dok 00-intake/lista-startowa.md
  dok 04-plan/plan.md
  dok 04-architektura/architektura.md
  dok 05-plan/plan.md
  dok decyzje.md
  for f in "$DOCS"/08-qa/raport-*.md; do [ ! -e "$f" ] || echo "08-qa/$(basename "$f")"; done
} | jq -Rsc 'split("\n") | map(select(length > 0))' >"$TMP/dokumenty.json"

# Wstrzymania jak w shctl (lib/zadania.sh, „wstrzymania”): pozycje list i wiersze tabel bez
# nagłówka, „brak” się nie liczy.
{
  if [ -f "$LIMITY" ]; then
    grep -E '^(- |\| )' "$LIMITY" | grep -vE '^\|[- |:]*$' | awk '!/^\| / || n++' |
      grep -viE '^(- |\| )[*_(]*(brak|nic|none)[*_)]*[ |]*$' || true
  fi
} | jq -Rsc '
  split("\n")
  | map(gsub("^\\s+|\\s+$"; "") | select(length > 0)
      | if startswith("- ") then ltrimstr("- ")
        else ltrimstr("|") | rtrimstr("|") | split("|") | map(gsub("^\\s+|\\s+$"; "")) | join(" · ")
        end)' >"$TMP/wstrzymania.json"

TERAZ="${SH_TERAZ:-$(date +%s)}"

jq -n \
  --slurpfile issues "$TMP/issues.json" --slurpfile prs "$TMP/prs.json" --slurpfile otw "$TMP/otwarte.json" \
  --slurpfile etapy <(jq -s . "$TMP/etapy.jsonl") --slurpfile esk <(jq -s . "$TMP/eskalacje.jsonl") \
  --slurpfile dok "$TMP/dokumenty.json" --slurpfile wstrz "$TMP/wstrzymania.json" \
  --rawfile lista "$TMP/lista.txt" --arg lista_od "$LISTA_OD" \
  --arg nazwa "$NAZWA" --arg tryb "${TRYB:-M}" --arg odbior "$ODBIOR_S" \
  --arg zlecenie_od "$ZLECENIE_OD" --arg przebieg_od "$PRZEBIEG_OD" \
  --argjson srednia "$SREDNIA" --argjson rownolegle "$MAX_LOCAL" --argjson stan "$STAN_ZADAN" \
  --argjson teraz "$TERAZ" '
  def etykiety: [.labels[]? | if type == "object" then .name else . end];
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
    etykiety as $e
    | if .state == "CLOSED" then (if .stateReason == "NOT_PLANNED" then "anulowane" else "done" end)
      else first(("escalated", "blocked", "review", "in-progress", "todo")
        | select(("status:" + .) as $n | $e | index($n))) // "todo" end;
  def iteracja: [etykiety[] | select(startswith("iter:")) | ltrimstr("iter:") | tonumber] | max // 0;
  # Zależności z pola strukturalnego, jak w shctl: lista „#NR, #NR” w pierwszej niepustej linii sekcji;
  # notatki pod nią (np. „#79 anulowane”) nie są zależnościami.
  def zaleznosci:
    ((.body // "") | split("\n")) as $l
    | ([range(0; $l | length) | select($l[.] | test("^#{2,3} *Zależności"))][0]) as $i
    | if $i == null then []
      else ([$l[($i + 1):][] | select(test("^\\s*$") | not)][0] // "") as $p
        | if ($p | test("^#{2,3} ")) then []
          else [(($p | capture("^(?<l>(\\s*#[0-9]+\\s*,?)+)").l) // "") | scan("#([0-9]+)") | .[0] | tonumber] | unique end end;
  def iso: if . == null or . == "" then "" else sub("\\.[0-9]+Z$"; "Z") end;
  def czas($s): if $s == null or $s == "" then null else ($teraz - ($s | iso | fromdateiso8601)) end;
  def slownie($sek):
    if $sek == null or $sek < 0 then "-"
    else ($sek / 60 | floor) as $m
      | if $m < 60 then "\($m) min"
        elif $m < 1440 then "\($m / 60 | floor) h" + (if $m % 60 > 0 then " \($m % 60) min" else "" end)
        else "\($m / 1440 | floor) d" + (if ($m % 1440) >= 60 then " \(($m % 1440) / 60 | floor) h" else "" end) end end;
  def ostatnio: sort_by(.zamkniete, .nr) | reverse;
  def nazwa_etapu:
    {"00-intake": "Specyfikacja", "04-plan": "Plan", "04-architektura": "Architektura",
     "05-plan": "Plan", "06-zadania": "Rozpisanie zadań", "08-qa": "QA", "wydanie": "Odbiór i wydanie"}[.] // .;
  def pass_dla_heada:
    .headRefOid as $h
    | [(.comments // [])[] | select(.body | contains("<!-- shctl:review head=" + $h + " "))] | last
    | if . == null then null elif (.body | contains("werdykt=PASS")) then (.createdAt // "") else null end;

  ($prs[0] | map(. + {ci: ci})) as $prs
  | ($otw[0]) as $otw
  | ($issues[0] | map(. + {_et: etykiety})) as $is
  | ($is | map({key: (.number | tostring), value: .}) | from_entries) as $mapa
  | ($is | map(
      .number as $nr
      | ($prs | map(select(([.closingIssuesReferences[]?.number] | index($nr)) != null
          or (.headRefName | startswith("task/\($nr)-")))) | max_by(.number)) as $pr
      | ($otw | map(select(([.closingIssuesReferences[]?.number] | index($nr)) != null
          or (.headRefName | startswith("task/\($nr)-")))) | max_by(.number)) as $po
      | {
          nr: $nr, tytul: .title, status: status_zadania, iter: iteracja,
          kamien: (.milestone.title // "-"),
          pr: (if $pr then $pr.number else null end),
          pr_stan: (if $pr then ($pr.state | ascii_downcase) else null end),
          ci: ($pr.ci // "-"),
          pass_od: (if $po then ($po | pass_dla_heada) else null end),
          s: ((._et | index("tryb:S")) != null),
          niewidoczne: ((._et | index("widoczne:nie")) != null),
          typ: ([._et[] | select(startswith("typ:")) | ltrimstr("typ:")][0] // ""),
          zal: zaleznosci,
          start: ($stan[($nr | tostring)].start // null),
          utworzone: (.createdAt | iso),
          zamkniete: (.closedAt | iso)
        }) | sort_by(.nr)) as $z
  # Bieżące zlecenie: od zlecenie_od albo przebiegu dryrun; bez przebiegu ostatnia seria tryb:S po
  # zamkniętych zadaniach trybu M. Otwarte zadania zawsze.
  | ([$zlecenie_od, $przebieg_od] | map(iso) | max) as $od
  | ($z | map(select($od == "" or .utworzone == "" or .utworzone >= $od))) as $okres
  | (if $przebieg_od != "" then $okres
     else ([$okres[] | select(.s | not) | .nr] | max) as $ost_m
       | ([$okres[] | select(.s and ($ost_m == null or .nr > $ost_m))]) as $seria_s
       | ([$okres[] | select((.s | not) and (.status | IN("done", "anulowane") | not))] | length) as $otwarte_m
       | if $ost_m != null and $otwarte_m == 0 and ($seria_s | length) > 0 then $seria_s else $okres end end) as $zakres
  | ([$zakres[].nr]) as $nr_zakres
  | ($z | map(select((.nr as $n | $nr_zakres | index($n)) != null or (.status | IN("done", "anulowane") | not)))) as $biezace
  | ($biezace | map(select(.status != "anulowane"))) as $biezace_bez_anul
  | ($biezace | map(select(.status == "done"))) as $zrobione_b
  | ($z | map(select(.status == "todo") | . as $t
      | . + {czeka_na: [.zal[] | select(($mapa[tostring] // null) as $i
          | $i == null or ($i.state == "OPEN") or ($i.stateReason == "NOT_PLANNED"))]})) as $todo
  # Etapy: etap przygotowania w todo przy zadaniach zlecenia jest pominięty (np. przebieg dryrun
  # z zadaniami z zadania.yaml), tak jak status pominiety. Przebieg dryrun kończy się na QA, więc
  # wydanie w todo też jest wtedy pominięte.
  | (($biezace_bez_anul | length) > 0) as $sa_zadania
  | ($etapy[0] | map(. + {pominiety: (.status == "pominiety"
      or ($sa_zadania and .status == "todo" and (.etap | IN("08-qa", "wydanie") | not))
      or ($przebieg_od != "" and .etap == "wydanie" and .status == "todo"))})) as $et
  | ([$et[] | select(.pominiety | not)]) as $et_akt
  | ($esk[0] | map(select(.status == "otwarta"))) as $otwarte_esk
  | ($lista | split("\n") | map(select(length > 0))) as $lista
  | ($z | map(select(.status | IN("in-progress", "review", "escalated", "blocked")))) as $w_toku
  | ($todo | map(select(.czeka_na | length == 0))) as $gotowe
  | ($todo | map(select(.czeka_na | length > 0))) as $zaplanowane
  | ([$et_akt[] | select(.etap != "08-qa" and .etap != "wydanie")]) as $przyg
  | ([$przyg[] | select(.status != "done")][0]) as $etap_przyg
  | ([$et_akt[] | select(.etap == "wydanie")][0]) as $wydanie
  | ([$z[] | select(.status | IN("done", "anulowane") | not)]) as $otwarte_z
  | (if $tryb == "S" then
        (if ($otwarte_z | length) > 0 then {klucz: "realizacja", opis: "Zlecenie S w realizacji"}
         else {klucz: "zakonczony", opis: "Zlecenie S zakończone"} end)
     elif $etap_przyg != null then
        {klucz: $etap_przyg.etap, opis: ($etap_przyg.etap | nazwa_etapu), status: $etap_przyg.status}
     elif ($otwarte_z | length) > 0 then
        ([$otwarte_z[] | select(.kamien != "-") | .kamien] | sort | first) as $k
        | {klucz: "realizacja", opis: ("Realizacja" + (if $k then ", kamień \($k)" else "" end))}
     elif $wydanie != null and $wydanie.status != "done" then
        {klucz: "wydanie", opis: "Odbiór i wydanie", status: $wydanie.status}
     else {klucz: "zakonczony", opis: "Zakończony"} end) as $etap
  | (if $tryb == "S" or ($et_akt | length) == 0 then null
     else {x: ([$et_akt[] | select(.status == "done")] | length), y: ($et_akt | length)} end) as $postep_etapy
  | {x: ($zrobione_b | length), y: ($biezace_bez_anul | length)} as $postep_zadan
  # Czeka na Ciebie: pozycje z czasem, od którego czekają, i tekstem do wpisania.
  | ([ $otwarte_esk[]
        | {co: "\(.id) (\(.dotyczy)\(if .typ == "pytanie" then ", pytanie" else "" end)): \(.powod)",
           od: .od,
           # Opcja z etykietą („A: …”, „2) …”) to sama etykieta; bez etykiety pełny tekst opcji
           # (dryrun 5: „E-001: Zamknąć” ucinało opcję do pierwszego słowa).
           wpisz: "\(.id): \((.opcje[0] // "TWOJA ODPOWIEDŹ") as $o
             | if ($o | test("^[A-Za-z0-9]{1,2}[:)] ")) then ($o | capture("^(?<e>[A-Za-z0-9]{1,2})[:)]").e) else $o end)",
           opcje: .opcje} ]
     + [ $lista[] | {co: "Lista startowa: \(.)", od: $lista_od,
           wpisz: "gotowe: \(. | split(":")[0] | split(",")[0] | split(" (")[0])", opcje: []} ]
     + [ $et[] | select(.checkpoint and .status == "review" and (.zaakceptowany | not)) as $e
         | ($otw | map(select(.headRefName == "stage/\($e.etap)")) | max_by(.number)) as $p
         | select($p != null) | ($p | pass_dla_heada) as $od | select($od != null)
         | {co: "Akceptacja: \($e.etap | nazwa_etapu) (PR #\($p.number), review PASS)", od: $od,
            wpisz: "akceptuję \($e.etap | nazwa_etapu | ascii_downcase) PR #\($p.number)", opcje: []} ]
     + [ $z[] | select(.s and .status == "review" and .pass_od != null
           and ($odbior == "reczny" or (.niewidoczne | not)))
         | {co: "Odbiór zlecenia S #\(.nr) \(.tytul) (PR #\(.pr), review PASS)", od: .pass_od,
            wpisz: "odbieram #\(.nr)", opcje: ["albo: poprawki #\(.nr): CO ZMIENIĆ"]} ]
    ) as $czeka
  | (if ($czeka | length) > 0 then "Twoja odpowiedź: \($czeka[0].co)"
     elif $etap.klucz == "zakonczony" then "Brak, zlecenie zakończone"
     elif ($etap.status // "") == "review" then "Review etapu \($etap.opis | ascii_downcase), potem Twoja akceptacja"
     elif ($etap.status // "") == "in-progress" then "Agent przygotowuje etap \($etap.opis | ascii_downcase)"
     elif ($etap.status // "") == "escalated" then "Etap \($etap.opis | ascii_downcase) czeka na rozstrzygnięcie eskalacji"
     elif ($etap.status // "") == "todo" then "Start etapu \($etap.opis | ascii_downcase)"
     elif ($w_toku | length) > 0 then
       "Dokończenie " + ([$w_toku[] | "#\(.nr)"] | join(", "))
       + (if ($gotowe | length) > 0 then ", potem " + ([$gotowe[0:3][] | "#\(.nr)"] | join(", ")) else "" end)
     elif ($gotowe | length) > 0 then "Start " + ([$gotowe[0:3][] | "#\(.nr)"] | join(", "))
     elif $etap.klucz == "wydanie" then "Odbiór: scenariusze odbioru i Twoja akceptacja"
     else "Orkiestrator ustala następny krok" end) as $nastepny
  | (($w_toku | length) + ($todo | length)) as $pozostale
  | (if $pozostale == 0 then null
     elif $srednia == 0 then "brak danych (pierwsze zadania)"
     else ((($pozostale + $rownolegle - 1) / $rownolegle | floor) * $srednia) as $m
       | "ok. \(slownie($m * 60)) pracy agentów (\($pozostale) zadań, średnio \(slownie($srednia * 60)) na zadanie, \($rownolegle) równolegle; orientacyjnie)" end) as $szac
  | {
      nazwa: $nazwa, tryb: $tryb, etap: $etap, przebieg: ($przebieg_od != ""), nastepny: $nastepny, szacunek: $szac,
      postep_etapy: $postep_etapy, postep_zadan: $postep_zadan,
      czeka: $czeka, w_toku: $w_toku, gotowe: $gotowe, zaplanowane: $zaplanowane,
      zrobione: ($zrobione_b | ostatnio),
      zrobione_wczesniej: (([$z[] | select(.status == "done")] | length) - ($zrobione_b | length)),
      anulowane: [$biezace[] | select(.status == "anulowane")],
      wszystkie_zrobione: ([$z[] | select(.status == "done")] | ostatnio),
      wszystkie_anulowane: [$z[] | select(.status == "anulowane")],
      zadania_lacznie: ([$z[] | select(.status != "anulowane")] | length),
      eskalacje: $otwarte_esk, eskalacje_zamkniete: [$esk[0][] | select(.status != "otwarta") | .id],
      dokumenty: $dok[0], wstrzymania: $wstrz[0],
      tabela: $z
    }
  | .w_toku |= map(. + {od_slownie: slownie(czas(.start))})
  | .czeka |= map(. + {od_slownie: slownie(czas(.od))})
' >"$TMP/stan.json"

# --- index.md -----------------------------------------------------------------------------------

{
  echo "$START"
  echo "| Zadanie | Tytuł | Status | Iteracja | Kamień milowy | PR | CI |"
  echo "|---|---|---|---|---|---|---|"
  jq -r '.tabela[] | "| #\(.nr) | \(.tytul | gsub("\\|"; "\\|")) | \(.status) | \(.iter) | \(.kamien) | \(if .pr then "#\(.pr) \(.pr_stan)" else "-" end) | \(.ci) |"' "$TMP/stan.json"
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

# --- Projekt.md (treść) -------------------------------------------------------------------------

jq -r --argjson ile "$OSTATNICH" '
  def komorka: tostring | gsub("\\|"; "\\|") | gsub("\n"; " ");
  def stan_slownie:
    {"in-progress": "worker", "review": "review", "escalated": "eskalacja", "blocked": "zablokowane"}[.] // .;
  def link($p): "[\($p | split("/") | last | rtrimstr(".md"))](\($p))";
  def pr: if .pr then "#\(.pr)" else "-" end;
  (if .przebieg then {w: "przebiegu", wcz: "Wcześniejsze przebiegi"} else {w: "zleceniu", wcz: "Wcześniejsze zlecenia"} end) as $j
  | "## Gdzie jesteśmy",
  "",
  "- **Etap:** \(.etap.opis)",
  "- **Postęp:** Etapy \(if .postep_etapy then "\(.postep_etapy.x)/\(.postep_etapy.y)" else "–" end) · Zadania \(.postep_zadan.x)/\(.postep_zadan.y)"
    + (if .zadania_lacznie > .postep_zadan.y then " w bieżącym \($j.w) (łącznie \(.zadania_lacznie))" else "" end),
  "- **Co się dzieje:** " + (if (.w_toku | length) > 0
      then ([.w_toku[] | "#\(.nr) \(.tytul) (\(.status | stan_slownie)\(if .iter > 1 then ", iteracja \(.iter)" else "" end)\(if .od_slownie != "-" then ", od \(.od_slownie)" else "" end))"] | join("; "))
      elif (.etap.status // "") != "" then "etap \(.etap.opis | ascii_downcase) \({"todo": "jeszcze nie rozpoczęty", "in-progress": "w przygotowaniu", "review": "w review", "escalated": "wstrzymany eskalacją"}[.etap.status] // .etap.status)"
      else "nic w toku" end),
  "- **Następny krok:** \(.nastepny)",
  (if .szacunek then "- **Szacowany czas:** \(.szacunek)" else empty end),
  (if (.wstrzymania | length) > 0 then "- **Wstrzymania:** " + (.wstrzymania | join("; ")) else empty end),
  "",
  "## Czeka na Ciebie",
  "",
  (if (.czeka | length) > 0 then
     (.czeka | to_entries[] | .value as $c
       | "\(.key + 1). \($c.co)" + (if $c.od_slownie != "-" then " (czeka \($c.od_slownie))" else "" end)
         + "  \n   Wpisz orkiestratorowi: `\($c.wpisz)`"
         + (if ($c.opcje | length) > 0 then "  \n   " + ($c.opcje | join("; ")) else "" end))
   elif .etap.klucz == "zakonczony" then "Nic. Projekt zakończony."
   else "Nic. Agenci pracują sami." end),
  "",
  "## Zadania",
  "",
  (if (.w_toku | length) + (.gotowe | length) + (.zaplanowane | length) == 0 then "Nic w toku.", "" else empty end),
  (if (.w_toku | length) > 0 then
    "### W realizacji (\(.w_toku | length))", "",
    "| Zadanie | Kamień | Kto | Iteracja | PR | CI | Od |", "|---|---|---|---|---|---|---|",
    (.w_toku[] | "| #\(.nr) \(.tytul | komorka) | \(.kamien) | \(.status | stan_slownie) | \(.iter) | \(pr) | \(.ci) | \(.od_slownie) |"), ""
   else empty end),
  (if (.gotowe | length) > 0 then
    "### Gotowe do startu (\(.gotowe | length))", "",
    "| Zadanie | Kamień | Zależności |", "|---|---|---|",
    (.gotowe[] | "| #\(.nr) \(.tytul | komorka) | \(.kamien) | \(if (.zal | length) > 0 then ([.zal[] | "#\(.) ✓"] | join(", ")) else "brak" end) |"), ""
   else empty end),
  (if (.zaplanowane | length) > 0 then
    "### Zaplanowane (\(.zaplanowane | length))", "",
    "| Zadanie | Kamień | Czeka na |", "|---|---|---|",
    (.zaplanowane[] | "| #\(.nr) \(.tytul | komorka) | \(.kamien) | \([.czeka_na[] | "#\(.)"] | join(", ")) |"), ""
   else empty end),
  "### Zrobione w bieżącym \($j.w) (\(.zrobione | length))",
  "",
  (if (.zrobione | length) == 0 then "Jeszcze nic." else
    "| Zadanie | Kamień | PR |", "|---|---|---|",
    (.zrobione[0:$ile][] | "| #\(.nr) \(.tytul | komorka) | \(.kamien) | \(pr) |") end),
  (if (.zrobione | length) > $ile then "", "Ostatnie \($ile) z \(.zrobione | length). Pełna lista: [Historia](historia.md)."
   elif .zrobione_wczesniej > 0 then "", "\($j.wcz) (\(.zrobione_wczesniej) zadań): [Historia](historia.md)."
   else empty end),
  (if (.anulowane | length) > 0 then
    "", "### Anulowane w bieżącym \($j.w) (\(.anulowane | length))", "",
    (.anulowane[] | "- #\(.nr) \(.tytul)")
   else empty end),
  "",
  "## Eskalacje i pytania",
  "",
  (if (.eskalacje | length) == 0 then "Otwartych brak." else
    "| Nr | Rodzaj | Dotyczy | Powód |", "|---|---|---|---|",
    (.eskalacje[] | "| \(.id) | \(if .typ == "pytanie" then "pytanie" else "eskalacja" end) | \(.dotyczy) | \(.powod | komorka) |") end),
  (if (.eskalacje_zamkniete | length) > 0 then "",
    "Zamknięte (\(.eskalacje_zamkniete | length)): " + ([.eskalacje_zamkniete[] | "[\(.)](07-realizacja/escalations/\(.).md)"] | join(", ")) + "."
   else empty end),
  "",
  "## Dokumenty",
  "",
  ([.dokumenty[] | select(test("^00-intake/funkcje/") | not)] | .[] |
    if . == "00-intake/specyfikacja.md" then "- [Specyfikacja](\(.))"
    elif . == "00-intake/lista-startowa.md" then "- [Lista startowa](\(.))"
    elif test("plan\\.md$") then "- [Plan](\(.))"
    elif . == "04-architektura/architektura.md" then "- [Architektura](\(.))"
    elif . == "decyzje.md" then "- [Decyzje](\(.))"
    elif test("^08-qa/raport-") then "- [Raport QA \(split("raport-")[1] | rtrimstr(".md"))](\(.))"
    else "- \(link(.))" end),
  (([.dokumenty[] | select(test("^00-intake/funkcje/"))]) as $k
    | if ($k | length) > 0 then "- Karty funkcji: " + ([$k[] | link(.)] | join(", ")) else empty end),
  "- [Historia](historia.md): punkt przekazania, dziennik etapów, wszystkie zadania"
' "$TMP/stan.json" >"$TMP/tresc.md"

frontmatter() {
  jq -r --arg sync "$1" '
    "---",
    "projekt: \(.nazwa)",
    "tryb: \(.tryb)",
    "etap_opis: \(.etap.opis | tojson)",
    "postep_etapy: \(if .postep_etapy then "\(.postep_etapy.x)/\(.postep_etapy.y)" else "-" end | tojson)",
    "postep_zadania: \("\(.postep_zadan.x)/\(.postep_zadan.y)" | tojson)",
    "czeka_na_ciebie: \(.czeka | length)",
    "eskalacje: \(.eskalacje | length)",
    "nastepny_krok: \(.nastepny | tojson)",
    "ostatnia_synchronizacja: \($sync)",
    "---"' "$TMP/stan.json"
}

zloz_projekt() {
  frontmatter "$1"
  printf '\n# %s\n\n' "$NAZWA"
  printf '<!-- Plik generuje scripts/sync-status.sh przy każdej zmianie stanu. Nie edytuj go ręcznie. -->\n\n'
  cat "$TMP/tresc.md"
}

# --- historia.md --------------------------------------------------------------------------------

jq -r '
  def komorka: tostring | gsub("\\|"; "\\|") | gsub("\n"; " ");
  "<!-- Blok generuje scripts/sync-status.sh. Nie edytuj go ręcznie. -->",
  "",
  "## Wszystkie zadania zrobione (\(.wszystkie_zrobione | length))",
  "",
  (if (.wszystkie_zrobione | length) == 0 then "Jeszcze nic." else
    "| Zadanie | Kamień | PR | Zamknięte |", "|---|---|---|---|",
    (.wszystkie_zrobione[] | "| #\(.nr) \(.tytul | komorka) | \(.kamien) | \(if .pr then "#\(.pr)" else "-" end) | \(if .zamkniete != "" then .zamkniete[0:10] else "-" end) |") end),
  (if (.wszystkie_anulowane | length) > 0 then
    "", "## Wszystkie zadania anulowane (\(.wszystkie_anulowane | length))", "",
    (.wszystkie_anulowane[] | "- #\(.nr) \(.tytul)")
   else empty end)
' "$TMP/stan.json" >"$TMP/blok-historii.md"

# Część ręczna historii: z obecnej historia.md (poza blokiem) albo nowa. „Punkt przekazania” i
# „Dziennik etapów” ze starego Projekt.md albo status.md przechodzą tutaj: punkt przekazania
# zastępuje ten w historii, brakujące wpisy dziennika są dopisywane.
ZRODLO=""
if [ -f "$PROJEKT_MD" ] && grep -qE '^## (Punkt przekazania|Dziennik etapów)$' "$PROJEKT_MD"; then
  ZRODLO="$PROJEKT_MD"
elif [ -f "$STARY" ]; then
  ZRODLO="$STARY"
fi
STARE_PRZEK="$( [ -n "$ZRODLO" ] && sekcja "$ZRODLO" "Punkt przekazania" || true)"
STARY_DZIEN="$( [ -n "$ZRODLO" ] && sekcja "$ZRODLO" "Dziennik etapów" || true)"
case "$STARE_PRZEK" in *"(brak)") STARE_PRZEK="" ;; esac

if [ -f "$HISTORIA" ]; then
  awk -v s="$H_START" -v k="$H_KONIEC" '$0 == s { w = 1 } !w { print } $0 == k { w = 0 }' "$HISTORIA" |
    awk 'NF { for (; p > 0; p--) print ""; print; next } { p++ }' >"$TMP/reczna.md"
  grep -qxF '## Punkt przekazania' "$TMP/reczna.md" || printf '\n## Punkt przekazania\n\n(brak)\n' >>"$TMP/reczna.md"
  grep -qxF '## Dziennik etapów' "$TMP/reczna.md" || printf '\n## Dziennik etapów\n\n(brak)\n' >>"$TMP/reczna.md"
else
  printf '# Historia projektu\n\nPunkt przekazania wpisuje orkiestrator po kamieniu milowym, dziennik etapów `shctl stage`, a listę\nzadań `scripts/sync-status.sh`.\n\n## Punkt przekazania\n\n(brak)\n\n## Dziennik etapów\n\n(brak)\n' >"$TMP/reczna.md"
fi

# Zastępuje treść sekcji „## NAZWA” w pliku (do następnego nagłówka ## albo końca).
zastap_sekcje() {
  local plik="$1" nazwa="$2" tresc="$3"
  printf '%s\n' "$tresc" >"$TMP/sekcja.txt"
  awk -v n="## $nazwa" -v t="$TMP/sekcja.txt" '
    $0 == n { print; print ""; while ((getline l < t) > 0) print l; close(t); print ""; w = 1; next }
    w && /^## / { w = 0 }
    !w { print }' "$plik" | awk 'NF { for (; p > 0; p--) print ""; print; next } { p++ }' >"$TMP/sekcja.out"
  mv "$TMP/sekcja.out" "$plik"
}

[ -z "$STARE_PRZEK" ] || zastap_sekcje "$TMP/reczna.md" "Punkt przekazania" "$STARE_PRZEK"
if [ -n "$STARY_DZIEN" ]; then
  obecny="$(sekcja "$TMP/reczna.md" "Dziennik etapów" | grep -vxF '(brak)' || true)"
  nowe="$(printf '%s\n' "$STARY_DZIEN" | while IFS= read -r l; do
    [ -z "$l" ] || printf '%s\n' "$obecny" | grep -qxF -- "$l" || printf '%s\n' "$l"
  done)"
  [ -z "$nowe" ] || zastap_sekcje "$TMP/reczna.md" "Dziennik etapów" "${obecny:+$obecny
}$nowe"
fi

{
  cat "$TMP/reczna.md"
  printf '\n%s\n' "$H_START"
  cat "$TMP/blok-historii.md"
  printf '%s\n' "$H_KONIEC"
} >"$TMP/historia.md"

# --- Zapis --------------------------------------------------------------------------------------

STARA_SYNC="$( [ -f "$PROJEKT_MD" ] && fm_get "$PROJEKT_MD" ostatnia_synchronizacja || true)"
[ -n "$STARA_SYNC" ] || STARA_SYNC=brak
zloz_projekt "$STARA_SYNC" >"$TMP/Projekt.md"
jq -c '[.czeka[] | {co, od, wpisz}]' "$TMP/stan.json" >"$TMP/czeka.json"

zmiany=0
cmp -s "$TMP/index.md" "$INDEKS" || zmiany=1
if [ -f "$PROJEKT_MD" ]; then cmp -s "$TMP/Projekt.md" "$PROJEKT_MD" || zmiany=1; else zmiany=1; fi
if [ -f "$HISTORIA" ]; then cmp -s "$TMP/historia.md" "$HISTORIA" || zmiany=1; else zmiany=1; fi
[ ! -f "$STARY" ] || zmiany=1

if [ "$DRY" -eq 1 ]; then
  cat "$TMP/Projekt.md"
  echo "sync-status: dry-run, zmiany: $zmiany"
  exit 0
fi

teraz_iso() { date -u -r "$TERAZ" +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date -u -d "@$TERAZ" +%Y-%m-%dT%H:%M:%SZ; }

if [ -n "$WYJSCIE" ]; then
  mkdir -p "$WYJSCIE"
  zloz_projekt "$(teraz_iso)" >"$WYJSCIE/Projekt.md"
  cp "$TMP/historia.md" "$WYJSCIE/historia.md"
  cp "$TMP/index.md" "$WYJSCIE/index.md"
  cp "$TMP/czeka.json" "$WYJSCIE/czeka.json"
  echo "sync-status: zapisano Projekt.md, historia.md, index.md i czeka.json w $WYJSCIE"
  exit 0
fi

# Lista „Czeka na Ciebie” dla przypomnień i shctl status (serwer SH; poza repo).
if [ -d "$SH_DIR/stan" ]; then
  mkdir -p "$SH_DIR/stan/czeka"
  cmp -s "$TMP/czeka.json" "$SH_DIR/stan/czeka/$NAZWA.json" 2>/dev/null ||
    cp "$TMP/czeka.json" "$SH_DIR/stan/czeka/$NAZWA.json"
fi

if [ "$zmiany" -eq 0 ]; then
  echo "sync-status: bez zmian"
  exit 0
fi

zloz_projekt "$(date -u +%Y-%m-%dT%H:%M:%SZ)" >"$TMP/Projekt.md"
cat "$TMP/index.md" >"$INDEKS"
cat "$TMP/Projekt.md" >"$PROJEKT_MD"
cat "$TMP/historia.md" >"$HISTORIA"
if [ -f "$STARY" ]; then
  rm -f "$STARY"
  echo "sync-status: docs/status.md zastąpiony przez docs/Projekt.md i docs/historia.md"
fi
echo "sync-status: zaktualizowano index.md, Projekt.md i historia.md"
