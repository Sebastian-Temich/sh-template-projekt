# Plan: NAZWA

Źródło: `docs/00-intake/specyfikacja.md` w rewizji SHA. Wymagania przywołujemy numerami `W-NN`.
Etap `04-plan`: krótka architektura i plan kamieni milowych w jednym dokumencie. Zadania rozpisuje
etap `06-zadania` (`docs/06-zadania/zadania.yaml`).

## Architektura

Krótko: tyle, ile potrzeba do rozpisania zadań. Szczegóły ważnych decyzji idą do ADR w `adr/`.

### Moduły i punkty wejścia

| Moduł / funkcja | Punkt wejścia (strona, trasa, komenda, endpoint) | Design (pliki) | Wymagania |
|---|---|---|---|

### Model danych

Migracje są zgodne wstecz (expand/contract): poprzednia wersja aplikacji działa na nowym schemacie.

### Integracje

### Bezpieczeństwo

Auth, dostęp do danych, sekrety, dane osobowe.

### Środowiska i droga na produkcję

| Środowisko | Opis w tym projekcie |
|---|---|
| LOCAL | Supabase CLI, blok portów z `konfiguracja.md` |
| PREVIEW | Preview deploy PR |
| STAGING | Wdrożenie `main` pod aliasem staging, osobny projekt Supabase migrowany przez CI (`STAGING_DB_URL`) |
| PROD | Bez dostępu agentów; wdraża właściciel przez `scripts/deploy-prod.sh vX.Y.Z` |

Odstępstwa tego projektu od drogi na produkcję z `proces-v1.md`:

### Decyzje

Lista ADR z `adr/`.

## Kamienie milowe

Każdy kamień to pionowy przekrój: działający rezultat jednej ścieżki (dane, API, UI, testy, docs),
dostępny z punktu wejścia. Pierwszy kamień zaczyna się od szkieletu projektu, ostatni kończy
dokumentacją wydania (`wydanie/techniczna`, `wydanie/produktowa`).

| Nr | Kamień milowy | Rezultat | Wymagania | Warunek startu |
|---|---|---|---|---|
| 1 | Szkielet | Repo, CI zielone, komendy w `AGENTS.md` sprawdzone | | Plan zaakceptowany |

## Zadania właściciela

| Zadanie | Przed | Uwagi |
|---|---|---|
| Konta prod na kontach klienta: Vercel, Supabase prod (UE) | odbiorem | |
| Projekt Supabase staging | pierwszą migracją na `main` | |
| Sekret `STAGING_DB_URL` w GitHub Secrets | pierwszą migracją na `main` | jedyny sekret w GitHubie |
| Domena i DNS | odbiorem | |
| Zmienne prod w panelu Vercel | wydaniem | |
| (typ projektu: konta w sklepach, publikacja) | | |

## Ryzyka

| Ryzyko | Skutek | Działanie (ADR, spike, dowody) | Właściciel |
|---|---|---|---|

## Scenariusze odbioru

5–10 scenariuszy, które właściciel sprawdza na stagingu przy odbiorze. QA zbiorcze sprawdza scenariusze
swojego kamienia.

| Nr | Scenariusz | Kroki | Oczekiwany wynik | Wymagania | Kamień |
|---|---|---|---|---|---|
| O-1 | | | | | |

## Zakres autoryzacji

Po akceptacji orkiestrator zapisuje go w `decyzje.md` przez `shctl decision add --rola wlasciciel`.

- Na co: kamienie milowe
- Zakres: wymagania, dostępy, płatne usługi
- Do kiedy: do odbioru zlecenia
- Wymaga nowej decyzji właściciela:

## Gotowość środowiska

Wynik `shctl doctor` przy planowaniu: czas UTC, wynik, braki ważne dla projektu z właścicielem.

## Następny krok

Jedno działanie z właścicielem.
