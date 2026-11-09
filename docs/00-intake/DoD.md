---
etap: 00-intake
status: todo
iteracja: 0
akceptacja_wlasciciela: true
---

# DoD: Specyfikacja

## Dokumentacja

- [ ] `specyfikacja.md` ma cel i kontekst, użytkowników, zakres, wymagania, typ projektu, stack, hosting, notatkę o designie, ryzyka i szacunek poglądowy
- [ ] `zrodlo.md` zawiera pierwotne zlecenie
- [ ] Każda funkcja użytkowa ma kartę `funkcje/W-NN.md` bez otwartych luk (`[?]`, `?`, TODO); `scripts/check-dod.sh` sprawdza sekcje
- [ ] `lista-startowa.md` wymienia wszystko zewnętrzne od właściciela, z instrukcją przy każdej pozycji
<!-- tylko-tryb:L -->
- [ ] `intake.md` powstał
- [ ] `tech-proposal.md` powstał
- [ ] `narzedzia.md` powstał
- [ ] `wycena.md` powstała
<!-- /tylko-tryb -->

## Funkcjonalność

- [ ] Typ projektu jest rozpoznany (web, rozszerzenie Chrome, wtyczka Office, mobile, ML, inny)
- [ ] Każde wymaganie to historyjka z priorytetem i kryteriami Given/When/Then
- [ ] Kroki przebiegu kart są zmapowane na ekrany designu, a brakujące stany ekranu mają odpowiedź albo założenie
- [ ] Stack ma rekomendację, alternatywę i uzasadnienie

## Checklisty jakości

- [ ] Tryb procesu jest zapisany w `konfiguracja.md` z uzasadnieniem w jednym zdaniu
- [ ] Obszary ryzyka są ocenione; każdy na `tak` albo `do ustalenia` ma w specyfikacji „ADR w 04-plan” (ADR pisze sh-plan, nie intake)
- [ ] Kroki ręczne właściciela są wypisane
- [ ] Karty mają części „Dla właściciela” (prosty język, bez kodów i atrybutów) i „Dla wykonawcy”; numeracja W-01, W-02 …
- [ ] Zbiorcza lista „Do potwierdzenia” w specyfikacji zbiera wiersze z kart; każdy jest w „Decyzjach do rejestru” PR
- [ ] Hosting jest zapisany w `konfiguracja.md`

## Checkpoint

- [ ] Review etapu dało PASS (zaznacza reviewer, nie autor)
- [ ] Właściciel zaakceptował specyfikację
