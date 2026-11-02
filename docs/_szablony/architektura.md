# Architektura: NAZWA

Źródło: `docs/00-intake/specyfikacja.md` w rewizji SHA.

## Przegląd

## Moduły i granice

## Model danych

Migracje są zgodne wstecz (expand/contract): poprzednia wersja aplikacji działa na nowym schemacie.

## Integracje

## Bezpieczeństwo

Auth, dostęp do danych, sekrety, dane osobowe.

## Środowiska i droga na produkcję

| Środowisko | Opis w tym projekcie |
|---|---|
| LOCAL | Supabase CLI, blok portów z `konfiguracja.md` |
| PREVIEW | Preview deploy PR |
| STAGING | Wdrożenie `main` pod aliasem staging, osobny projekt Supabase migrowany przez CI (`STAGING_DB_URL`) |
| PROD | Bez dostępu agentów; wdraża właściciel przez `scripts/deploy-prod.sh vX.Y.Z` |

Droga na produkcję według `proces-v1.md` („Droga na produkcję”) i odstępstwa tego projektu.

## Testy

## Decyzje

Lista ADR z `adr/`.
