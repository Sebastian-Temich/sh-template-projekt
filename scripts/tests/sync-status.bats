#!/usr/bin/env bats
# Testy scripts/sync-status.sh na kopii repo: docs/Projekt.md, docs/historia.md, index.md, lista
# czeka dla serwera, wstrzymania, bieżące zlecenie, migracja ze status.md i starego Projekt.md.
# gh zastąpiony atrapą bez zadań albo danymi z --dane.
# Uruchomienie: bats scripts/tests/sync-status.bats

setup() {
  ROOT="$BATS_TEST_TMPDIR/repo"
  mkdir -p "$ROOT/scripts" "$BATS_TEST_TMPDIR/bin" "$BATS_TEST_TMPDIR/sh/stan" "$BATS_TEST_TMPDIR/dane"
  # Dane testowe, nigdy docs/ repo: te pliki zmienia orkiestrator (scripts/tests/dane/README.md).
  cp -R "$BATS_TEST_DIRNAME/dane/docs" "$ROOT/docs"
  cp "$BATS_TEST_DIRNAME/../sync-status.sh" "$ROOT/scripts/"
  printf '#!/bin/sh\necho "[]"\n' >"$BATS_TEST_TMPDIR/bin/gh"
  chmod +x "$BATS_TEST_TMPDIR/bin/gh"
  export PATH="$BATS_TEST_TMPDIR/bin:$PATH" SH_DIR="$BATS_TEST_TMPDIR/sh"
  # 2026-11-09T12:00:00Z
  export SH_TERAZ=1794225600
  D="$BATS_TEST_TMPDIR/dane"
}

P() { echo "$ROOT/docs/Projekt.md"; }
H() { echo "$ROOT/docs/historia.md"; }
fm() { awk -v k="$1" 'index($0, k ": ") == 1 { print substr($0, length(k) + 3); exit }' "$(P)"; }
sync() { bash "$ROOT/scripts/sync-status.sh" --nazwa demo "$@"; }
etap() { sed "s/^status: .*/status: $2/" "$ROOT/docs/$1/DoD.md" >"$ROOT/x" && mv "$ROOT/x" "$ROOT/docs/$1/DoD.md"; }
# Dopisuje linię frontmattera konfiguracji po tryb_procesu.
konfig() { awk -v l="$1" '{ print } /^tryb_procesu: / { print l }' "$ROOT/docs/konfiguracja.md" >"$ROOT/x" && mv "$ROOT/x" "$ROOT/docs/konfiguracja.md"; }

# Realizacja: etapy przygotowania done, zadania w różnych stanach.
realizacja() {
  for e in 00-intake 04-plan 06-zadania; do etap "$e" done; done
  cat >"$D/issues.json" <<'EOF'
[
 {"number":1,"title":"Szkielet","state":"CLOSED","stateReason":"COMPLETED","labels":[{"name":"iter:1"}],"milestone":{"title":"M1 Szkielet"},"body":"### Zależności\n\nbrak\n","createdAt":"2026-11-08T10:00:00Z","closedAt":"2026-11-08T12:00:00Z"},
 {"number":2,"title":"Koszyk","state":"OPEN","labels":[{"name":"status:in-progress"},{"name":"iter:2"}],"milestone":{"title":"M2 Koszyk"},"body":"### Zależności\n\n#1\n\n### Typ\n\nfeature\n","createdAt":"2026-11-08T10:00:00Z"},
 {"number":3,"title":"Katalog","state":"OPEN","labels":[{"name":"status:todo"}],"milestone":{"title":"M2 Koszyk"},"body":"### Zależności\n\n#1\n","createdAt":"2026-11-08T10:00:00Z"},
 {"number":4,"title":"Płatność","state":"OPEN","labels":[{"name":"status:todo"}],"milestone":{"title":"M3 Płatność"},"body":"### Zależności\n\n#2, #3\n","createdAt":"2026-11-08T10:00:00Z"},
 {"number":5,"title":"Stare","state":"CLOSED","stateReason":"NOT_PLANNED","labels":[],"milestone":null,"body":"","createdAt":"2026-11-08T10:00:00Z"},
 {"number":6,"title":"Eksport CSV","state":"OPEN","labels":[{"name":"status:review"},{"name":"tryb:S"},{"name":"iter:1"}],"milestone":null,"body":"","createdAt":"2026-11-09T09:00:00Z"}
]
EOF
  cat >"$D/prs.json" <<'EOF'
[
 {"number":10,"state":"MERGED","headRefName":"task/1-szkielet","closingIssuesReferences":[{"number":1}],"statusCheckRollup":[]},
 {"number":11,"state":"OPEN","headRefName":"task/2-koszyk","closingIssuesReferences":[{"number":2}],"statusCheckRollup":[{"status":"COMPLETED","conclusion":"FAILURE"}]},
 {"number":12,"state":"OPEN","headRefName":"task/6-eksport","closingIssuesReferences":[{"number":6}],"statusCheckRollup":[{"status":"COMPLETED","conclusion":"SUCCESS"}]}
]
EOF
  cat >"$D/otwarte.json" <<'EOF'
[
 {"number":12,"headRefName":"task/6-eksport","headRefOid":"abc","closingIssuesReferences":[{"number":6}],
  "comments":[{"body":"## Review Codex: PASS\n\n<!-- shctl:review head=abc werdykt=PASS -->","createdAt":"2026-11-09T06:00:00Z"}]}
]
EOF
  printf '{"zadania":{"2":{"start":"2026-11-09T10:30:00Z"}}}' >"$SH_DIR/stan/demo.json"
}

