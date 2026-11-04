# Dane testowe skryptów

`docs/` to zamrożona kopia początkowego `docs/` szablonu: `konfiguracja.md`, `status.md`,
`decyzje.md`, `_dashboard.md`, `06-zadania/index.md` i `DoD.md` każdego etapu. Testy w
`scripts/tests/` kopiują ją do katalogu tymczasowego i tam zmieniają.

Testy nigdy nie czytają prawdziwego `docs/` repo. W projekcie zmienia je orkiestrator (status,
decyzje, DoD etapów), więc test oparty na nich zaczyna padać po pierwszej decyzji, choć kod jest
dobry (sh-dryrun#7). Pilnuje tego `dane-testowe.bats`.

Zmiana formatu pliku w `docs/` szablonu wymaga tej samej zmiany tutaj.
