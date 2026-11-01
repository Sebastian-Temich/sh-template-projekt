#!/usr/bin/env bash
# Wdrożenie produkcyjne. Uruchamia wyłącznie właściciel, ze swojego urządzenia.
# Na serwerze i w GitHub Secrets nie ma poświadczeń produkcyjnych (proces-v1.md, „Dostępy”).
#
# Użycie: scripts/deploy-prod.sh vX.Y.Z [--dry-run]
#   --dry-run  sprawdza warunki i pokazuje migracje, niczego nie wdraża
#
# Wymagane zmienne: SUPABASE_ACCESS_TOKEN, SUPABASE_DB_PASSWORD, SUPABASE_PROJECT_REF,
#                   VERCEL_TOKEN, VERCEL_ORG_ID, VERCEL_PROJECT_ID
#
# Wdraża czysty eksport taga, z budowaniem po stronie Vercela. Kod projektu nie uruchamia się
# lokalnie, więc nie ma dostępu do tokenów z tego środowiska.
set -euo pipefail

blad() {
  echo "BŁĄD: $*" >&2
  exit 1
}

TAG=""
DRY=0
while [ $# -gt 0 ]; do
  case "$1" in
    --dry-run) DRY=1 ;;
    -*) blad "nieznana opcja $1" ;;
    *) [ -z "$TAG" ] || blad "podano więcej niż jeden tag"; TAG="$1" ;;
  esac
  shift
done

[ -n "$TAG" ] || blad "użycie: $0 vX.Y.Z [--dry-run]"
[[ "$TAG" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]] || blad "tag '$TAG' nie jest wersją semver vX.Y.Z"

[ ! -d "$HOME/sh/sh-system" ] || blad "to wygląda na serwer agentów; wdrożenie tylko z urządzenia właściciela"

for narzedzie in git gh supabase vercel; do
  command -v "$narzedzie" >/dev/null || blad "brak narzędzia $narzedzie"
done
for zmienna in SUPABASE_ACCESS_TOKEN SUPABASE_DB_PASSWORD SUPABASE_PROJECT_REF \
  VERCEL_TOKEN VERCEL_ORG_ID VERCEL_PROJECT_ID; do
  [ -n "${!zmienna:-}" ] || blad "brak zmiennej $zmienna"
done

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
echo "Warunki spełnione: $TAG, commit $COMMIT, CI zielone."

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
git archive "$COMMIT" | tar -x -C "$TMP"
cd "$TMP"

supabase link --project-ref "$SUPABASE_PROJECT_REF"
echo "Migracje do wykonania na produkcji:"
supabase db push --dry-run

if [ "$DRY" -eq 1 ]; then
  echo "deploy-prod: dry-run zakończony, nic nie wdrożono"
  exit 0
fi

[ -t 0 ] || blad "potwierdzenie wymaga terminala"
printf 'Wdrożyć %s na PRODUKCJĘ? Wpisz tag, aby potwierdzić: ' "$TAG"
read -r ODPOWIEDZ
[ "$ODPOWIEDZ" = "$TAG" ] || blad "brak potwierdzenia, nic nie wdrożono"

supabase db push
if ! vercel deploy --prod --yes; then
  blad "migracje wykonane, ale deploy Vercel nie przeszedł; produkcja ma nową bazę i starą aplikację"
fi
echo "deploy-prod: wdrożono $TAG"