# Zamknięte zadania: M zadań trybu M utworzonych 2026-11-01, potem S zadań tryb:S (numery od 100);
# wszystkie etapy done.
zamkniete() {
  local m="$1" s="${2:-0}" e
  jq -n --argjson m "$m" --argjson s "$s" '
    [range(1; $m + 1) | {number: ., title: "Zadanie \(.)", state: "CLOSED", stateReason: "COMPLETED",
       labels: [{name: "tryb:M"}], milestone: {title: "M1"}, body: "",
       createdAt: "2026-11-01T10:00:00Z", closedAt: "2026-11-02T\(10 + .):00:00Z"}]
    + [range(100; 100 + $s) | {number: ., title: "Poprawka \(.)", state: "CLOSED", stateReason: "COMPLETED",
       labels: [{name: "tryb:S"}], milestone: null, body: "",
       createdAt: "2026-11-05T10:00:00Z", closedAt: "2026-11-06T10:00:00Z"}]' >"$D/issues.json"
  for e in 00-intake 04-plan 06-zadania 08-qa wydanie; do etap "$e" done; done
}

@test "Projekt.md: krotki frontmatter, sekcje, konczy sie Dokumentami; historia.md osobno" {
  run sync
  echo "$output"
  [ "$status" -eq 0 ]
  cat "$(P)"
  [ "$(awk 'NR > 1 && /^---$/ { exit } NR > 1 { sub(/:.*/, ""); print }' "$(P)" | paste -sd ' ' -)" = \
    "projekt tryb etap_opis postep_etapy postep_zadania czeka_na_ciebie eskalacje nastepny_krok ostatnia_synchronizacja" ]
  [ "$(fm etap_opis)" = '"Specyfikacja"' ]
  [ "$(fm postep_etapy)" = '"0/5"' ]
  [ "$(fm nastepny_krok)" = '"Start etapu specyfikacja"' ]
  grep -qF -- '- **Postęp:** Etapy 0/5 · Zadania 0/0' "$(P)"
  grep -qxF 'Nic. Agenci pracują sami.' "$(P)"
  grep -qxF 'Nic w toku.' "$(P)"
  ! grep -qE '### (W realizacji|Gotowe do startu|Zaplanowane)' "$(P)" || false
  ! grep -qE 'Punkt przekazania|Dziennik etapów|dataview' "$(P)" || false
  [ "$(tail -1 "$(P)")" = '- [Historia](historia.md): punkt przekazania, dziennik etapów, wszystkie zadania' ]
  grep -qxF '## Punkt przekazania' "$(H)"
  grep -qxF '## Dziennik etapów' "$(H)"
  grep -qxF '<!-- historia:start -->' "$(H)"
}

@test "powtorka bez zmian stanu niczego nie zmienia" {
  sync >/dev/null
  cp "$(P)" "$BATS_TEST_TMPDIR/przed"
  cp "$(H)" "$BATS_TEST_TMPDIR/przed-h"
  run sync
  [[ "$output" == *"bez zmian"* ]] || false
  cmp "$(P)" "$BATS_TEST_TMPDIR/przed"
  cmp "$(H)" "$BATS_TEST_TMPDIR/przed-h"
}

