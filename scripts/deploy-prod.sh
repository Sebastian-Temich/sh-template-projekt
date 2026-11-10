#!/usr/bin/env bash
# Wdrożenie produkcyjne. Uruchamia wyłącznie właściciel, ze swojego urządzenia.
# Na serwerze i w GitHub Secrets nie ma poświadczeń produkcyjnych (proces-v1.md, „Droga na produkcję”).
#
# Użycie: scripts/deploy-prod.sh vX.Y.Z [--dry-run] [--target prod|staging] [--tylko-aplikacja]
#   --dry-run          wykonuje tylko odczyty (w tym smoke test), kroki zmieniające stan wypisuje
#   --target staging   próba całej drogi na stagingu, także rollbacku
#   --tylko-aplikacja  ponowienie po awarii Vercela: bez backupu i migracji, stan migracji tylko pokazuje
#
# Zmienne: VERCEL_TOKEN, VERCEL_ORG_ID, VERCEL_PROJECT_ID oraz
#   prod:    PROD_DB_URL, PROD_DOMAIN
#   staging: STAGING_DB_URL, STAGING_DOMAIN
# Opcjonalnie: SMOKE_PATH (domyślnie /), BACKUP_DIR (domyślnie ~/sh-backupy)
#
# Aplikacja nie buduje się lokalnie: Vercel promuje wdrożenie preview tego commita.
# Kod projektu nie uruchamia się więc na urządzeniu właściciela obok tokenów.
set -euo pipefail
umask 077

blad() {
  echo "BŁĄD: $*" >&2
  exit 1
}

TAG=""
DRY=0
CEL=prod
TYLKO_APLIKACJA=0
while [ $# -gt 0 ]; do
  case "$1" in
    --dry-run) DRY=1 ;;
    --tylko-aplikacja) TYLKO_APLIKACJA=1 ;;
    --target)
      [ $# -ge 2 ] || blad "--target wymaga wartości"
      CEL="$2"
      shift
      ;;
    -*) blad "nieznana opcja $1" ;;
    *) [ -z "$TAG" ] || blad "podano więcej niż jeden tag"; TAG="$1" ;;
  esac
  shift
done

[ -n "$TAG" ] || blad "użycie: $0 vX.Y.Z [--dry-run] [--target prod|staging] [--tylko-aplikacja]"
[[ "$TAG" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]] || blad "tag '$TAG' nie jest wersją semver vX.Y.Z"

case "$CEL" in
  prod) ZMIENNA_DB=PROD_DB_URL; ZMIENNA_DOMENA=PROD_DOMAIN ;;
  staging) ZMIENNA_DB=STAGING_DB_URL; ZMIENNA_DOMENA=STAGING_DOMAIN ;;
  *) blad "--target: dozwolone prod albo staging" ;;
esac

# Serwer agentów: katalog SH w /Users/Shared/sh (SH_DIR w testach) albo dawne ~/sh.
[ ! -d "${SH_DIR:-/Users/Shared/sh}/sh-system" ] && [ ! -d "$HOME/sh/sh-system" ] || blad "to wygląda na serwer agentów; wdrożenie tylko z urządzenia właściciela"

for narzedzie in git gh jq curl docker supabase vercel; do
  command -v "$narzedzie" >/dev/null || blad "brak narzędzia $narzedzie"
done
for zmienna in VERCEL_TOKEN VERCEL_ORG_ID VERCEL_PROJECT_ID "$ZMIENNA_DB" "$ZMIENNA_DOMENA"; do
  [ -n "${!zmienna:-}" ] || blad "brak zmiennej $zmienna"
done
DB_URL="${!ZMIENNA_DB}"
DOMENA="${!ZMIENNA_DOMENA}"
SMOKE_URL="https://$DOMENA${SMOKE_PATH:-/}"

# Kroki zmieniające stan. Opis nie zawiera argumentów, bo są w nich poświadczenia.
wykonaj() {
  local opis="$1"
  shift
  if [ "$DRY" -eq 1 ]; then
    echo "[dry-run] $opis"
    return 0
  fi
  echo "==> $opis"
  "$@"
}

# Łańcuch &&, bo wywołanie stoi przed `||` i set -e tu nie działa.
backup_bazy() {
  mkdir -p "$BACKUP" &&
    supabase db dump --db-url "$DB_URL" -f "$BACKUP/roles.sql" --role-only &&
    supabase db dump --db-url "$DB_URL" -f "$BACKUP/schema.sql" &&
    supabase db dump --db-url "$DB_URL" -f "$BACKUP/data.sql" --use-copy --data-only \
      -x "storage.buckets_vectors" -x "storage.vector_indexes"
}

# Produkcja: promocja preview, Vercel przebudowuje ten commit ze zmiennymi prod (README).
# Staging nie ma promocji, więc próbę wykonuje przepięcie domeny.
ustaw_wersje() {
  if [ "$CEL" = "prod" ]; then
    vercel promote "$1" --yes --timeout 15m
  else
    vercel alias set "$1" "$DOMENA"
  fi
}

cofnij_wersje() {
  if [ "$CEL" = "prod" ]; then
    vercel rollback "$1" --yes --timeout 5m
  else
    vercel alias set "$1" "$DOMENA"
  fi
}

# 1. Tag i CI
ROOT="$(git rev-parse --show-toplevel)"
cd "$ROOT"

