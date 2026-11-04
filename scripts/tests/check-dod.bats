#!/usr/bin/env bats
# Testy scripts/check-dod.sh na kopii docs/ z szablonu.
# Uruchomienie: bats scripts/tests/check-dod.bats

SKRYPT="$BATS_TEST_DIRNAME/../check-dod.sh"

setup() {
  ROOT="$BATS_TEST_TMPDIR/repo"
  mkdir -p "$ROOT"
  # Dane testowe, nigdy docs/ repo: te pliki zmienia orkiestrator (scripts/tests/dane/README.md).
  cp -R "$BATS_TEST_DIRNAME/dane/docs" "$ROOT/docs"
}

# Podmiana bez sed -i, które działa inaczej na macOS i Linuksie.
zamien() {
  sed "$2" "$1" >"$1.nowy"
  mv "$1.nowy" "$1"
}

ustaw() {
  zamien "$ROOT/docs/konfiguracja.md" "s/^$1: .*/$1: $2/"
}

status_etapu() {
  zamien "$ROOT/docs/$1/DoD.md" "s/^status: .*/status: $2/"
}

# Pierwsze pole pasujące do wzorca: nowy początek i dopisek na końcu (bez sed 0,/re/ z GNU).
pierwsze_pole() {
  W="$2" P="$3" K="$4" awk '!z && $0 ~ ENVIRON["W"] { sub(ENVIRON["W"], ENVIRON["P"]); $0 = $0 ENVIRON["K"]; z = 1 } { print }' \
    "$ROOT/docs/$1/DoD.md" >"$ROOT/docs/$1/DoD.md.nowy"
  mv "$ROOT/docs/$1/DoD.md.nowy" "$ROOT/docs/$1/DoD.md"
}

zaznacz_wszystko() {
  zamien "$ROOT/docs/$1/DoD.md" 's/^- \[ \]/- [x]/'
}

@test "szablon przechodzi" {
  run bash "$SKRYPT" "$ROOT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"check-dod: OK (tryb M)"* ]] || false
}

@test "brak konfiguracji" {
  rm "$ROOT/docs/konfiguracja.md"
  run bash "$SKRYPT" "$ROOT"
  [ "$status" -eq 1 ]
  [[ "$output" == *"brak"*"konfiguracja.md"* ]] || false
}

@test "niedozwolony tryb procesu" {
  ustaw tryb_procesu X
  run bash "$SKRYPT" "$ROOT"
  [ "$status" -eq 1 ]
  [[ "$output" == *"tryb_procesu='X'"* ]] || false
}

@test "tryb L niedostepny w etapie A" {
  ustaw tryb_procesu L
  run bash "$SKRYPT" "$ROOT"
  [ "$status" -eq 1 ]
  [[ "$output" == *"dopiero w etapie wdrożenia B"* ]] || false
}

@test "brak DoD etapu" {
  rm "$ROOT/docs/08-qa/DoD.md"
  run bash "$SKRYPT" "$ROOT"
  [ "$status" -eq 1 ]
  [[ "$output" == *"docs/08-qa/DoD.md: brak pliku"* ]] || false
}

@test "bledna iteracja" {
  zamien "$ROOT/docs/08-qa/DoD.md" 's/^iteracja: .*/iteracja: 4/'
  run bash "$SKRYPT" "$ROOT"
  [ "$status" -eq 1 ]
  [[ "$output" == *"iteracja='4'"* ]] || false
}

@test "brak sekcji" {
  zamien "$ROOT/docs/08-qa/DoD.md" 's/^## Checkpoint$/## Inna/'
  run bash "$SKRYPT" "$ROOT"
  [ "$status" -eq 1 ]
  [[ "$output" == *"brak sekcji 'Checkpoint'"* ]] || false
}

@test "status done z pustymi polami" {
  status_etapu 08-qa done
  run bash "$SKRYPT" "$ROOT"
  [ "$status" -eq 1 ]
  [[ "$output" == *"status done, ale"* ]] || false
}

@test "status done z zaznaczonymi polami" {
  status_etapu 08-qa done
  zaznacz_wszystko 08-qa
  run bash "$SKRYPT" "$ROOT"
  [ "$status" -eq 0 ]
}

@test "blok tylko-tryb:L pomijany w trybie M" {
  status_etapu wydanie done
  zaznacz_wszystko wydanie
  zamien "$ROOT/docs/wydanie/DoD.md" 's/^- \[x\] `architektoniczna/- [ ] `architektoniczna/'
  run bash "$SKRYPT" "$ROOT"
  [ "$status" -eq 0 ]
}

@test "blok tylko-tryb:L liczony w trybie L" {
  ustaw etap_wdrozenia B
  ustaw tryb_procesu L
  status_etapu wydanie done
  zaznacz_wszystko wydanie
  zamien "$ROOT/docs/wydanie/DoD.md" 's/^- \[x\] `architektoniczna/- [ ] `architektoniczna/'
  run bash "$SKRYPT" "$ROOT"
  [ "$status" -eq 1 ]
  [[ "$output" == *"docs/wydanie/DoD.md: status done, ale 1 pól"* ]] || false
}

@test "pominiety etap z trybu M bez uzasadnienia odrzucony" {
  status_etapu 08-qa pominiety
  run bash "$SKRYPT" "$ROOT"
  [ "$status" -eq 1 ]
  [[ "$output" == *"wymaga uzasadnienie_pominiecia"* ]] || false
}

