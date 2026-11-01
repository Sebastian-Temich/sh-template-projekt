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

## Droga na produkcję

Proces opisuje `sh-system/docs/proces-v1.md`, sekcja „Droga na produkcję”. Produkcję wdraża wyłącznie
właściciel ze swojego urządzenia. Na serwerze i w GitHub Secrets nie ma poświadczeń produkcyjnych.
Workflow `deploy-prod` jest zablokowany. W etapie A nie ma deployów produkcyjnych.

### Przygotowanie produkcji

Robisz to raz na projekt, na swoim urządzeniu, na kontach klienta.

1. Załóż projekt Vercel i podłącz repo.
2. Załóż projekt Supabase prod w regionie UE.
3. Załóż osobny projekt Supabase staging.
4. Zainstaluj i zaloguj Vercel CLI, Supabase CLI, `gh`, `jq` i Docker. Dump bazy działa w kontenerze.
   Na serwerze te CLI pozostają wylogowane.
5. Wyłącz automatyczny deploy produkcyjny z `main`. W Vercel: Settings → Environments → Production →
   Branch Tracking wpisz nazwę gałęzi, na którą nikt nie pushuje, np. `produkcja`, i zapisz. Każda
   inna gałąź, także `main`, wdraża się jako preview.
   **Nie używaj** `git.deploymentEnabled: { "main": false }`: to wyłącza deploy z commitów na `main`,
   a wdrożenie preview `main` jest stagingiem i wersją do promocji.
6. W Vercel ustaw zmienne. Production: wartości prod. Preview: wartości staging.
7. Dodaj domenę prod, a domenę staging przypisz do gałęzi `main`.
8. W repo dodaj jeden sekret:
   `gh secret set STAGING_DB_URL`. To connection string bazy staging, a nie token konta. Użyj
   session poolera (IPv4), a znaki specjalne hasła zakoduj procentowo.
9. Zapisz poświadczenia prod w menedżerze haseł albo w `.env.prod.local` poza repo.
10. Skonfiguruj DNS, Resend i Sentry prod. To zadania właściciela w planie projektu.
11. Zrób próbę na stagingu, także rollbacku (niżej).

### Zmienne dla `scripts/deploy-prod.sh`

| Zmienna | Znaczenie |
|---|---|
| `VERCEL_TOKEN`, `VERCEL_ORG_ID`, `VERCEL_PROJECT_ID` | Token i identyfikatory Vercel |
| `PROD_DB_URL`, `PROD_DOMAIN` | Connection string bazy prod (połączenie bezpośrednie), domena prod |
| `STAGING_DB_URL`, `STAGING_DOMAIN` | To samo dla `--target staging` |
| `SMOKE_PATH` | Ścieżka smoke testu, domyślnie `/` |
| `BACKUP_DIR` | Katalog backupów, domyślnie `~/sh-backupy` |

Backupy zawierają dane klienta. Trzymaj je na zaszyfrowanym dysku i usuwaj po okresie retencji.

### Wydanie

Orkiestrator przygotowuje `CHANGELOG.md`, tag, notatki, listę migracji i plan rollbacku w
`docs/wydanie/techniczna/`. Przejrzyj zmiany w `scripts/deploy-prod.sh` od poprzedniego wydania, bo
działa z Twoimi tokenami. Potem:

```bash
git switch --detach v1.2.3
scripts/deploy-prod.sh v1.2.3 --dry-run
scripts/deploy-prod.sh v1.2.3
```

Skrypt sprawdza tag, CI i wdrożenie preview tego commita, pokazuje migracje, prosi o wpisanie taga,
robi backup bazy, wykonuje migracje, promuje preview na produkcję i uruchamia smoke test. Przy
błędzie smoke testu cofa aplikację do poprzedniej wersji. Bazy nie cofa: migracje są zgodne wstecz, a
rollback bazy to migracja naprawcza albo backup.

Vercel przy promocji preview buduje ten sam commit od nowa ze zmiennymi Production, więc jest to ta
sama wersja kodu co na stagingu, ale nowe wdrożenie.

`--dry-run` wykonuje tylko odczyty, także smoke test bieżącej wersji.

### Próba na stagingu

```bash
scripts/deploy-prod.sh v1.2.3 --target staging
SMOKE_PATH=/nie-ma-takiej-strony scripts/deploy-prod.sh v1.2.3 --target staging
```

Staging nie ma promocji Vercel, więc skrypt przepina domenę staging poleceniem `vercel alias set`.
Drugie polecenie wymusza błąd smoke testu i sprawdza rollback. Kolejny push na `main` przywraca
domenę na najnowsze preview. Promocję i `vercel rollback` sprawdzisz dopiero na produkcji, dlatego
przed pierwszym wydaniem zrób je na projekcie testowym.

### Testy skryptu

```bash
bats scripts/tests/deploy-prod.bats
```

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
| `scripts/deploy-prod.sh` | Wdrożenie produkcyjne, tylko dla właściciela; testy w `scripts/tests/` |
| `.claude/roles/` | Profile uprawnień, uruchamiane przez `claude --settings` |
| `.github/` | Szablony issue i PR, CI, migracje staging, zablokowany workflow deploy produkcyjny |

## Tryby w DoD

Każdy `DoD.md` zawiera checklistę trybu M. Punkty tylko dla trybu L stoją w bloku
`<!-- tylko-tryb:L -->` i `check-dod.sh` liczy je wyłącznie w trybie L. Etapy `01-brief`,
`02-design` i `03-wymagania` należą tylko do trybu L. Tryb S nie ma DoD etapów: jego DoD to issue i
checklista PR.