@test "wstrzymania z limity.md w Gdzie jestesmy, wpis brak sie nie liczy" {
  cat >"$SH_DIR/limity.md" <<'EOF'
# Limity

| Wykonawca | Od | Do | Źródło |
|---|---|---|---|
| claude | 2026-11-02 14:05 | 2026-11-02 19:00 | panel worker:sklep:12 |
- codex "do 20:30"
EOF
  run sync
  [ "$status" -eq 0 ]
  grep -qF -- '- **Wstrzymania:** claude · 2026-11-02 14:05 · 2026-11-02 19:00 · panel worker:sklep:12; codex "do 20:30"' "$(P)"
  [ "$(fm ostatnia_synchronizacja)" != brak ]
  printf '# Limity\n\n- (brak)\n' >"$SH_DIR/limity.md"
  run sync
  [ "$status" -eq 0 ]
  ! grep -q 'Wstrzymania' "$(P)" || false
}

@test "realizacja: zadania wedlug stanu, postep w dwoch jednostkach, czas w toku" {
  realizacja
  run sync --dane "$D"
  echo "$output"
  [ "$status" -eq 0 ]
  cat "$(P)"
  [ "$(fm postep_etapy)" = '"3/5"' ]
  [ "$(fm postep_zadania)" = '"1/5"' ]
  grep -qF -- '- **Postęp:** Etapy 3/5 · Zadania 1/5' "$(P)"
  grep -qF -- '- **Etap:** Realizacja, kamień M2 Koszyk' "$(P)"
  grep -qF '#2 Koszyk (worker, iteracja 2, od 1 h 30 min)' "$(P)"
  grep -qF '| #2 Koszyk | M2 Koszyk | worker | 2 | #11 | fail | 1 h 30 min |' "$(P)"
  grep -qF '### Gotowe do startu (1)' "$(P)"
  grep -qF '| #3 Katalog | M2 Koszyk | #1 ✓ |' "$(P)"
  grep -qF '| #4 Płatność | M3 Płatność | #2, #3 |' "$(P)"
  grep -qF '### Zrobione w bieżącym zleceniu (1)' "$(P)"
  grep -qF -- '- #5 Stare' "$(P)"
  ! grep -qxF 'Nic w toku.' "$(P)" || false
  grep -qF '| #2 | Koszyk | in-progress | 2 | M2 Koszyk | #11 open | fail |' "$ROOT/docs/06-zadania/index.md"
  grep -qF '| #1 Szkielet | M1 Szkielet | #10 | 2026-11-08 |' "$(H)"
}

@test "czeka na ciebie: tekst do wpisania w Projekt.md, lista z czasem w stan/czeka" {
  realizacja
  mkdir -p "$ROOT/docs/07-realizacja/escalations"
  printf -- '---\nid: E-001\nstatus: otwarta\ndotyczy: "#2"\npowod: brak klucza Stripe\notwarto: 2026-11-09T07:00:00Z\n---\n\n# E\n\n## Opcje i rekomendacja\n\n- A: czekać\n- B: atrapa\n\n## Czego potrzeba od właściciela\n' \
    >"$ROOT/docs/07-realizacja/escalations/E-001.md"
  printf -- '---\nid: E-002\nstatus: otwarta\ntyp: pytanie\ndotyczy: "#3"\npowod: "W-02: komunikat pustego katalogu"\notwarto: 2026-11-09T11:00:00Z\n---\n\n# E\n' \
    >"$ROOT/docs/07-realizacja/escalations/E-002.md"
  printf '# Lista startowa\n\n- [x] Vercel\n- [ ] Stripe: klucze testowe (W-03), JAK: Dashboard\n' >"$ROOT/docs/00-intake/lista-startowa.md"
  run sync --dane "$D"
  echo "$output"
  [ "$status" -eq 0 ]
  cat "$(P)"
  [ "$(fm czeka_na_ciebie)" = 4 ]
  [ "$(fm eskalacje)" = 2 ]
  grep -qF '1. E-001 (#2): brak klucza Stripe (czeka 5 h)' "$(P)"
  grep -qF 'Wpisz orkiestratorowi: `E-001: A`' "$(P)"
  grep -qF 'E-002 (#3, pytanie): W-02: komunikat pustego katalogu (czeka 1 h)' "$(P)"
  grep -qF 'Lista startowa: Stripe: klucze testowe (W-03), JAK: Dashboard' "$(P)"
  grep -qF 'Wpisz orkiestratorowi: `gotowe: Stripe`' "$(P)"
  grep -qF 'Odbiór zlecenia S #6 Eksport CSV (PR #12, review PASS) (czeka 6 h)' "$(P)"
  grep -qF 'Wpisz orkiestratorowi: `odbieram #6`' "$(P)"
  [ "$(fm nastepny_krok)" = '"Twoja odpowiedź: E-001 (#2): brak klucza Stripe"' ]
  grep -qF '| E-002 | pytanie | #3 | W-02: komunikat pustego katalogu |' "$(P)"
  [ "$(jq -r '.[0].od' "$SH_DIR/stan/czeka/demo.json")" = 2026-11-09T07:00:00Z ]
  [ "$(jq -r '.[0].wpisz' "$SH_DIR/stan/czeka/demo.json")" = 'E-001: A' ]
  [ "$(jq length "$SH_DIR/stan/czeka/demo.json")" = 4 ]
}

