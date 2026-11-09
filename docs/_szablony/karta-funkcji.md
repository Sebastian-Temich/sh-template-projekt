---
wymaganie: W-N
rodzaj: pelna
priorytet: musi
---

# Karta funkcji W-N: TYTUŁ

Wymaganie: `docs/00-intake/specyfikacja.md`, W-N. Design: ścieżki w `docs/00-intake/zrodla/` albo
„brak designu” (wtedy stany ekranu opisuje karta, a `sh-plan` zapisuje decyzję w zadaniu).

<!--
Wzór karty funkcji (sh-intake, etap 00-intake). Plik: docs/00-intake/funkcje/W-N.md, nazwa równa polu
`wymaganie`. Jedna karta na funkcję użytkową z specyfikacji; wymaganie bez funkcji użytkowej (np.
wydajność, SEO) ma w nagłówku specyfikacji „(bez karty: powód)”.

rodzaj: pelna (funkcja kluczowa: dane osobowe, płatności, integracja, kilka kroków) albo skrocona
(funkcja prosta). Skrócona ma tylko sekcje: Wejście, Przebieg, Stany ekranu, Kryteria akceptacji, Poza
zakresem, Założenia modelu. Tryb S nie ma kart w repo: krótka karta trafia do celu issue.

Luka to „[?]”, samotny „?” (np. komórka tabeli „| ? |”) albo TODO. scripts/check-dod.sh odrzuca kartę
z luką, więc przed PR każda luka ma odpowiedź właściciela albo założenie w „Założeniach modelu”.
Sekcja bez zastosowania: jedna linia „Nie dotyczy: powód.”. Ten komentarz usuń.
-->

## Wejście

Kto (rola z „Użytkowników”), skąd wchodzi (trasa, element nawigacji, przycisk, link w e-mailu) i w
jakim stanie (zalogowany, z koszykiem, pierwszy raz).

## Przebieg

1. Użytkownik …
2. System …
3. …

Ekran każdego kroku: plik designu i ramka albo „brak w designie”.

## Stany ekranu

| Stan | Kiedy | Co widzi użytkownik | Design |
|---|---|---|---|
| Pusty | Brak danych, pierwsze wejście | | |
| Ładowanie lub postęp | Czekanie na serwer, wysyłka | | |
| Sukces | | | |
| Częściowy sukces | Część operacji się udała | | |
| Błąd walidacji | Złe albo brakujące dane | | |
| Błąd serwera lub usługi | Timeout, 5xx, usługa zewnętrzna | | |
| Brak uprawnień lub limit | 401, 403, 429 | | |

Wiersz bez zastosowania: „nie dotyczy: powód” w kolumnie „Co widzi użytkownik”.

## Dane wejścia i wyjścia

| Pole | Kierunek | Typ i format | Wymagane | Limit i walidacja | Komunikat błędu |
|---|---|---|---|---|---|

Gdzie trafiają dane (baza, e-mail, usługa zewnętrzna), jak długo są przechowywane i czy to dane osobowe.

## Reguły biznesowe

- R1: …

## Przypadki brzegowe

- Podwójne kliknięcie, wolna sieć, powrót przyciskiem „wstecz”, odświeżenie w trakcie
- Wartości graniczne (puste, maksymalne, znaki specjalne, emoji)
- Brak JavaScriptu, czytnik ekranu, telefon

## Kryteria akceptacji

Identyfikatory `W-N/K1`, `W-N/K2`, … przywołują zadania (`sh-plan`) i review. Każde kryterium
sprawdzalne testem albo oznaczone „(ręcznie: dlaczego)”.

- W-N/K1: Given STAN, when DZIAŁANIE, then WYNIK.

## Poza zakresem

- …

## Założenia modelu

Odpowiedzi „zdecyduj sam” i luki rozstrzygnięte bez pytania. Każde założenie trafia też do „Decyzji do
rejestru” w opisie PR (orkiestrator zapisuje je w `decyzje.md`) i do listy do potwierdzenia w
checkpoincie specyfikacji.

| Nr | Założenie | Dlaczego | Status |
|---|---|---|---|
| Z1 | | | do potwierdzenia |