git fetch --quiet --tags origin
ZDALNY="$(git ls-remote origin "refs/tags/$TAG^{}" "refs/tags/$TAG" | tail -n 1 | cut -f 1)"
[ -n "$ZDALNY" ] || blad "tagu $TAG nie ma na origin"
COMMIT="$(git rev-parse "$TAG^{commit}")"
[ "$ZDALNY" = "$COMMIT" ] || blad "tag $TAG różni się od tagu na origin"

git fetch --quiet origin main
git merge-base --is-ancestor "$COMMIT" origin/main || blad "commit taga $TAG nie należy do origin/main"
[ "$(git rev-parse HEAD)" = "$COMMIT" ] || blad "HEAD nie wskazuje na $TAG (git switch --detach $TAG)"
[ -z "$(git status --porcelain)" ] || blad "drzewo robocze nie jest czyste"

CI="$(gh run list --workflow ci.yml --commit "$COMMIT" --limit 1 --json conclusion --jq '.[0].conclusion // ""')"
[ "$CI" = "success" ] || blad "CI na $COMMIT nie jest zielone (wynik: '${CI:-brak}')"
echo "Warunki spełnione: $TAG, commit $COMMIT, CI zielone, cel: $CEL."

TMP="$(mktemp -d "${TMPDIR:-/tmp}/deploy-prod.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT
git archive "$COMMIT" | tar -x -C "$TMP"
cd "$TMP"

# 2. Wersje aplikacji: ta, która przeszła staging, i bieżąca (cel rollbacku)
KANDYDAT="$(vercel list --environment preview --status READY --meta "githubCommitSha=$COMMIT" --json --yes |
  jq -r '(.deployments? // .) | .[0].url // ""')"
[ -n "$KANDYDAT" ] || blad "brak gotowego wdrożenia preview dla $COMMIT"
POPRZEDNI="$(vercel inspect "$DOMENA" --json 2>/dev/null | jq -r '.url // ""' || true)"
echo "Wersja do wdrożenia: $KANDYDAT"
echo "Wersja bieżąca: ${POPRZEDNI:-brak}"
[ -n "$POPRZEDNI" ] || echo "UWAGA: brak bieżącej wersji, rollback aplikacji nie będzie możliwy."

# 3. Lista migracji i potwierdzenie
echo "Stan migracji:"
supabase migration list --db-url "$DB_URL"
echo "Migracje do wykonania:"
supabase db push --db-url "$DB_URL" --dry-run

if [ "$DRY" -eq 0 ]; then
  [ -t 0 ] || blad "potwierdzenie wymaga terminala"
  printf 'Wdrożyć %s na %s? Wpisz tag, aby potwierdzić: ' "$TAG" "$CEL"
  read -r ODPOWIEDZ
  [ "$ODPOWIEDZ" = "$TAG" ] || blad "brak potwierdzenia, nic nie wdrożono"
fi

# 4. Backup i migracje
KATALOG_BACKUPOW="${BACKUP_DIR:-$HOME/sh-backupy}"
if [ "$TYLKO_APLIKACJA" -eq 1 ]; then
  BACKUP="ostatni backup w $KATALOG_BACKUPOW"
  echo "--tylko-aplikacja: backup i migracje pominięte."
else
  BACKUP="$KATALOG_BACKUPOW/$CEL-$TAG-$(date -u +%Y%m%dT%H%M%SZ)"
  wykonaj "backup bazy $CEL do $BACKUP" backup_bazy || blad "backup się nie udał, nic nie wdrożono"
  wykonaj "migracje bazy $CEL" supabase db push --db-url "$DB_URL" --yes ||
    blad "migracje się nie udały, aplikacja bez zmian; backup: $BACKUP"
fi

# 5. Aplikacja
if ! wykonaj "wdrożenie $KANDYDAT na $CEL" ustaw_wersje "$KANDYDAT"; then
  PONOW="scripts/deploy-prod.sh $TAG --tylko-aplikacja"
  [ "$CEL" = "prod" ] || PONOW="$PONOW --target $CEL"
  echo "BŁĄD: wdrożenie aplikacji przez Vercel się nie udało." >&2
  echo "Stan: baza zaktualizowana, stara aplikacja działa dzięki migracjom zgodnym wstecz." >&2
  echo "Po usunięciu awarii ponów: $PONOW" >&2
  echo "Przekroczenie czasu nie przerywa promocji, sprawdź: vercel promote status. Backup: $BACKUP" >&2
  exit 1
fi

# 6. Smoke test i rollback
if curl -fsS -o /dev/null --max-time 15 --retry 5 --retry-delay 6 --retry-all-errors "$SMOKE_URL"; then
  [ "$DRY" -eq 0 ] || { echo "deploy-prod: dry-run zakończony, nic nie wdrożono"; exit 0; }
  echo "deploy-prod: wdrożono $TAG na $CEL"
  exit 0
fi

echo "BŁĄD: smoke test nie przeszedł: $SMOKE_URL" >&2
[ -n "$POPRZEDNI" ] || blad "brak wersji do rollbacku; napraw ręcznie, backup: $BACKUP"
wykonaj "rollback aplikacji do $POPRZEDNI" cofnij_wersje "$POPRZEDNI" ||
  blad "rollback aplikacji się nie udał; napraw ręcznie, backup: $BACKUP"
echo "Rollback aplikacji wykonany. Baza zostaje po migracjach, bo są zgodne wstecz." >&2
echo "Rollback bazy: migracja naprawcza albo backup $BACKUP, według planu rollbacku." >&2
exit 1