@test "pominiety etap z trybu M z uzasadnieniem dozwolony" {
  status_etapu 08-qa pominiety
  zamien "$ROOT/docs/08-qa/DoD.md" 's/^status: pominiety$/status: pominiety\
uzasadnienie_pominiecia: biblioteka bez UI, QA w testach jednostkowych/'
  run bash "$SKRYPT" "$ROOT"
  echo "$output"
  [ "$status" -eq 0 ]
}

@test "pole nie dotyczy z powodem zamyka etap" {
  status_etapu 08-qa done
  zaznacz_wszystko 08-qa
  pierwsze_pole 08-qa '^- \[x\] ' '- [-] ' ' (nie dotyczy: biblioteka bez UI)'
  grep -q '^- \[-\] .*(nie dotyczy: biblioteka bez UI)$' "$ROOT/docs/08-qa/DoD.md"
  run bash "$SKRYPT" "$ROOT"
  echo "$output"
  [ "$status" -eq 0 ]
}

@test "pole [-] bez powodu to blad" {
  pierwsze_pole 08-qa '^- \[ \] ' '- [-] ' ''
  run bash "$SKRYPT" "$ROOT"
  [ "$status" -eq 1 ]
  [[ "$output" == *"docs/08-qa/DoD.md: 1 pól [-] bez"* ]] || false
}

@test ".husky w repo" {
  mkdir "$ROOT/.husky"
  run bash "$SKRYPT" "$ROOT"
  [ "$status" -eq 1 ]
  [[ "$output" == *".husky: projekty nie mają hooków git"* ]] || false
}

@test ".githooks w repo" {
  mkdir "$ROOT/.githooks"
  run bash "$SKRYPT" "$ROOT"
  [ "$status" -eq 1 ]
  [[ "$output" == *".githooks: projekty nie mają hooków git"* ]] || false
}

@test ".githooks w podkatalogu" {
  mkdir -p "$ROOT/apps/web/.githooks"
  run bash "$SKRYPT" "$ROOT"
  [ "$status" -eq 1 ]
  [[ "$output" == *"apps/web/.githooks"* ]] || false
}

@test ".husky w podkatalogu" {
  mkdir -p "$ROOT/apps/web/.husky"
  run bash "$SKRYPT" "$ROOT"
  [ "$status" -eq 1 ]
  [[ "$output" == *"apps/web/.husky"* ]] || false
}

@test "prepare z husky w package.json" {
  echo '{"scripts":{"prepare":"husky"}}' >"$ROOT/package.json"
  run bash "$SKRYPT" "$ROOT"
  [ "$status" -eq 1 ]
  [[ "$output" == *"package.json: skrypt prepare z husky"* ]] || false
}

@test "prepare z husky wsrod innych polecen, z odstepami" {
  printf '{\n  "scripts": {\n    "prepare" :  "pnpm build && husky install"\n  }\n}\n' >"$ROOT/package.json"
  run bash "$SKRYPT" "$ROOT"
  [ "$status" -eq 1 ]
}

@test "prepare bez husky i inne skrypty przechodza" {
  echo '{"scripts":{"prepare":"tsc","lint":"husky-nie-tutaj"}}' >"$ROOT/package.json"
  run bash "$SKRYPT" "$ROOT"
  [ "$status" -eq 0 ]
}

@test "node_modules pomijane" {
  mkdir -p "$ROOT/node_modules/x/.husky" "$ROOT/node_modules/x/.githooks"
  echo '{"scripts":{"prepare":"husky"}}' >"$ROOT/node_modules/x/package.json"
  run bash "$SKRYPT" "$ROOT"
  [ "$status" -eq 0 ]
}

@test "pominiety etap spoza trybu M dozwolony" {
  status_etapu 01-brief pominiety
  run bash "$SKRYPT" "$ROOT"
  [ "$status" -eq 0 ]
}

@test "blok dataviewjs w docs to blad" {
  printf '# X\n\n```dataviewjs\ndv.paragraph(1)\n```\n' >"$ROOT/docs/widok.md"
  run bash "$SKRYPT" "$ROOT"
  [ "$status" -eq 1 ]
  [[ "$output" == *"docs/widok.md:3: wykonywalny kod w notatce"* ]] || false
}

@test "dataviewjs w podkatalogu, z wcieciem i tyldami to blad" {
  mkdir -p "$ROOT/docs/07-realizacja/x"
  printf -- '- lista\n  ~~~ dataviewjs\n  1\n  ~~~\n' >"$ROOT/docs/07-realizacja/x/a.md"
  run bash "$SKRYPT" "$ROOT"
  [ "$status" -eq 1 ]
  [[ "$output" == *"docs/07-realizacja/x/a.md:2:"* ]] || false
}

@test "inline dataview JS to blad" {
  printf 'Liczba: `$= dv.pages().length`\n' >"$ROOT/docs/widok.md"
  run bash "$SKRYPT" "$ROOT"
  [ "$status" -eq 1 ]
  [[ "$output" == *"wykonywalny kod w notatce"* ]] || false
}

@test "blok dataview DQL i slowo dataviewjs w tekscie przechodza" {
  printf 'Bez dataviewjs.\n\n```dataview\nLIST\n```\n' >"$ROOT/docs/widok.md"
  run bash "$SKRYPT" "$ROOT"
  [ "$status" -eq 0 ]
}
