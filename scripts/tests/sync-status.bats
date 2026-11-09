#!/usr/bin/env bats
# Testy scripts/sync-status.sh na kopii repo: docs/Projekt.md, index.md, wstrzymania, migracja ze
# status.md. gh zastąpiony atrapą bez zadań albo danymi z --dane.
# Uruchomienie: bats scripts/tests/sync-status.bats

setup() {
  ROOT="$BATS_TEST_TMPDIR/repo"
  mkdir -p "$ROOT/scripts" "$BATS_TEST_TMPDIR/bin" "$BATS_TEST_TMPDIR/sh" "$BATS_TEST_TMPDIR/dane"
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
fm() { awk -v k="$1" 'index($0, k ": ") == 1 { print substr($0, length(k) + 3); exit }' "$(P)"; }
sync() { bash "$ROOT/scripts/sync-status.sh" --nazwa demo "$@"; }
etap() { sed "s/^status: .*/status: $2/" "$ROOT/docs/$1/DoD.md" >"$ROOT/x" && mv "$ROOT/x" "$ROOT/docs/$1/DoD.md"; }

# Realizacja: etapy przygotowania done, zadania w różnych stanach.
realizacja() {
  for e in 00-intake 04-plan 06-zadania; do etap "$e" done; done
  cat >"$D/issues.json" <<'EOF'
[
 {"number":1,"title":"Szkielet","state":"CLOSED","stateReason":"COMPLETED","labels":[{"name":"iter:1"}],"milestone":{"title":"M1 Szkielet"},"body":"### Zależności\n\nbrak\n"},
 {"number":2,"title":"Koszyk","state":"OPEN","labels":[{"name":"status:in-progress"},{"name":"iter:2"}],"milestone":{"title":"M2 Koszyk"},"body":"### Zależności\n\n#1\n\n### Typ\n\nfeature\n"},
 {"number":3,"title":"Katalog","state":"OPEN","labels":[{"name":"status:todo"}],"milestone":{"title":"M2 Koszyk"},"body":"### Zależności\n\n#1\n"},
 {"number":4,"title":"Płatność","state":"OPEN","labels":[{"name":"status:todo"}],"milestone":{"title":"M3 Płatność"},"body":"### Zależności\n\n#2, #3\n"},
 {"number":5,"title":"Stare","state":"CLOSED","stateReason":"NOT_PLANNED","labels":[],"milestone":null,"body":""},
 {"number":6,"title":"Eksport CSV","state":"OPEN","labels":[{"name":"status:review"},{"name":"tryb:S"},{"name":"iter:1"}],"milestone":null,"body":""}
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
  mkdir -p "$SH_DIR/stan"
  printf '{"zadania":{"2":{"start":"2026-11-09T10:30:00Z"}}}' >"$SH_DIR/stan/demo.json"
}

@test "bez limity.md: pusta lista, Projekt.md z blokiem i sekcjami" {
  run sync
  echo "$output"
  [ "$status" -eq 0 ]
  [ "$(fm wstrzymania)" = "[]" ]
  [ "$(fm etap)" = 00-intake ]
  grep -qxF '<!-- projekt:start -->' "$(P)"
  grep -qxF '## Gdzie jesteśmy' "$(P)"
  grep -qxF '## Czeka na Ciebie' "$(P)"
  grep -qxF '## Punkt przekazania' "$(P)"
  ! grep -q 'dataview' "$(P)" || false
}

@test "powtorka bez zmian stanu niczego nie zmienia" {
  sync >/dev/null
  cp "$(P)" "$BATS_TEST_TMPDIR/przed"
  run sync
  [[ "$output" == *"bez zmian"* ]] || false
  cmp "$(P)" "$BATS_TEST_TMPDIR/przed"
}

@test "tabela i lista z limity.md trafiaja do frontmattera" {
  cat >"$SH_DIR/limity.md" <<'EOF'
# Limity

| Wykonawca | Od | Do | Źródło |
|---|---|---|---|
| claude | 2026-11-02 14:05 | 2026-11-02 19:00 | panel worker:sklep:12 |
- codex "do 20:30"
EOF
  run sync
  [ "$status" -eq 0 ]
  [ "$(fm wstrzymania)" = '["claude · 2026-11-02 14:05 · 2026-11-02 19:00 · panel worker:sklep:12","codex \"do 20:30\""]' ]
  [ "$(fm ostatnia_synchronizacja)" != brak ]
  grep -q '^- \*\*Wstrzymania:\*\* claude' "$(P)"
}

@test "wpis brak nie jest wstrzymaniem" {
  printf '# Limity\n\n- (brak)\n' >"$SH_DIR/limity.md"
  run sync
  [ "$status" -eq 0 ]
  [ "$(fm wstrzymania)" = "[]" ]
}

@test "realizacja: zadania wedlug stanu, postep, co sie dzieje, czas w toku" {
  realizacja
  run sync --dane "$D"
  echo "$output"
  [ "$status" -eq 0 ]
  cat "$(P)"
  [ "$(fm etap)" = realizacja ]
  [ "$(fm postep)" = '"1/5"' ]
  grep -qF -- '- **Etap:** Realizacja, kamień M2 Koszyk' "$(P)"
  grep -qF '#2 Koszyk (worker, iteracja 2, od 1 h 30 min)' "$(P)"
  grep -qF '| #2 Koszyk | M2 Koszyk | worker | 2 | #11 | fail | 1 h 30 min |' "$(P)"
  grep -qF '### Gotowe do startu (1)' "$(P)"
  grep -qF '| #3 Katalog | M2 Koszyk | #1 ✓ |' "$(P)"
  grep -qF '| #4 Płatność | M3 Płatność | #2, #3 |' "$(P)"
  grep -qF '### Zrobione (1)' "$(P)"
  grep -qF -- '- #5 Stare' "$(P)"
  grep -qF '| #2 | Koszyk | in-progress | 2 | M2 Koszyk | #11 open | fail |' "$ROOT/docs/06-zadania/index.md"
  [ "$(fm ci_fail)" = 1 ]
}

@test "czeka na ciebie: eskalacja, pytanie, lista startowa, odbior S z tekstem do wpisania" {
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
  [ "$(fm eskalacje)" = 1 ]
  [ "$(fm pytania)" = 1 ]
  grep -qF '1. E-001 (#2): brak klucza Stripe (czeka 5 h)' "$(P)"
  grep -qF 'Wpisz orkiestratorowi: `E-001: A`' "$(P)"
  grep -qF 'E-002 (#3, pytanie): W-02: komunikat pustego katalogu (czeka 1 h)' "$(P)"
  grep -qF 'Lista startowa: Stripe: klucze testowe (W-03), JAK: Dashboard' "$(P)"
  grep -qF 'Wpisz orkiestratorowi: `gotowe: Stripe`' "$(P)"
  grep -qF 'Odbiór zlecenia S #6 Eksport CSV (PR #12, review PASS) (czeka 6 h)' "$(P)"
  grep -qF 'Wpisz orkiestratorowi: `odbieram #6`' "$(P)"
  grep -qF -- '- **Następny krok:** Twoja odpowiedź: E-001 (#2): brak klucza Stripe' "$(P)"
  grep -qF '| E-002 | pytanie | #3 | W-02: komunikat pustego katalogu |' "$(P)"
  [ "$(fm czeka | jq -r '.[0].od')" = 2026-11-09T07:00:00Z ]
}

@test "odbior_S auto_bez_zmian_widocznych: zlecenie bez zmian widocznych nie czeka na wlasciciela" {
  realizacja
  sed 's/^tryb_procesu: .*/&\nodbior_S: auto_bez_zmian_widocznych/' "$ROOT/docs/konfiguracja.md" >"$ROOT/x" && mv "$ROOT/x" "$ROOT/docs/konfiguracja.md"
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

@test "dokumenty: specyfikacja, karty funkcji, plan, decyzje, raporty QA" {
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
}

@test "szacowany czas z metryk" {
  realizacja
  printf '# Metryki\n\n| Zlecenie | Tryb | Czas | Zadania | Iteracje | Eskalacje | Uwagi |\n|---|---|---|---|---|---|---|\n| #1 Szkielet | M | 1h 0min | 1 | 1 | 0 | PR #10 |\n| #9 X | M | 30min | 1 | 1 | 0 | PR #9 |\n' >"$ROOT/docs/metryki.md"
  run sync --dane "$D"
  [ "$status" -eq 0 ]
  grep -qF -- '- **Szacowany czas:** ok. 1 h 30 min pracy agentów (4 zadań, średnio 45 min na zadanie, 2 równolegle; orientacyjnie)' "$(P)"
}

@test "migracja: status.md znika, Projekt.md przejmuje punkt przekazania i dziennik" {
  rm "$(P)"
  printf -- '---\nzadania_todo: 0\n---\n\n# Status projektu\n\n## Bieżący etap\n\n(brak)\n\n## Punkt przekazania\n\nKamień M1 zakończony.\n\n## Dziennik etapów\n\n- 2026-11-05 `00-intake`: done\n' >"$ROOT/docs/status.md"
  run sync
  echo "$output"
  [ "$status" -eq 0 ]
  [ ! -e "$ROOT/docs/status.md" ]
  grep -qxF 'Kamień M1 zakończony.' "$(P)"
  grep -qxF -- '- 2026-11-05 `00-intake`: done' "$(P)"
  ! grep -q 'Bieżący etap' "$(P)" || false
}

@test "punkt przekazania wpisany przez orkiestratora zostaje po synchronizacji" {
  sync >/dev/null
  awk '{ print } /^## Punkt przekazania$/ { print ""; print "Ręczny wpis orkiestratora." }' "$(P)" >"$ROOT/x" && mv "$ROOT/x" "$(P)"
  realizacja
  run sync --dane "$D"
  [ "$status" -eq 0 ]
  grep -qxF 'Ręczny wpis orkiestratora.' "$(P)"
}

@test "--wyjscie zapisuje podglad bez zmian w docs" {
  cp "$(P)" "$BATS_TEST_TMPDIR/przed"
  realizacja
  run sync --dane "$D" --wyjscie "$BATS_TEST_TMPDIR/podglad"
  [ "$status" -eq 0 ]
  cmp "$(P)" "$BATS_TEST_TMPDIR/przed"
  grep -qF '#2 Koszyk' "$BATS_TEST_TMPDIR/podglad/Projekt.md"
}
