---
etap: 04-plan
status: todo
iteracja: 0
akceptacja_wlasciciela: true
---

# DoD: Plan

Jeden dokument `plan.md`: krótka architektura i plan kamieni milowych (szablon `docs/_szablony/plan.md`).

## Dokumentacja

- [ ] `plan.md` ma krótką architekturę: moduły, model danych, bezpieczeństwo, środowiska
- [ ] `plan.md` ma kamienie milowe jako pionowe przekroje
- [ ] `plan.md` ma 5–10 scenariuszy odbioru, zakres autoryzacji i jeden następny krok
- [ ] Ważne decyzje i obszary ryzyka mają ADR w `adr/`
- [ ] Sekcja „Stack (kontrakt)” w `AGENTS.md` jest uzupełniona

## Funkcjonalność

- [ ] Każde wymaganie ze specyfikacji ma kamień milowy
- [ ] Każda funkcja ma wskazany punkt wejścia (strona, trasa, komenda, endpoint)
- [ ] Pierwszy kamień zaczyna się od szkieletu projektu, ostatni kończy dokumentacją wydania

## Checklisty jakości

- [ ] Migracje zgodne wstecz są zasadą modelu danych
- [ ] Zadania właściciela są w planie: konta prod i staging, DNS, `STAGING_DB_URL`, zmienne prod w Vercel oraz kroki typu projektu

## Checkpoint

- [ ] Review etapu dało PASS (zaznacza reviewer, nie autor)
- [ ] Właściciel zaakceptował plan
<!-- tylko-tryb:L -->
- [ ] Checkpoint 1 zaliczony
<!-- /tylko-tryb -->
