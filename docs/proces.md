# Proces AI Software House w tym repo

Repo powstało z szablonu `sh-template-projekt` i jest prowadzone przez agentów AI Software House
(proces: `sh-system/docs/proces-v1.md`). Ten plik opisuje, jak działa praca w repo; o samym projekcie
mówi `README.md`, a o bieżącym stanie `docs/Projekt.md`.

## Jak to działa

- Właściciel zleca pracę zwykłym językiem. Orkiestrator (Claude Code na serwerze) prowadzi etapy:
  specyfikacja z kartami funkcji (`docs/00-intake/`), plan (`docs/04-plan/`), zadania jako issue,
  realizacja (worker w osobnym worktree, PR „Closes #NR”), review w świeżej sesji bez kontekstu workera (Claude albo Codex, zależnie od ryzyka PR), QA po
  kamieniu milowym (`docs/08-qa/`), odbiór.
- Stan projektu dla ludzi: `docs/Projekt.md` (generuje `scripts/sync-status.sh` przy każdej zmianie
  stanu: gdzie jesteśmy, co czeka na właściciela, zadania bieżącego zlecenia, eskalacje, dokumenty).
  Punkt przekazania, dziennik etapów i pełna lista zadań są w `docs/historia.md`.
- Mechanikę (gałęzie, worktree, etykiety, eskalacje, merge) wykonuje `shctl`. Pliki wspólne
  (`docs/Projekt.md`, `docs/historia.md`, `decyzje.md`, `metryki.md`, `backlog-drobne.md`, `06-zadania/index.md`,
  `CHANGELOG.md`) zmienia wyłącznie orkiestrator na `main`.
- Instrukcje dla agentów: `AGENTS.md`.

## Jak powstaje projekt

```bash
shctl new-project NAZWA --opis "Krótki opis repo" [--zlecenie "TREŚĆ ZLECENIA"] [--prywatny]
```

Komenda zakłada repo na koncie Sebastian-Temich jako zwykłe repo (bez „generated from”): pliki
szablonu trafiają tam pierwszym commitem po skanie `gitleaks`. Domyślnie repo jest publiczne;
prywatne tylko na wyraźne polecenie właściciela (`--prywatny`), a jego CI korzysta z runnera na
serwerze (zmienna repo `SH_RUNS_ON`). Do tego:

1. opis repo i temat `sh-projekt`, później aktualizowane przez `shctl repo opis` na checkpointach
   specyfikacji, planu i odbioru;
2. ruleset `sh-ochrona-galezi`: bez usuwania i force push na `main` i `production`;
3. etykiety (`scripts/setup-labels.sh`) i blok portów w `/Users/Shared/sh/porty.md`;
4. `tryb_procesu` w `docs/konfiguracja.md` i etapy spoza trybu jako `pominiety`.

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
5. Ustaw gałąź produkcyjną. W Vercel: Settings → Environments → Production → Branch Tracking wpisz
   `production` zamiast `main` i zapisz. Dzięki temu `main` wdraża się jako preview. Gałęzi
   `production` nie zakładaj i nie pushuj na nią: każdy commit na tej gałęzi Vercel wdraża produkcyjnie.
   **Nie używaj** `git.deploymentEnabled: { "main": false }`: to wyłącza deploy z commitów na `main`,
   a wdrożenie preview `main` jest stagingiem i wersją do promocji.
6. W Vercel ustaw zmienne. Production: wartości prod. Preview: wartości staging.
7. Dodaj domenę prod. Domenę staging przypisz do `main`: Settings → Domains → Edit → Connect to an
   environment: Preview → Git Branch: `main`. To stały alias stagingu.
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

`--dry-run` wykonuje tylko odczyty, także smoke test bieżącej wersji.

Gdy Vercel zawiedzie po migracjach, baza jest już zaktualizowana, a stara aplikacja działa dzięki
migracjom zgodnym wstecz. Po usunięciu awarii ponów tylko krok aplikacji. Skrypt pokaże stan migracji,
bez backupu i bez migracji, a w razie błędu smoke testu cofnie aplikację:

```bash
scripts/deploy-prod.sh v1.2.3 --tylko-aplikacja
```

### Promocja i rollback w Vercel: wynik sprawdzenia dokumentacji

Sprawdzone 2026-11-01 w dokumentacji Vercel oraz w `vercel --help` i kodzie Vercel CLI 65.9.0.

- **Promocja preview przebudowuje aplikację.** Dokumentacja:
  [„through a complete rebuild”](https://vercel.com/docs/deployments/promoting-a-deployment), zmienne
  zmieniają się z Preview na Production, a zmiennych preview nie można użyć w produkcji.
  [`vercel promote`](https://vercel.com/docs/cli/promote) tworzy przy tym „a new production
  deployment”. Na produkcji jest więc ten sam commit co na stagingu, ale nowy build. Build może się
  nie udać albo dać inny wynik niż na stagingu, dlatego po promocji działa smoke test.
- `--yes` pomija potwierdzenie promocji preview. Przekroczenie `--timeout` kończy tylko czekanie CLI,
  promocja trwa dalej, a jej stan pokazuje `vercel promote status`.
- **Rollback nie przebudowuje aplikacji.** [Stara wersja](https://vercel.com/docs/instant-rollback)
  zachowuje swoje zmienne środowiskowe sprzed zmian w panelu. Celem może być tylko wdrożenie, które
  było już produkcyjne. Na planie Hobby tylko poprzednie.
- Po rollbacku Vercel wyłącza automatyczne przypisywanie domen produkcyjnych. Następne `vercel promote`
  [włącza je z powrotem](https://vercel.com/docs/cli/rollback).

### Próba na stagingu

```bash
scripts/deploy-prod.sh v1.2.3 --target staging
SMOKE_PATH=/nie-ma-takiej-strony scripts/deploy-prod.sh v1.2.3 --target staging
```

Staging nie ma promocji Vercel, więc skrypt przepina domenę staging poleceniem `vercel alias set`.
Drugie polecenie wymusza błąd smoke testu i sprawdza rollback. Pamiętaj, że każde przejście bez
`--tylko-aplikacja` robi backup i migruje staging. Kolejny push na `main` przywraca
domenę na najnowsze preview. Promocję i `vercel rollback` sprawdzisz dopiero na produkcji, dlatego
przed pierwszym wydaniem zrób je na projekcie testowym.

### Testy skryptu

```bash
bats scripts/tests
```

Testy skryptów (`scripts/tests`) działają w CI tylko w repo szablonu (`.github/workflows/szablon.yml`).
W projekcie ten workflow jest pominięty, a `ci.yml` nie ma joba `testy-skryptow`: testy czytały żywe
`docs/` projektu i dawały fałszywe alarmy (sh-dryrun: 39 czerwonych przebiegów).

## Zawartość

| Ścieżka | Zawartość |
|---|---|
| `AGENTS.md` | Jedyny plik instrukcji dla agentów |
| `CLAUDE.md` | Import `AGENTS.md` i wskazówki dla Claude |
| `CHANGELOG.md` | Zmiany projektu, aktualizowane przez `shctl task close` |
| `docs/` | Etapy z `DoD.md`, pliki wspólne, `konfiguracja.md` |
| `docs/_szablony/` | Szablony dokumentów |
| `scripts/check-dod.sh` | Walidacja DoD, zakaz hooków git i kodu wykonywalnego w `docs/`, działa w CI |
| `scripts/setup-labels.sh` | Etykiety GitHub, idempotentnie |
| `scripts/sync-status.sh` | Stan issue, PR i CI do `06-zadania/index.md`, `docs/Projekt.md` (widok projektu dla właściciela) i `docs/historia.md` (lista zadań), wstrzymania z `/Users/Shared/sh/limity.md` |
| `scripts/deploy-prod.sh` | Wdrożenie produkcyjne, tylko dla właściciela; testy w `scripts/tests/` |
| `.claude/roles/worker/` | Profil uprawnień workera, uruchamiany przez `claude --settings` |
| `.claude/roles/reviewer/` | Profil reviewera Claude (tylko odczyt, bez sieci); `shctl review run` bierze go z `main` |
| `.github/` | Szablony issue i PR, CI, migracje staging, zablokowany workflow deploy produkcyjny |

## Tryby w DoD

Każdy `DoD.md` zawiera checklistę trybu M. Punkty tylko dla trybu L stoją w bloku
`<!-- tylko-tryb:L -->` i `check-dod.sh` liczy je wyłącznie w trybie L. Tryb L (z etapami briefu,
designu i wymagań) jest odłożony. `07-realizacja` nie ma `DoD.md`: stan realizacji jest w issue. Tryb
S nie ma DoD etapów: jego DoD to issue i checklista PR.

Pole, które w projekcie nie ma zastosowania (np. E2E w bibliotece bez UI), zapisujemy jako
`- [-] treść pola (nie dotyczy: powód)`. `check-dod.sh` liczy je jak zamknięte, a `[-]` bez powodu
odrzuca. Etap trybu M pomija się tylko z decyzją: orkiestrator zapisuje ją przez `shctl decision add` i
ustawia w `DoD.md` na `main` `status: pominiety` oraz `decyzja: "..."`; bez pola `decyzja`
`check-dod.sh` odrzuca status `pominiety`.
Frontmatter `DoD.md` (`status`, `iteracja`) zmienia tylko shctl na `main`, nigdy gałąź `stage/ETAP`.