@test "odbior_S auto_bez_zmian_widocznych: zlecenie bez zmian widocznych nie czeka na wlasciciela" {
  realizacja
  konfig 'odbior_S: auto_bez_zmian_widocznych'
  jq 'map(if .number == 6 then .labels += [{"name":"widoczne:nie"}] else . end)' "$D/issues.json" >"$D/x" && mv "$D/x" "$D/issues.json"
  run sync --dane "$D"
  [ "$status" -eq 0 ]
  ! grep -q 'odbieram #6' "$(P)" || false
}

@test "checkpoint etapu po PASS: akceptacja z tekstem do wpisania" {
  etap 00-intake review
  printf '[{"number":2,"headRefName":"stage/00-intake","headRefOid":"def","closingIssuesReferences":[],"comments":[{"body":"<!-- shctl:review head=def werdykt=PASS -->","createdAt":"2026-11-09T08:00:00Z"}]}]' >"$D/otwarte.json"
  run sync --dane "$D"
  [ "$status" -eq 0 ]
  grep -qF 'Akceptacja: Specyfikacja (PR #2, review PASS) (czeka 4 h)' "$(P)"
  grep -qF '`akceptuję specyfikacja PR #2`' "$(P)"
}

@test "dokumenty: specyfikacja, karty funkcji, plan, decyzje, raporty QA, historia" {
  mkdir -p "$ROOT/docs/00-intake/funkcje" "$ROOT/docs/04-plan" "$ROOT/docs/08-qa"
  : >"$ROOT/docs/00-intake/specyfikacja.md"
  : >"$ROOT/docs/00-intake/funkcje/W-01.md"
  : >"$ROOT/docs/00-intake/funkcje/W-02.md"
  : >"$ROOT/docs/04-plan/plan.md"
  : >"$ROOT/docs/08-qa/raport-M1.md"
  run sync
  [ "$status" -eq 0 ]
  grep -qF -- '- [Specyfikacja](00-intake/specyfikacja.md)' "$(P)"
  grep -qF -- '- Karty funkcji: [W-01](00-intake/funkcje/W-01.md), [W-02](00-intake/funkcje/W-02.md)' "$(P)"
  grep -qF -- '- [Plan](04-plan/plan.md)' "$(P)"
  grep -qF -- '- [Raport QA M1](08-qa/raport-M1.md)' "$(P)"
  [ "$(tail -1 "$(P)")" = '- [Historia](historia.md): punkt przekazania, dziennik etapów, wszystkie zadania' ]
}

@test "szacowany czas z metryk" {
  realizacja
  printf '# Metryki\n\n| Zlecenie | Tryb | Czas | Zadania | Iteracje | Eskalacje | Uwagi |\n|---|---|---|---|---|---|---|\n| #1 Szkielet | M | 1h 0min | 1 | 1 | 0 | PR #10 |\n| #9 X | M | 30min | 1 | 1 | 0 | PR #9 |\n' >"$ROOT/docs/metryki.md"
  run sync --dane "$D"
  [ "$status" -eq 0 ]
  grep -qF -- '- **Szacowany czas:** ok. 1 h 30 min pracy agentów (4 zadań, średnio 45 min na zadanie, 2 równolegle; orientacyjnie)' "$(P)"
}

