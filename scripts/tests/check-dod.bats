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

@test "pola - [ ] w komentarzach HTML nie blokuja done (dryrun 5)" {
  status_etapu 08-qa done
  zaznacz_wszystko 08-qa
  printf '\n<!-- Przykład:\n- [ ] pole w przykładzie\n- [-] bez powodu\n-->\n<!-- - [ ] w jednej linii -->\n' >>"$ROOT/docs/08-qa/DoD.md"
  run bash "$SKRYPT" "$ROOT"
  echo "$output"
  [ "$status" -eq 0 ]
  printf '<!-- x --> - [ ] po komentarzu\n' >>"$ROOT/docs/08-qa/DoD.md"
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

@test "pominiety etap bez decyzji odrzucony" {
  status_etapu 08-qa pominiety
  run bash "$SKRYPT" "$ROOT"
  [ "$status" -eq 1 ]
  [[ "$output" == *"status pominiety wymaga pola decyzja"* ]] || false
}

@test "pominiety etap z decyzja dozwolony" {
  status_etapu 08-qa pominiety
  zamien "$ROOT/docs/08-qa/DoD.md" 's/^status: pominiety$/status: pominiety\
decyzja: biblioteka bez UI, QA w testach jednostkowych/'
  run bash "$SKRYPT" "$ROOT"
  echo "$output"
  [ "$status" -eq 0 ]
}

@test "tryb S: pominiety bez decyzji dozwolony" {
  ustaw tryb_procesu S
  status_etapu 08-qa pominiety
  run bash "$SKRYPT" "$ROOT"
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

@test "etapy trybu L i DoD realizacji nie sa wymagane" {
  for e in 01-brief 02-design 03-wymagania 07-realizacja; do [ ! -e "$ROOT/docs/$e/DoD.md" ]; done
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

@test "wersja procesu 2: etap 04-plan, bez 04-architektura i 05-plan" {
  [ -f "$ROOT/docs/04-plan/DoD.md" ]
  [ ! -e "$ROOT/docs/04-architektura" ] && [ ! -e "$ROOT/docs/05-plan" ]
  run bash "$SKRYPT" "$ROOT"
  [ "$status" -eq 0 ]
  rm "$ROOT/docs/04-plan/DoD.md"
  run bash "$SKRYPT" "$ROOT"
  [ "$status" -eq 1 ]
  [[ "$output" == *"docs/04-plan/DoD.md: brak pliku"* ]] || false
}

@test "wersja procesu 1 (brak pola): etapy 04-architektura i 05-plan" {
  grep -v '^wersja_procesu:' "$ROOT/docs/konfiguracja.md" >"$ROOT/k" && mv "$ROOT/k" "$ROOT/docs/konfiguracja.md"
  run bash "$SKRYPT" "$ROOT"
  [ "$status" -eq 1 ]
  [[ "$output" == *"docs/04-architektura/DoD.md: brak pliku"* ]] || false
  [[ "$output" == *"docs/05-plan/DoD.md: brak pliku"* ]] || false
  for e in 04-architektura 05-plan; do
    mkdir -p "$ROOT/docs/$e"
    sed "s/^etap: .*/etap: $e/" "$ROOT/docs/04-plan/DoD.md" >"$ROOT/docs/$e/DoD.md"
  done
  rm -r "$ROOT/docs/04-plan"
  run bash "$SKRYPT" "$ROOT"
  [ "$status" -eq 0 ]
}

@test "nieznana wersja procesu to blad" {
  ustaw wersja_procesu 3
  run bash "$SKRYPT" "$ROOT"
  [ "$status" -eq 1 ]
  [[ "$output" == *"wersja_procesu='3'"* ]] || false
}

# Specyfikacja z W-01 (karta) i W-02 (bez karty) oraz poprawna karta pełna W-01.
karty() {
  mkdir -p "$ROOT/docs/00-intake/funkcje"
  printf '# Specyfikacja\n\n### W-01: Formularz (musi)\n\nx\n\n### W-02: Wydajność (musi) (bez karty: niefunkcjonalne)\n\ny\n' \
    >"$ROOT/docs/00-intake/specyfikacja.md"
  K="$ROOT/docs/00-intake/funkcje/W-01.md"
  {
    printf -- '---\nwymaganie: W-01\nrodzaj: pelna\n---\n\n# Karta funkcji W-01: Formularz\n\n'
    printf '<!-- komentarz z [?], TODO i `kodem` nie jest luką -->\n\n## Dla właściciela\n\n'
    for s in "Opis" "Przebieg" "Stany ekranu" "Reguły biznesowe" "Poza zakresem" "Do potwierdzenia"; do
      printf '### %s\n\nCzy to pytanie? Wiadomość do 5000 znaków.\n\n' "$s"
    done
    printf '## Dla wykonawcy\n\n'
    for s in "Wejście" "Pola i walidacja" "Odpowiedzi i błędy" "Dostępność" "Przypadki brzegowe" \
      "Kryteria akceptacji" "Design i ADR"; do
      printf '### %s\n\nKod 429, `aria-live`.\n\n' "$s"
    done
    printf '```\nTODO w bloku kodu nie jest luką\n```\n'
  } >"$K"
  zamien "$K" 's/^### Kryteria akceptacji$/### Kryteria akceptacji\
\
- W-01\/K1: Given formularz, when wysyłam, then widzę sukces./'
}

@test "karty: poprawna karta i wymaganie bez karty przechodza" {
  karty
  run bash "$SKRYPT" "$ROOT"
  echo "$output"
  [ "$status" -eq 0 ]
}

@test "karty: brak karty funkcji uzytkowej to blad" {
  karty
  rm "$K"
  run bash "$SKRYPT" "$ROOT"
  [ "$status" -eq 1 ]
  [[ "$output" == *"funkcje/W-01.md: brak karty funkcji dla W-01"* ]] || false
}

@test "karty: numeracja jednocyfrowa to blad" {
  karty
  zamien "$ROOT/docs/00-intake/specyfikacja.md" 's/### W-01:/### W-1:/'
  run bash "$SKRYPT" "$ROOT"
  [ "$status" -eq 1 ]
  [[ "$output" == *"W-1: numeracja wymagań ma dwie cyfry"* ]] || false
}

@test "karty: luki [?], samotny ? i TODO sa bledami" {
  karty
  printf '| Pusty | ? | x |\n- limit [?]\n- TODO: komunikat\n' >>"$K"
  run bash "$SKRYPT" "$ROOT"
  [ "$status" -eq 1 ]
  [ "$(grep -c 'otwarta luka' <<<"$output")" -eq 3 ]
}

@test "karty: czesc dla wlasciciela bez kodu, kodow HTTP i atrybutow" {
  karty
  zamien "$K" 's/^Czy to pytanie? Wiadomość do 5000 znaków.$/Serwer zwraca 429 i ustawia `aria-live`./'
  run bash "$SKRYPT" "$ROOT"
  [ "$status" -eq 1 ]
  [ "$(grep -c 'część dla właściciela bez kodu' <<<"$output")" -eq 6 ]
}

@test "karty: brak czesci i sekcji, brak Given/When/Then i zly rodzaj" {
  karty
  zamien "$K" '/^### Reguły biznesowe$/d'
  run bash "$SKRYPT" "$ROOT"
  [ "$status" -eq 1 ]
  [[ "$output" == *"brak sekcji 'Reguły biznesowe' w części 'Dla właściciela'"* ]] || false
  zamien "$K" '/^### Poza zakresem$/d'
  run bash "$SKRYPT" "$ROOT"
  [[ "$output" == *"brak sekcji 'Poza zakresem' w części 'Dla właściciela'"* ]] || false
  zamien "$K" 's/^## Dla wykonawcy$/### Poza zakresem\
\
Bez załączników.\
\
## Dla wykonawcy/'
  run bash "$SKRYPT" "$ROOT"
  [[ "$output" != *"'Poza zakresem'"* ]] || false
  zamien "$K" 's/^rodzaj: pelna/rodzaj: skrocona/'
  run bash "$SKRYPT" "$ROOT"
  echo "$output"
  [ "$status" -eq 0 ]
  zamien "$K" 's/Given formularz/Formularz/'
  run bash "$SKRYPT" "$ROOT"
  [ "$status" -eq 1 ]
  [[ "$output" == *"bez kryterium Given/When/Then"* ]] || false
  zamien "$K" '/^## Dla wykonawcy$/d'
  run bash "$SKRYPT" "$ROOT"
  [[ "$output" == *"brak części 'Dla wykonawcy'"* ]] || false
  zamien "$K" 's/^rodzaj: skrocona/rodzaj: inna/'
  run bash "$SKRYPT" "$ROOT"
  [[ "$output" == *"rodzaj='inna'"* ]] || false
}

@test "karty: tryb S i projekt bez katalogu funkcje nie sa sprawdzane" {
  karty
  rm "$K"
  ustaw tryb_procesu S
  for e in 00-intake 04-plan 06-zadania 08-qa wydanie; do status_etapu "$e" pominiety; done
  run bash "$SKRYPT" "$ROOT"
  [[ "$output" != *"karty funkcji"* ]] || false
  ustaw tryb_procesu M
  rm -r "$ROOT/docs/00-intake/funkcje"
  run bash "$SKRYPT" "$ROOT"
  [[ "$output" != *"karty funkcji"* ]] || false
}
