#!/usr/bin/env bats
# Testy skryptów pracują na danych z scripts/tests/dane, nigdy na prawdziwym docs/ repo
# (scripts/tests/dane/README.md). Uruchomienie: bats scripts/tests/dane-testowe.bats

@test "zaden test nie siega do docs/ repo" {
  local f
  for f in "$BATS_TEST_DIRNAME"/*.bats; do
    [ "$f" != "$BATS_TEST_FILENAME" ] || continue
    run grep -nE '\.\./\.\./docs|show-toplevel\)/docs' "$f"
    [ "$status" -eq 1 ] || { echo "$f: $output"; false; }
  done
}

@test "dane testowe maja pliki uzywane przez testy" {
  for f in konfiguracja.md status.md decyzje.md _dashboard.md 00-intake/DoD.md 08-qa/DoD.md wydanie/DoD.md 06-zadania/index.md; do
    [ -f "$BATS_TEST_DIRNAME/dane/docs/$f" ] || { echo "brak dane/docs/$f"; false; }
  done
}