@test "zakonczony projekt: Nic. Projekt zakonczony., zrobione tylko z ostatniego zlecenia S" {
  zamkniete 4 2
  run sync --dane "$D"
  echo "$output"
  [ "$status" -eq 0 ]
  cat "$(P)"
  [ "$(fm etap_opis)" = '"Zakończony"' ]
  grep -qxF 'Nic. Projekt zakończony.' "$(P)"
  grep -qxF -- '- **Postęp:** Etapy 5/5 · Zadania 2/2 w bieżącym zleceniu (łącznie 6)' "$(P)"
  [ "$(fm postep_zadania)" = '"2/2"' ]
  grep -qF '### Zrobione w bieżącym zleceniu (2)' "$(P)"
  grep -qF '| #101 Poprawka 101 |' "$(P)"
  ! grep -qF '#4 Zadanie 4' "$(P)" || false
  grep -qF 'Wcześniejsze zlecenia (4 zadań): [Historia](historia.md).' "$(P)"
  grep -qF '## Wszystkie zadania zrobione (6)' "$(H)"
  grep -qF '| #4 Zadanie 4 | M1 | - | 2026-11-02 |' "$(H)"
}

@test "zrobione: najwyzej 10 ostatnich, reszta w historii" {
  zamkniete 12
  run sync --dane "$D"
  [ "$status" -eq 0 ]
  cat "$(P)"
  grep -qF '### Zrobione w bieżącym zleceniu (12)' "$(P)"
  [ "$(grep -c '^| #[0-9]* Zadanie' "$(P)")" -eq 10 ]
  grep -qF '| #12 Zadanie 12 |' "$(P)"
  ! grep -qF '| #2 Zadanie 2 |' "$(P)" || false
  grep -qF 'Ostatnie 10 z 12. Pełna lista: [Historia](historia.md).' "$(P)"
  grep -qF '| #1 Zadanie 1 |' "$(H)"
}

@test "przebieg dryrun: zadania od resetu, etapy przygotowania i wydanie w todo pominiete" {
  zamkniete 3
  jq '. + [{number: 20, title: "Nowe", state: "CLOSED", stateReason: "COMPLETED", labels: [], milestone: {title: "M1"},
    body: "", createdAt: "2026-11-04T22:28:00Z", closedAt: "2026-11-04T23:00:00Z"},
    {number: 21, title: "Drugie", state: "OPEN", labels: [{name: "status:todo"}], milestone: {title: "M1"},
    body: "", createdAt: "2026-11-04T22:28:00Z"}]' "$D/issues.json" >"$D/x" && mv "$D/x" "$D/issues.json"
  for e in 00-intake 04-plan 06-zadania 08-qa wydanie; do etap "$e" todo; done
  printf '# Metryki\n\n## Przebieg dryrun 3: max_local=2 (2026-11-04)\n\nReset do baseline `624bd6f` o 22:27 UTC.\n' >"$ROOT/docs/metryki.md"
  run sync --dane "$D"
  [ "$status" -eq 0 ]
  cat "$(P)"
  grep -qxF -- '- **Postęp:** Etapy 0/1 · Zadania 1/2 w bieżącym przebiegu (łącznie 5)' "$(P)"
  grep -qF -- '- **Etap:** Realizacja, kamień M1' "$(P)"
  grep -qF '### Zrobione w bieżącym przebiegu (1)' "$(P)"
  grep -qF 'Wcześniejsze przebiegi (3 zadań): [Historia](historia.md).' "$(P)"
}

@test "przebieg dryrun po QA: wydanie pominiete, przebieg zakonczony" {
  zamkniete 3
  jq '. + [{number: 20, title: "Nowe", state: "CLOSED", stateReason: "COMPLETED", labels: [], milestone: {title: "M1"},
    body: "", createdAt: "2026-11-04T22:28:00Z", closedAt: "2026-11-04T23:00:00Z"}]' "$D/issues.json" >"$D/x" && mv "$D/x" "$D/issues.json"
  for e in 00-intake 04-plan 06-zadania wydanie; do etap "$e" todo; done
  printf '# Metryki\n\n## Przebieg dryrun 3: max_local=2 (2026-11-04)\n\nReset do baseline `624bd6f` o 22:27 UTC.\n' >"$ROOT/docs/metryki.md"
  run sync --dane "$D"
  [ "$status" -eq 0 ]
  cat "$(P)"
  [ "$(fm etap_opis)" = '"Zakończony"' ]
  grep -qxF -- '- **Postęp:** Etapy 1/1 · Zadania 1/1 w bieżącym przebiegu (łącznie 4)' "$(P)"
  grep -qxF 'Nic. Projekt zakończony.' "$(P)"
}

