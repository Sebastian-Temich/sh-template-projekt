# Plan: NAZWA

Źródło: `docs/00-intake/specyfikacja.md` w rewizji SHA. Wymagania przywołujemy numerami `W-n`.

## Kamienie milowe

Każdy kamień to pionowy przekrój: działający rezultat jednej ścieżki (dane, API, UI, testy, docs).

| Nr | Kamień milowy | Rezultat | Wymagania | Warunek startu |
|---|---|---|---|---|
| 1 | Szkielet | Repo, CI zielone, komendy w `AGENTS.md` sprawdzone | | Plan zaakceptowany |

## Zadania

| Nr | Zadanie | Kamień | Zależności | Wykonawca |
|---|---|---|---|---|
| 1 | Szkielet projektu (sekwencyjnie) | 1 | | claude |
| N | Dokumentacja wydania (`wydanie/techniczna`, `wydanie/produktowa`) | ostatni | wszystkie | claude |

Pierwsze zadanie kamienia 1 to szkielet, ostatnie zadanie planu to dokumentacja wydania.

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
