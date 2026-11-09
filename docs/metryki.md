# Metryki

Plik wspólny, aktualizuje orkiestrator. Pomiar poglądowy, służy też do porównań w `sh-dryrun`.

| Zlecenie | Tryb | Czas | Zadania | Iteracje | Eskalacje | Uwagi |
|---|---|---|---|---|---|---|

Eskalacje nie liczą pytań workera (`shctl escalate --typ pytanie`): są w „Uwagach” jako „pytania: N”.

## Przyczyny uwag

Zgłoszenia review (wiersz dopisuje `shctl task close`) i QA (wiersz z raportu przepisuje orkiestrator)
według przyczyny: wymaganie, kod, test, design.

| Źródło | Wymaganie | Kod | Test | Design | Bez przyczyny |
|---|---|---|---|---|---|
