#!/usr/bin/env bash
# Sprawdza DoD.md wszystkich etapów (docs/proces-v1.md, „Definition of Done”).
# Użycie: scripts/check-dod.sh [KATALOG_REPO]
# Blok <!-- tylko-tryb:L --> ... <!-- /tylko-tryb --> liczy się wyłącznie w trybie L.
# Sprawdza też zakaz hooków git w projekcie (AGENTS.md, „Hooki git”): .githooks/ i husky,
# oraz zakaz wykonywalnego kodu w notatkach docs/ (AGENTS.md, „Zasady pracy”): bloki dataviewjs
# i inline `$=`.
# Działa na bash 3.2 (macOS) i bez narzędzi spoza systemu.
set -euo pipefail

ROOT="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
DOCS="$ROOT/docs"
KONFIG="$DOCS/konfiguracja.md"

# Etapy z DoD.md (tryb M) według wersja_procesu z konfiguracja.md: 2 ma jeden etap 04-plan, a brak pola
# (wersja 1, projekty sprzed migracji) osobne 04-architektura i 05-plan. Tryb L jest odłożony; stan
# realizacji jest w issue.
ETAPY_V1="00-intake 04-architektura 05-plan 06-zadania 08-qa wydanie"
ETAPY_V2="00-intake 04-plan 06-zadania 08-qa wydanie"
SEKCJE=("Dokumentacja" "Funkcjonalność" "Checklisty jakości" "Checkpoint")

bledy=0
blad() {
  echo "BŁĄD: $*" >&2
  bledy=$((bledy + 1))
}

# Wartość klucza z frontmattera: pierwszy blok między liniami ---.
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
    }' "$1"
}

ma_frontmatter() {
  [ "$(head -n 1 "$1")" = "---" ] && [ "$(awk 'NR > 1 && $0 == "---" { n++ } END { print n + 0 }' "$1")" -ge 1 ]
}