@test "kazdy naglowek wystepuje raz w Projekt.md i historia.md (rozne stany)" {
  local stan
  for stan in poczatek realizacja zamkniete; do
    case "$stan" in
      realizacja) realizacja ;;
      zamkniete) zamkniete 12 3 ;;
    esac
    run sync --dane "$D"
    [ "$status" -eq 0 ]
    [ -z "$(grep -E '^#{1,6} ' "$(P)" | sort | uniq -d)" ] || { echo "$stan Projekt.md"; grep -E '^#' "$(P)"; false; }
    [ -z "$(grep -E '^#{1,6} ' "$(H)" | sort | uniq -d)" ] || { echo "$stan historia.md"; grep -E '^#' "$(H)"; false; }
    [ "$(grep -c '^# ' "$(P)")" -eq 1 ]
  done
}

@test "zamkniete eskalacje jako linki do plikow" {
  realizacja
  mkdir -p "$ROOT/docs/07-realizacja/escalations"
  printf -- '---\nid: E-001\nstatus: zamknieta\ndotyczy: "#2"\npowod: x\n---\n' >"$ROOT/docs/07-realizacja/escalations/E-001.md"
  printf -- '---\nid: E-002\nstatus: zamknieta\ndotyczy: "#3"\npowod: y\n---\n' >"$ROOT/docs/07-realizacja/escalations/E-002.md"
  run sync --dane "$D"
  [ "$status" -eq 0 ]
  grep -qxF 'Zamknięte (2): [E-001](07-realizacja/escalations/E-001.md), [E-002](07-realizacja/escalations/E-002.md).' "$(P)"
  ! grep -qF '`07-realizacja/escalations/`' "$(P)" || false
}

@test "zlecenie_od z konfiguracji wyznacza biezace zlecenie" {
  zamkniete 3
  jq 'map(if .number == 3 then .createdAt = "2026-11-03T10:00:00Z" else . end)' "$D/issues.json" >"$D/x" && mv "$D/x" "$D/issues.json"
  konfig 'zlecenie_od: "2026-11-03T00:00:00Z"'
  run sync --dane "$D"
  [ "$status" -eq 0 ]
  grep -qF '### Zrobione w bieżącym zleceniu (1)' "$(P)"
  grep -qF '| #3 Zadanie 3 |' "$(P)"
  grep -qF 'Wcześniejsze zlecenia (2 zadań)' "$(P)"
}

@test "migracja: status.md znika, historia.md przejmuje punkt przekazania i dziennik" {
  rm "$(P)" "$(H)"
  printf -- '---\nzadania_todo: 0\n---\n\n# Status projektu\n\n## Bieżący etap\n\n(brak)\n\n## Punkt przekazania\n\nKamień M1 zakończony.\n\n## Dziennik etapów\n\n- 2026-11-05 `00-intake`: done\n' >"$ROOT/docs/status.md"
  run sync
  echo "$output"
  [ "$status" -eq 0 ]
  [ ! -e "$ROOT/docs/status.md" ]
  grep -qxF 'Kamień M1 zakończony.' "$(H)"
  grep -qxF -- '- 2026-11-05 `00-intake`: done' "$(H)"
  ! grep -qE 'Bieżący etap|Kamień M1' "$(P)" || false
}

