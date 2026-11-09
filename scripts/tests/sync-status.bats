#!/usr/bin/env bats
# Testy wstrzymań w scripts/sync-status.sh na kopii repo, gh zastąpiony atrapą bez zadań.
# Uruchomienie: bats scripts/tests/sync-status.bats

setup() {
  ROOT="$BATS_TEST_TMPDIR/repo"
  mkdir -p "$ROOT/scripts" "$BATS_TEST_TMPDIR/bin" "$BATS_TEST_TMPDIR/sh"
  # Dane testowe, nigdy docs/ repo: te pliki zmienia orkiestrator (scripts/tests/dane/README.md).
  cp -R "$BATS_TEST_DIRNAME/dane/docs" "$ROOT/docs"
  cp "$BATS_TEST_DIRNAME/../sync-status.sh" "$ROOT/scripts/"
  printf '#!/bin/sh\necho "[]"\n' >"$BATS_TEST_TMPDIR/bin/gh"
  chmod +x "$BATS_TEST_TMPDIR/bin/gh"
  export PATH="$BATS_TEST_TMPDIR/bin:$PATH" SH_DIR="$BATS_TEST_TMPDIR/sh"
}

fm() { awk -v k="$1" 'index($0, k ": ") == 1 { print substr($0, length(k) + 3) }' "$ROOT/docs/status.md"; }

@test "bez limity.md: pusta lista i bez zmian" {
  run bash "$ROOT/scripts/sync-status.sh"
  [ "$status" -eq 0 ]
  [[ "$output" == *"bez zmian"* ]] || false
  [ "$(fm wstrzymania)" = "[]" ]
}

@test "tabela i lista z limity.md trafiaja do frontmattera" {
  cat >"$SH_DIR/limity.md" <<'EOF'
# Limity

| Wykonawca | Od | Do | Źródło |
|---|---|---|---|
| claude | 2026-11-02 14:05 | 2026-11-02 19:00 | panel worker:sklep:12 |
- codex "do 20:30"
EOF
  run bash "$ROOT/scripts/sync-status.sh"
  [ "$status" -eq 0 ]
  [ "$(fm wstrzymania)" = '["claude · 2026-11-02 14:05 · 2026-11-02 19:00 · panel worker:sklep:12","codex \"do 20:30\""]' ]
  [ "$(fm ostatnia_synchronizacja)" != brak ]
}

@test "wpis brak nie jest wstrzymaniem" {
  printf '# Limity\n\n- (brak)\n' >"$SH_DIR/limity.md"
  run bash "$ROOT/scripts/sync-status.sh"
  [ "$status" -eq 0 ]
  [ "$(fm wstrzymania)" = "[]" ]
}