# Wypisuje: "niezaznaczone zaznaczone nie-dotyczy błędne-nie-dotyczy".
# Pole „nie dotyczy”: `- [-] treść (nie dotyczy: powód)`, np. E2E w bibliotece bez UI. Powód jest
# obowiązkowy; pole bez niego liczy się jako błąd.
policz_checkboxy() {
  awk -v tryb="$2" '
    /^[ \t]*(```|~~~)/ { kod = !kod; next }
    kod { next }
    /<!-- tylko-tryb:L -->/ { tylko_l = 1; next }
    /<!-- \/tylko-tryb -->/ { tylko_l = 0; next }
    tylko_l && tryb != "L" { next }
    /^[ \t]*[-*+] \[ \]/ { puste++ }
    /^[ \t]*[-*+] \[[xX]\]/ { pelne++ }
    /^[ \t]*[-*+] \[-\]/ {
      if ($0 ~ /nie dotyczy: *[^ )]/) nd++
      else zle++
    }
    END { print puste + 0, pelne + 0, nd + 0, zle + 0 }' "$1"
}

if [ ! -f "$KONFIG" ]; then
  echo "BŁĄD: brak $KONFIG" >&2
  exit 1
fi

TRYB="$(fm_get "$KONFIG" tryb_procesu)"
WERSJA="$(fm_get "$KONFIG" wersja_procesu)"
case "${WERSJA:-1}" in
  1) ETAPY="$ETAPY_V1" ;;
  2) ETAPY="$ETAPY_V2" ;;
  *)
    echo "BŁĄD: konfiguracja.md: wersja_procesu='$WERSJA', dozwolone 1 albo 2" >&2
    exit 1
    ;;
esac
ETAP_WDROZENIA="$(fm_get "$KONFIG" etap_wdrozenia)"

case "$ETAP_WDROZENIA" in
  A | B) ;;
  *) blad "konfiguracja.md: etap_wdrozenia='$ETAP_WDROZENIA', dozwolone A albo B" ;;
esac
case "$TRYB" in
  S | M | L) ;;
  *)
    echo "BŁĄD: konfiguracja.md: tryb_procesu='$TRYB', dozwolone S, M albo L" >&2
    exit 1
    ;;
esac
if [ "$TRYB" = "L" ] && [ "$ETAP_WDROZENIA" = "A" ]; then
  blad "konfiguracja.md: tryb L jest dostępny dopiero w etapie wdrożenia B"
fi

for etap in $ETAPY; do
  plik="$DOCS/$etap/DoD.md"
  wzgl="docs/$etap/DoD.md"

  if [ ! -f "$plik" ]; then
    blad "$wzgl: brak pliku"
    continue
  fi
  if ! ma_frontmatter "$plik"; then
    blad "$wzgl: brak frontmattera"
    continue
  fi

  fm_etap="$(fm_get "$plik" etap)"
  status="$(fm_get "$plik" status)"
  iteracja="$(fm_get "$plik" iteracja)"

  [ "$fm_etap" = "$etap" ] || blad "$wzgl: etap='$fm_etap', oczekiwano '$etap'"
  case "$iteracja" in
    0 | 1 | 2 | 3) ;;
    *) blad "$wzgl: iteracja='$iteracja', dozwolone 0-3" ;;
  esac

  for sekcja in "${SEKCJE[@]}"; do
    grep -qxF "## $sekcja" "$plik" || blad "$wzgl: brak sekcji '$sekcja'"
  done

  read -r puste pelne nd zle <<EOF
$(policz_checkboxy "$plik" "$TRYB")
EOF
  [ "$zle" -eq 0 ] || blad "$wzgl: $zle pól [-] bez „(nie dotyczy: powód)”"

  case "$status" in
    todo | in-progress | review | escalated) ;;
    done)
      [ "$puste" -eq 0 ] || blad "$wzgl: status done, ale $puste pól nie jest zaznaczonych"
      [ "$pelne" -gt 0 ] || blad "$wzgl: status done bez żadnego zaznaczonego pola"
      ;;
    pominiety)
      # Pominięcie etapu to decyzja orkiestratora (shctl decision add) zapisana w polu decyzja.
      # Tryb S nie ma etapów: new-project oznacza wszystkie jako pominiety.
      if [ "$TRYB" != S ] && [ -z "$(fm_get "$plik" decyzja)" ]; then
        blad "$wzgl: status pominiety wymaga pola decyzja (shctl decision add, potem decyzja: \"...\" w DoD.md)"
      fi
      ;;
    *) blad "$wzgl: status='$status', dozwolone todo|in-progress|review|done|escalated|pominiety" ;;
  esac
done

# Karty funkcji (sh-intake, docs/_szablony/karta-funkcji.md): każde wymaganie „### W-N: …” ze
# specyfikacji ma kartę docs/00-intake/funkcje/W-N.md, chyba że nagłówek ma „(bez karty: powód)”.
# Karta ma sekcje swojego rodzaju (pelna albo skrocona), kryteria Given/When/Then i żadnej luki: „[?]”,
# samotnego „?” ani TODO poza blokami kodu i komentarzami HTML. Sprawdzane w trybie M i L, gdy projekt
# ma katalog docs/00-intake/funkcje/ (projekty sprzed SH-lite F4 go nie mają).
SEKCJE_KARTY_PELNEJ=("Wejście" "Przebieg" "Stany ekranu" "Dane wejścia i wyjścia" "Reguły biznesowe"
  "Przypadki brzegowe" "Kryteria akceptacji" "Poza zakresem" "Założenia modelu")
SEKCJE_KARTY_SKROCONEJ=("Wejście" "Przebieg" "Stany ekranu" "Kryteria akceptacji" "Poza zakresem"
  "Założenia modelu")
KARTY="$DOCS/00-intake/funkcje"
SPEC="$DOCS/00-intake/specyfikacja.md"

# Linie z luką: numer i treść, poza blokami kodu i komentarzami HTML.
luki_karty() {
  awk '
    /^[ \t]*(```|~~~)/ { kod = !kod; next }
    kod { next }
    {
      l = $0
      if (kom) { if (index(l, "-->")) { l = substr(l, index(l, "-->") + 3); kom = 0 } else next }
      while (index(l, "<!--")) {
        p = index(l, "<!--"); r = substr(l, p + 4)
        if (index(r, "-->")) l = substr(l, 1, p - 1) substr(r, index(r, "-->") + 3)
        else { l = substr(l, 1, p - 1); kom = 1 }
      }
      if (l ~ /\[\?\]/ || l ~ /(^|[ \t|(])\?([ \t|).,;:]|$)/ || l ~ /(^|[^A-Za-z])TODO([^A-Za-z]|$)/)
        print NR ": " l
    }' "$1"
}