@test "migracja: sekcje pod blokiem starego Projekt.md przechodza do historii" {
  rm "$(H)"
  printf -- '---\npostep: "1/5"\n---\n\n# demo\n\n<!-- projekt:start -->\n\n## Gdzie jesteśmy\n\n- stare\n\n<!-- projekt:end -->\n\n## Punkt przekazania\n\nPo M1.\n\n## Dziennik etapów\n\n- 2026-11-05 `00-intake`: done\n' >"$(P)"
  run sync
  [ "$status" -eq 0 ]
  cat "$(H)"
  grep -qxF 'Po M1.' "$(H)"
  grep -qxF -- '- 2026-11-05 `00-intake`: done' "$(H)"
  ! grep -qE 'Po M1|projekt:start|postep:' "$(P)" || false
  # Wpis dopisany później do Projekt.md (stary skill) też trafia do historii, bez powtórzeń.
  printf '\n## Dziennik etapów\n\n- 2026-11-05 `00-intake`: done\n- 2026-11-06 `04-plan`: done\n' >>"$(P)"
  run sync
  [ "$status" -eq 0 ]
  [ "$(grep -c '00-intake`: done' "$(H)")" -eq 1 ]
  grep -qxF -- '- 2026-11-06 `04-plan`: done' "$(H)"
  ! grep -q 'Dziennik' "$(P)" || false
}

@test "punkt przekazania i dziennik w historii zostaja po synchronizacji" {
  sync >/dev/null
  awk '{ print } /^## Punkt przekazania$/ { print ""; print "Ręczny wpis orkiestratora." }' "$(H)" >"$ROOT/x" && mv "$ROOT/x" "$(H)"
  realizacja
  run sync --dane "$D"
  [ "$status" -eq 0 ]
  grep -qxF 'Ręczny wpis orkiestratora.' "$(H)"
  grep -qF '## Wszystkie zadania zrobione (1)' "$(H)"
}

@test "--wyjscie zapisuje podglad bez zmian w docs i stan" {
  cp "$(P)" "$BATS_TEST_TMPDIR/przed"
  realizacja
  run sync --dane "$D" --wyjscie "$BATS_TEST_TMPDIR/podglad"
  [ "$status" -eq 0 ]
  cmp "$(P)" "$BATS_TEST_TMPDIR/przed"
  grep -qF '#2 Koszyk' "$BATS_TEST_TMPDIR/podglad/Projekt.md"
  [ -f "$BATS_TEST_TMPDIR/podglad/historia.md" ]
  [ -f "$BATS_TEST_TMPDIR/podglad/czeka.json" ]
  [ ! -e "$SH_DIR/stan/czeka/demo.json" ]
}

@test "eskalacja z opcja bez etykiety: pelny tekst do wpisania (dryrun 5)" {
  realizacja
  mkdir -p "$ROOT/docs/07-realizacja/escalations"
  printf -- '---\nid: E-001\nstatus: otwarta\ndotyczy: "#2"\npowod: sprzeczne kryteria\notwarto: 2026-11-09T07:00:00Z\n---\n\n# E\n\n## Opcje i rekomendacja\n\n- Zamknąć #2 jako niewykonalne (proponowane)\n- Zmienić kryterium K2\n\n## Czego potrzeba od właściciela\n' \
    >"$ROOT/docs/07-realizacja/escalations/E-001.md"
  run sync --dane "$D"
  [ "$status" -eq 0 ]
  grep -qF 'Wpisz orkiestratorowi: `E-001: Zamknąć #2 jako niewykonalne (proponowane)`' "$(P)"
  # Etykieta „2)” zostaje skrótem.
  sed 's/^- Zamknąć/- 2) Zamknąć/' "$ROOT/docs/07-realizacja/escalations/E-001.md" >"$ROOT/x" && mv "$ROOT/x" "$ROOT/docs/07-realizacja/escalations/E-001.md"
  run sync --dane "$D"
  grep -qF 'Wpisz orkiestratorowi: `E-001: 2`' "$(P)"
}

@test "zaleznosci tylko z pola strukturalnego: notatka z #NR pod lista nie blokuje" {
  realizacja
  jq 'map(if .number == 4 then .body = "### Zależności\n\n#3\n\nWcześniej też #2 (usunięte po E-001).\n" else . end)' "$D/issues.json" >"$D/x" && mv "$D/x" "$D/issues.json"
  run sync --dane "$D"
  [ "$status" -eq 0 ]
  cat "$(P)"
  grep -qF '### Gotowe do startu (1)' "$(P)"
  grep -qF '### Zaplanowane (1)' "$(P)"
  jq 'map(if .number == 4 then .body = "### Zależności\n\nbrak\n\nUwaga: #2 i #3 nie blokują.\n" else . end)' "$D/issues.json" >"$D/x" && mv "$D/x" "$D/issues.json"
  run sync --dane "$D"
  grep -qF '### Gotowe do startu (2)' "$(P)"
}
