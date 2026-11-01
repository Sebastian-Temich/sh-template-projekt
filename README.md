# sh-template-projekt

Szablon repozytorium projektu AI Software House. Proces opisuje `sh-system/docs/proces-v1.md`.

## Jak powstaje projekt

Projekt zakłada orkiestrator lub właściciel jedną komendą:

```bash
shctl new-project NAZWA
```

Komenda tworzy repo na koncie Sebastian-Temich z tego szablonu i klonuje je. Szablon przenosi tylko
pliki. Ustawienia repo trzeba założyć w każdym projekcie osobno, więc `shctl new-project` musi też:

1. uruchomić `scripts/setup-labels.sh`;
2. zarezerwować blok portów w `~/sh/porty.md`;
3. ustawić `tryb_procesu` i `hosting` w `docs/konfiguracja.md` po akceptacji właściciela;
4. oznaczyć w `DoD.md` jako `pominiety` etapy spoza wybranego trybu.

Projekty klientów są domyślnie prywatne.

## Wdrożenie produkcyjne

Produkcję wdraża wyłącznie właściciel ze swojego urządzenia. Na serwerze i w GitHub Secrets nie ma
żadnych poświadczeń produkcyjnych. Workflow `deploy-prod` jest zablokowany, bo GitHub nie oferuje
wymaganej akceptacji w repo prywatnych bez Enterprise, a agenci używają tokenu właściciela. W
pilocie nie ma deployów produkcyjnych.

```bash
git switch --detach v1.2.3
scripts/deploy-prod.sh v1.2.3 --dry-run
scripts/deploy-prod.sh v1.2.3
```

Skrypt wymaga narzędzi `git`, `gh`, `supabase` i `vercel` oraz tych zmiennych środowiskowych:

| Zmienna | Znaczenie |
|---|---|
| `SUPABASE_ACCESS_TOKEN` | Osobisty token Supabase |
| `SUPABASE_DB_PASSWORD` | Hasło bazy produkcyjnej |
| `SUPABASE_PROJECT_REF` | Identyfikator projektu Supabase |
| `VERCEL_TOKEN` | Token Vercel |
| `VERCEL_ORG_ID` | Identyfikator zespołu Vercel |
| `VERCEL_PROJECT_ID` | Identyfikator projektu Vercel |

Skrypt sprawdza tag semver `vX.Y.Z` na `origin`, przynależność commita do `main`, czyste drzewo i
zielone CI, pokazuje migracje i prosi o wpisanie taga. Potem wdraża czysty eksport taga:
`supabase db push`, a następnie `vercel deploy --prod --yes`. Build działa po stronie Vercela, więc
kod projektu nie uruchamia się lokalnie obok tokenów.

Przed uruchomieniem przejrzyj zmiany w `scripts/deploy-prod.sh` od poprzedniego wdrożenia, bo
działa on z Twoimi tokenami.

### Vercel: bez automatycznego deployu z main

Bez tego ustawienia każdy merge na `main` trafiałby na produkcję z pominięciem skryptu. Do
`vercel.json` w projekcie dopisz:

```json
{
  "$schema": "https://openapi.vercel.sh/vercel.json",
  "git": {
    "deploymentEnabled": {
      "main": false
    }
  }
}
```

Gałąź niewymieniona ma domyślnie `true`, więc pozostałe gałęzie nadal dostają preview deploy
(`https://vercel.com/docs/project-configuration/git-configuration`). Dokumentacja opisuje to
ustawienie jako wyzwalanie deployu przez commity. Działanie `vercel deploy --prod` przy tym
ustawieniu potwierdź przy pierwszym projekcie.

## Zawartość

| Ścieżka | Zawartość |
|---|---|
| `AGENTS.md` | Jedyny plik instrukcji dla agentów |
| `CLAUDE.md` | Import `AGENTS.md` i wskazówki dla Claude |
| `CHANGELOG.md` | Zmiany projektu, aktualizowane przez `shctl task close` |
| `docs/` | Etapy z `DoD.md`, pliki wspólne, `konfiguracja.md` |
| `docs/_szablony/` | Szablony dokumentów |
| `scripts/check-dod.sh` | Walidacja DoD, działa w CI |
| `scripts/setup-labels.sh` | Etykiety GitHub, idempotentnie |
| `scripts/sync-status.sh` | Stan issue, PR i CI do `06-zadania/index.md` i `status.md` |
| `scripts/deploy-prod.sh` | Wdrożenie produkcyjne, tylko dla właściciela |
| `.claude/roles/` | Profile uprawnień, uruchamiane przez `claude --settings` |
| `.github/` | Szablony issue i PR, CI, zablokowany workflow deploy produkcyjny |

## Tryby w DoD

Każdy `DoD.md` zawiera checklistę trybu M. Punkty tylko dla trybu L stoją w bloku
`<!-- tylko-tryb:L -->` i `check-dod.sh` liczy je wyłącznie w trybie L. Etapy `01-brief`,
`02-design` i `03-wymagania` należą tylko do trybu L. Tryb S nie ma DoD etapów: jego DoD to issue i
checklista PR.
