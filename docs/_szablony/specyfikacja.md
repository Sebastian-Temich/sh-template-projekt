# Specyfikacja: NAZWA

Zlecenie: `docs/00-intake/zrodlo.md`. Zlecono (UTC): RRRR-MM-DDTHH:MMZ.

## Cel i kontekst

Problem, dla kogo, rezultat biznesowy, sytuacja wyjściowa.

## Użytkownicy

| Grupa | Potrzeba | Uprawnienia |
|---|---|---|

## Zakres

W zakresie:

Poza zakresem:

## Wymagania

Historyjki z priorytetem (musi, powinno, może) i kryteriami Given/When/Then. Numeracja dwucyfrowa:
W-01, W-02 … ta sama w kartach, zadaniach i kryteriach (`W-01/K1`).

### W-01: TYTUŁ (musi)

Jako ROLA chcę DZIAŁANIE, aby CEL.

- Given STAN, when DZIAŁANIE, then WYNIK.

Wymaganie bez funkcji użytkowej (np. wydajność, SEO) ma w nagłówku „(bez karty: powód)”, np.
`### W-09: Wydajność (musi) (bez karty: wymaganie niefunkcjonalne)`.

## Karty funkcji

Każda funkcja użytkowa ma kartę `docs/00-intake/funkcje/W-NN.md` (wzór `docs/_szablony/karta-funkcji.md`)
z częścią „Dla właściciela” (opis, przebieg, stany ekranu z tekstami, reguły, poza zakresem, do
potwierdzenia) i „Dla wykonawcy” (pola i walidacja, kody odpowiedzi, dostępność, kryteria `W-NN/Kn`,
design i ADR).
Specyfikacja trzyma historyjki, karta szczegóły.

| Wymaganie | Karta | Rodzaj (pelna, skrocona) | Ekrany z designu |
|---|---|---|---|
| W-01 | `funkcje/W-01.md` | | |

## Lista startowa

Rzeczy zewnętrzne od właściciela (konta, dostępy, domeny, klucze testowe, materiały):
`docs/00-intake/lista-startowa.md`. Realizacja nie startuje, dopóki lista nie jest kompletna.

## Typ projektu

Typ (web, rozszerzenie Chrome, wtyczka Office, mobile, ML, inny) i jego konsekwencje:

| Konsekwencja | Ustalenie |
|---|---|
| Narzędzia testowe | |
| Dodatkowe punkty DoD | |
| Ograniczenia runnera | |
| Kroki ręczne właściciela | |

## Stack

| | Wybór | Uzasadnienie |
|---|---|---|
| Rekomendacja | | |
| Alternatywa | | |

## Hosting

Domyślnie Vercel + Supabase Cloud (region UE) na kontach klienta.

## Design

Skąd pochodzi design, co jest ustalone i co właściciel dostarcza do `docs/00-intake/zrodla/` (przez skrzynkę).

## Kroki ręczne właściciela

## Ryzyka

| Obszar | Ocena (tak, nie, do ustalenia) | Skutek |
|---|---|---|

## Szacunek poglądowy

| Miara | Wartość |
|---|---|
| Zadania | |
| Czas kalendarzowy | |
| Czas właściciela | |

## Tryb procesu

Tryb i uzasadnienie w jednym zdaniu.

## Do potwierdzenia

Zbiorcza lista z sekcji „Do potwierdzenia” wszystkich kart i założeń specyfikacji. Checkpoint
specyfikacji pokazuje właścicielowi części „Dla właściciela” kart i tę listę.

| Nr | Karta | Pytanie albo założenie | Proponowana odpowiedź | Źródło (zdecyduj sam, luka bez pytania) |
|---|---|---|---|---|