if [ "$TRYB" != S ] && [ -d "$KARTY" ] && [ -f "$SPEC" ]; then
  while IFS= read -r w; do
    [ -f "$KARTY/$w.md" ] || blad "docs/00-intake/funkcje/$w.md: brak karty funkcji dla $w (albo „(bez karty: powód)” w nagłówku specyfikacji)"
  done < <(awk '
    /^[ \t]*(```|~~~)/ { kod = !kod; next }
    kod { next }
    /^### W-[0-9]+[:  ]/ && !/\(bez karty: *[^ )]/ { sub(/^### /, ""); sub(/[:  ].*$/, ""); print }' "$SPEC")
fi
if [ "$TRYB" != S ] && [ -d "$KARTY" ]; then
  for karta in "$KARTY"/W-*.md; do
    [ -e "$karta" ] || continue
    wzgl="docs/00-intake/funkcje/$(basename "$karta")"
    if ! ma_frontmatter "$karta"; then
      blad "$wzgl: brak frontmattera (wymaganie, rodzaj)"
      continue
    fi
    [ "$(fm_get "$karta" wymaganie)" = "$(basename "$karta" .md)" ] ||
      blad "$wzgl: wymaganie='$(fm_get "$karta" wymaganie)', oczekiwano '$(basename "$karta" .md)'"
    case "$(fm_get "$karta" rodzaj)" in
      pelna) sekcje_karty=("${SEKCJE_KARTY_PELNEJ[@]}") ;;
      skrocona) sekcje_karty=("${SEKCJE_KARTY_SKROCONEJ[@]}") ;;
      *)
        blad "$wzgl: rodzaj='$(fm_get "$karta" rodzaj)', dozwolone pelna albo skrocona"
        sekcje_karty=("${SEKCJE_KARTY_SKROCONEJ[@]}")
        ;;
    esac
    for sekcja in "${sekcje_karty[@]}"; do
      grep -qxF "## $sekcja" "$karta" || blad "$wzgl: brak sekcji '$sekcja'"
    done
    awk '$0 == "## Kryteria akceptacji" { w = 1; next } w && /^## / { exit } w' "$karta" |
      grep -qiE 'given.*when.*then' || blad "$wzgl: „Kryteria akceptacji” bez kryterium Given/When/Then"
    while IFS= read -r luka; do
      [ -n "$luka" ] && blad "$wzgl:$luka (otwarta luka: odpowiedź właściciela albo założenie)"
    done < <(luki_karty "$karta")
  done
fi

# Bez jq: pole "prepare" z husky w dowolnym package.json poza node_modules.
while IFS= read -r sciezka; do
  wzgl="${sciezka#"$ROOT"/}"
  case "$sciezka" in
    */.husky | */.githooks) blad "$wzgl: projekty nie mają hooków git, kontrole robi CI" ;;
    *)
      if grep -Eq '"prepare"[[:space:]]*:[[:space:]]*"[^"]*husky' "$sciezka"; then
        blad "$wzgl: skrypt prepare z husky jest zabroniony, projekty nie mają hooków git"
      fi
      ;;
  esac
done < <(find "$ROOT" \( -name node_modules -o -name .git \) -prune -o \
  \( -type d \( -name .husky -o -name .githooks \) -o -type f -name package.json \) -print)

# Wykonywalny kod w notatkach: Dataview DQL tak, dataviewjs i inline JS nie.
while IFS= read -r trafienie; do
  blad "${trafienie#"$ROOT"/}: wykonywalny kod w notatce (dataviewjs albo inline \`\$=\`), dozwolone tylko DQL"
done < <(find "$DOCS" -type f -name '*.md' -exec grep -HnE \
  '^[[:space:]>]*(```+|~~~+)[[:space:]]*\{?dataviewjs|`\$=' {} + 2>/dev/null | cut -d: -f1-2 || true)

if [ "$bledy" -gt 0 ]; then
  echo "check-dod: błędy: $bledy" >&2
  exit 1
fi
echo "check-dod: OK (tryb $TRYB)"
