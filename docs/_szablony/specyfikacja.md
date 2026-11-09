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

Historyjki z priorytetem (musi, powinno, może) i kryteriami Given/When/Then.

### W-1: TYTUŁ (musi)

Jako ROLA chcę DZIAŁANIE, aby CEL.

- Given STAN, when DZIAŁANIE, then WYNIK.

Wymaganie bez funkcji użytkowej (np. wydajność, SEO) ma w nagłówku „(bez karty: powód)”, np.
`### W-9: Wydajność (musi) (bez karty: wymaganie niefunkcjonalne)`.

## Karty funkcji

Każda funkcja użytkowa ma kartę `docs/00-intake/funkcje/W-N.md` (wzór `docs/_szablony/karta-funkcji.md`):
przebieg, stany ekranu, dane, reguły, przypadki brzegowe i kryteria `W-N/Kn`. Specyfikacja trzyma
historyjki, karta szczegóły.

| Wymaganie | Karta | Rodzaj (pelna, skrocona) | Ekrany z designu |
|---|---|---|---|
| W-1 | `funkcje/W-1.md` | | |

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

## Założenia do potwierdzenia

Założenia z kart („Założenia modelu”) i specyfikacji; checkpoint specyfikacji pokazuje je właścicielowi.

| Nr | Karta | Założenie | Źródło (zdecyduj sam, luka bez pytania) |
|---|---|---|---|

