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
2. założyć environment `production` z wymaganą akceptacją właściciela;
3. zarezerwować blok portów w `~/sh/porty.md`;
4. ustawić `tryb_procesu` i `hosting` w `docs/konfiguracja.md` po akceptacji właściciela;
5. oznaczyć w `DoD.md` jako `pominiety` etapy spoza wybranego trybu.

Projekty klientów są domyślnie prywatne.

Workflow `deploy-prod` ma job `bramka`: bez reguły `required_reviewers` w environment `production`
deploy nie startuje. GitHub odrzuca tę regułę dla prywatnych repo, gdy plan konta jej nie obsługuje.

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
| `.claude/roles/` | Profile uprawnień, uruchamiane przez `claude --settings` |
| `.github/` | Szablony issue i PR, CI, deploy produkcyjny |

## Tryby w DoD

Każdy `DoD.md` zawiera checklistę trybu M. Punkty tylko dla trybu L stoją w bloku
`<!-- tylko-tryb:L -->` i `check-dod.sh` liczy je wyłącznie w trybie L. Etapy `01-brief`,
`02-design` i `03-wymagania` należą tylko do trybu L. Tryb S nie ma DoD etapów: jego DoD to issue i
checklista PR.
