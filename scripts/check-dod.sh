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
# obowiązkowy; pole bez niego liczy się jako błąd. Pola w blokach kodu i komentarzach HTML (przykłady
# w szablonach) się nie liczą.
policz_checkboxy() {
  awk -v tryb="$2" '
    !kom && /^[ \t]*(```|~~~)/ { kod = !kod; next }
    kod { next }
    !kom && /<!-- tylko-tryb:L -->/ { tylko_l = 1; next }
    !kom && /<!-- \/tylko-tryb -->/ { tylko_l = 0; next }
    tylko_l && tryb != "L" { next }
    {
      l = $0
      if (kom) { if (index(l, "-->")) { l = substr(l, index(l, "-->") + 3); kom = 0 } else next }
      while (index(l, "<!--")) {
        p = index(l, "<!--"); r = substr(l, p + 4)
        if (index(r, "-->")) l = substr(l, 1, p - 1) substr(r, index(r, "-->") + 3)
        else { l = substr(l, 1, p - 1); kom = 1 }
      }
    }
    l ~ /^[ \t]*[-*+] \[ \]/ { puste++ }
    l ~ /^[ \t]*[-*+] \[[xX]\]/ { pelne++ }
    l ~ /^[ \t]*[-*+] \[-\]/ {
      if (l ~ /nie dotyczy: *[^ )]/) nd++
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

# Karty funkcji (sh-intake, docs/_szablony/karta-funkcji.md): każde wymaganie „### W-NN: …” ze
# specyfikacji ma kartę docs/00-intake/funkcje/W-NN.md, chyba że nagłówek ma „(bez karty: powód)”.
# Numeracja wymagań: dwie cyfry (W-01, W-02 …). Karta ma części „Dla właściciela” i „Dla wykonawcy”
# z podsekcjami swojego rodzaju (pelna albo skrocona), kryteria Given/When/Then i żadnej luki: „[?]”,
# samotnego „?” ani TODO poza blokami kodu i komentarzami HTML. Część dla właściciela nie ma kodu w
# backtickach, kodów HTTP ani atrybutów (aria-*). Sprawdzane w trybie M i L, gdy projekt ma katalog
# docs/00-intake/funkcje/ (projekty sprzed SH-lite F4 go nie mają).
WLASCICIEL_PELNA=("Opis" "Przebieg" "Stany ekranu" "Reguły biznesowe" "Poza zakresem" "Do potwierdzenia")
WYKONAWCA_PELNA=("Wejście" "Pola i walidacja" "Odpowiedzi i błędy" "Dostępność" "Przypadki brzegowe"
  "Kryteria akceptacji" "Design i ADR")
WLASCICIEL_SKROCONA=("Opis" "Przebieg" "Stany ekranu" "Poza zakresem" "Do potwierdzenia")
WYKONAWCA_SKROCONA=("Kryteria akceptacji" "Design i ADR")
KARTY="$DOCS/00-intake/funkcje"
SPEC="$DOCS/00-intake/specyfikacja.md"

# Treść bez bloków kodu i komentarzy HTML, z numerami linii: „NR<TAB>linia”.
bez_kodu() {
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
      print NR "\t" l
    }' "$1"
}

# Część „## NAZWA” karty (do następnego nagłówka drugiego poziomu), w formacie bez_kodu.
czesc_karty() { bez_kodu "$1" | awk -F '\t' -v n="## $2" '$2 == n { w = 1; next } w && $2 ~ /^## / { exit } w'; }

if [ "$TRYB" != S ] && [ -d "$KARTY" ] && [ -f "$SPEC" ]; then
  while IFS= read -r w; do
    case "$w" in
      W-[0-9][0-9]*) [ -f "$KARTY/$w.md" ] ||
        blad "docs/00-intake/funkcje/$w.md: brak karty funkcji dla $w (albo „(bez karty: powód)” w nagłówku specyfikacji)" ;;
      *) blad "docs/00-intake/specyfikacja.md: $w: numeracja wymagań ma dwie cyfry (W-01, W-02 …)" ;;
    esac
  done < <(bez_kodu "$SPEC" | cut -f2- |
    awk '/^### W-[0-9]+[: ]/ && !/\(bez karty: *[^ )]/ { sub(/^### /, ""); sub(/[: ].*$/, ""); print }')
fi
if [ "$TRYB" != S ] && [ -d "$KARTY" ]; then
  for karta in "$KARTY"/W-*.md; do
    [ -e "$karta" ] || continue
    nazwa="$(basename "$karta" .md)"
    wzgl="docs/00-intake/funkcje/$nazwa.md"
    case "$nazwa" in W-[0-9][0-9]*) ;; *) blad "$wzgl: numeracja wymagań ma dwie cyfry (W-01, W-02 …)" ;; esac
    if ! ma_frontmatter "$karta"; then
      blad "$wzgl: brak frontmattera (wymaganie, rodzaj)"
      continue
    fi
    [ "$(fm_get "$karta" wymaganie)" = "$nazwa" ] ||
      blad "$wzgl: wymaganie='$(fm_get "$karta" wymaganie)', oczekiwano '$nazwa'"
    case "$(fm_get "$karta" rodzaj)" in
      pelna) wl=("${WLASCICIEL_PELNA[@]}"); wy=("${WYKONAWCA_PELNA[@]}") ;;
      skrocona) wl=("${WLASCICIEL_SKROCONA[@]}"); wy=("${WYKONAWCA_SKROCONA[@]}") ;;
      *)
        blad "$wzgl: rodzaj='$(fm_get "$karta" rodzaj)', dozwolone pelna albo skrocona"
        wl=("${WLASCICIEL_SKROCONA[@]}"); wy=("${WYKONAWCA_SKROCONA[@]}")
        ;;
    esac
    for czesc in "Dla właściciela" "Dla wykonawcy"; do
      grep -qxF "## $czesc" "$karta" || blad "$wzgl: brak części '$czesc'"
    done
    tresc_wl="$(czesc_karty "$karta" "Dla właściciela")"
    tresc_wy="$(czesc_karty "$karta" "Dla wykonawcy")"
    for sekcja in "${wl[@]}"; do
      awk -F '\t' -v n="### $sekcja" '$2 == n { z = 1 } END { exit !z }' <<<"$tresc_wl" ||
        blad "$wzgl: brak sekcji '$sekcja' w części 'Dla właściciela'"
    done
    for sekcja in "${wy[@]}"; do
      awk -F '\t' -v n="### $sekcja" '$2 == n { z = 1 } END { exit !z }' <<<"$tresc_wy" ||
        blad "$wzgl: brak sekcji '$sekcja' w części 'Dla wykonawcy'"
    done
    awk -F '\t' '$2 == "### Kryteria akceptacji" { w = 1; next } w && $2 ~ /^##/ { exit } w { print $2 }' <<<"$tresc_wy" |
      grep -qiE 'given.*when.*then' || blad "$wzgl: „Kryteria akceptacji” bez kryterium Given/When/Then"
    while IFS=$'\t' read -r nr linia; do
      [ -n "$nr" ] || continue
      blad "$wzgl:$nr: część dla właściciela bez kodu, kodów HTTP i atrybutów (przenieś do „Dla wykonawcy”): $linia"
    done < <(awk -F '\t' '$2 ~ /`|aria-|HTTP|(^|[^0-9])[1-5][0-9][0-9] [A-Z]|(^|[ (])(4|5)[0-9][0-9]([ ),.;:]|$)/' <<<"$tresc_wl" |
      grep -vE '[0-9]+ (znak|zna|min|sek|s\b|ms|zł|PLN|osób|dni|godz|%)' || true)
    while IFS=$'\t' read -r nr linia; do
      [ -n "$nr" ] || continue
      blad "$wzgl:$nr: $linia (otwarta luka: odpowiedź właściciela albo „Do potwierdzenia”)"
    done < <(bez_kodu "$karta" | awk -F '\t' '$2 ~ /\[\?\]/ || $2 ~ /(^|[ \t|(])\?([ \t|).,;:]|$)/ || $2 ~ /(^|[^A-Za-z])TODO([^A-Za-z]|$)/')
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
