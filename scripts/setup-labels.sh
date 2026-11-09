#!/usr/bin/env bash
# Zakłada etykiety z docs/proces-v1.md („Etykiety GitHub”). Idempotentny: istniejące aktualizuje.
# Użycie: scripts/setup-labels.sh [--dry-run] [--repo WLASCICIEL/NAZWA]
set -euo pipefail

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

# nazwa|kolor|opis
ETYKIETY='
runner:local|1D76DB|Zadanie dla lokalnego workera
runner:cloud|0E8A16|Zadanie dla workera w chmurze (etap B)
wykonawca:claude|5319E7|Wykonawca: Claude
wykonawca:codex|006B75|Wykonawca: Codex (etap B)
tryb:S|C2E0C6|Zlecenie w trybie S
tryb:M|FEF2C0|Zlecenie w trybie M
widoczne:nie|BFDADC|Zlecenie S bez zmian widocznych dla użytkownika (odbior_S)
status:todo|EDEDED|Czeka na realizację
status:in-progress|FBCA04|W realizacji
status:review|0052CC|PR czeka na review
status:blocked|D93F0B|Czeka na coś zewnętrznego, bez eskalacji
status:escalated|B60205|Eskalacja do właściciela
iter:1|D4C5F9|Iteracja poprawek 1
iter:2|B39DDB|Iteracja poprawek 2
iter:3|8E6BBF|Iteracja poprawek 3
db:migracja|F9D0C4|Migracja lub reset bazy, pojedynczo w projekcie
typ:feature|A2EEEF|Funkcja
typ:bug|D73A4A|Błąd
typ:qa|BFD4F2|QA
typ:docs|0075CA|Dokumentacja
typ:cr|C5DEF5|Change request
sev:krytyczne|B60205|Zgłoszenie krytyczne, blokuje
sev:istotne|FBCA04|Zgłoszenie istotne, blokuje
sev:drobne|C2E0C6|Zgłoszenie drobne, nie blokuje
'

licznik=0
while IFS='|' read -r nazwa kolor opis; do
  [ -n "$nazwa" ] || continue
  licznik=$((licznik + 1))
  if [ "$DRY" -eq 1 ]; then
    echo "etykieta: $nazwa ($kolor) $opis"
  else
    gh label create "$nazwa" --color "$kolor" --description "$opis" --force ${REPO_ARGS[@]+"${REPO_ARGS[@]}"}
  fi
done <<EOF
$ETYKIETY
EOF

echo "setup-labels: $licznik etykiet"
