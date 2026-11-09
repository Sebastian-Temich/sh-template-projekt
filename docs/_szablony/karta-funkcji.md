---
wymaganie: W-NN
rodzaj: pelna
priorytet: musi
---

# Karta funkcji W-NN: TYTUŁ

<!--
Wzór karty funkcji (sh-intake, etap 00-intake). Plik: docs/00-intake/funkcje/W-NN.md (dwie cyfry:
W-01, W-02 …), nazwa równa polu `wymaganie`. Jedna karta na funkcję użytkową ze specyfikacji;
wymaganie bez funkcji użytkowej (np. wydajność, SEO) ma w nagłówku specyfikacji „(bez karty: powód)”.

Dwie części. „Dla właściciela” czyta właściciel w checkpoincie specyfikacji: prosty język, bez kodów
HTTP, atrybutów, nazw pól z kodu i backticków. „Dla wykonawcy” czytają sh-plan, worker i review.

rodzaj: pelna (funkcja kluczowa: dane osobowe, płatności, integracja, kilka kroków) albo skrocona
(funkcja prosta). Skrócona ma: Opis, Przebieg, Stany ekranu, Poza zakresem, Do potwierdzenia oraz
Kryteria akceptacji i Design i ADR. Tryb S nie ma kart w repo: krótka karta trafia do celu issue.

Luka to „[?]”, samotny „?” (np. komórka tabeli „| ? |”) albo TODO. scripts/check-dod.sh odrzuca kartę
z luką, więc przed PR każda luka ma odpowiedź właściciela albo wiersz w „Do potwierdzenia”.
Sekcja bez zastosowania: jedna linia „Nie dotyczy: powód.”. Ten komentarz usuń.
-->

## Dla właściciela

### Opis

Jeden akapit prostym językiem: kto, co robi, po co i co dostaje na końcu.

### Przebieg

Z perspektywy użytkownika:

1. Użytkownik …
2. Widzi …
3. …

### Stany ekranu

| Stan | Kiedy | Co widzi użytkownik |
|---|---|---|
| Pusty | Pierwsze wejście, brak danych | |
| W trakcie | Czekanie, wysyłanie | |
| Sukces | | |
| Częściowy sukces | Część się udała | |
| Błąd w danych | Brak lub zły wpis | |
| Błąd po naszej stronie | Usługa nie działa albo nie odpowiada | |
| Za dużo prób albo brak dostępu | | |

Teksty dokładnie takie, jakie zobaczy użytkownik. Wiersz bez zastosowania: „nie dotyczy: powód”.

### Reguły biznesowe

- R1: …

### Poza zakresem

Czego ta funkcja nie robi, prostym językiem (np. „bez załączników”, „bez zapisu wiadomości w panelu”).

- …

### Do potwierdzenia

Założenia modelu („zdecyduj sam” albo luka rozstrzygnięta bez pytania). Każdy wiersz trafia też do
zbiorczej listy „Do potwierdzenia” w specyfikacji i do „Decyzji do rejestru” w opisie PR.

| Nr | Pytanie albo założenie | Proponowana odpowiedź | Status |
|---|---|---|---|
| Z1 | | | do potwierdzenia |

## Dla wykonawcy

### Wejście

Rola, punkt wejścia (trasa, element nawigacji) i stan początkowy.

### Pola i walidacja

| Pole | Kierunek | Typ i format | Wymagane | Limit i walidacja | Komunikat błędu |
|---|---|---|---|---|---|

Gdzie trafiają dane (baza, e-mail, usługa), retencja i czy to dane osobowe.

### Odpowiedzi i błędy

| Sytuacja | Kod odpowiedzi | Stan ekranu z części dla właściciela | Log (bez danych osobowych) |
|---|---|---|---|

### Dostępność

Fokus, komunikaty dla czytnika ekranu (aria-live, aria-describedby), obsługa klawiaturą, kontrast,
działanie bez JavaScriptu.

### Przypadki brzegowe

- Podwójne kliknięcie, wolna sieć i timeout, powrót „wstecz”, odświeżenie w trakcie
- Wartości graniczne (puste, maksymalne, znaki specjalne, emoji)

### Kryteria akceptacji

Identyfikatory `W-NN/K1`, `W-NN/K2`, … przywołują zadania (`sh-plan`) i review. Każde kryterium
sprawdzalne testem albo oznaczone „(ręcznie: dlaczego)”.

- W-NN/K1: Given STAN, when DZIAŁANIE, then WYNIK.

### Design i ADR

Krok przebiegu i stan ekranu → plik i ramka w `docs/00-intake/zrodla/` albo „brak w designie” (wtedy
wiersz w „Do potwierdzenia”). ADR i decyzje, które dotyczą funkcji.
