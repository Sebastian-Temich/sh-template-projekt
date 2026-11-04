---
etap_wdrozenia: A
tryb_procesu: M
auto_merge_S: false
# max_local: limit workerów Maca jest w /Users/Shared/sh/konfiguracja.md (domyślnie 2). Wpis tutaj
# może go tylko obniżyć dla tego projektu, np. max_local: 1.
max_review_queue: 3
min_wolne_gb: 15
# Dodatkowe pliki env (ścieżki względne w repo, bez ..) kopiowane do worktree workera obok .env.local.
# Reviewer ich nie dostaje. Przykład: [config/dev.local.json]
env_files: []
playwright_version: 1.61.1
playwright_workers: 1
modele:
  orkiestrator: opus
  intake: opus
  architekt: opus
  zadania: opus
  worker: opus
  qa: opus
  status: opus
  reviewer:
    narzedzie: codex
    model: GPT-6-Astra
    rozumowanie: high
hosting:
  aplikacja: vercel
  baza: supabase-cloud
  region: eu
  konta: klient
  zaakceptowany: false
---

# Konfiguracja projektu

Źródłem wartości jest frontmatter powyżej. Czytają go shctl i `scripts/check-dod.sh`.

| Pole | Znaczenie |
|---|---|
| `etap_wdrozenia` | `A` albo `B`. Etap A: tylko tryby S i M, tylko `runner:local` i `wykonawca:claude` |
| `tryb_procesu` | `S`, `M` albo `L` (L od etapu B). Nowy projekt zaczyna od M lub L. Proponuje `sh-intake`, akceptuje właściciel |
| `auto_merge_S` | Czy orkiestrator merguje zlecenia S sam. Włączamy po kilku udanych zleceniach S |
| `max_local` | Opcjonalne obniżenie limitu workerów dla projektu; limit Maca (domyślnie 2) jest w `/Users/Shared/sh/konfiguracja.md` |
| `max_review_queue` | Liczba PR czekających na review, przy której dispatch staje |
| `min_wolne_gb` | Minimum wolnego miejsca na dysku |
| `env_files` | Dodatkowe pliki env, które `shctl task dispatch` kopiuje do worktree workera obok `.env.local`. Ścieżki względne, bez `..`; tylko klucze testowe. Reviewer ich nie dostaje |
| `playwright_version` | Przypięta wersja, ostatnia z działającym WebKit na macOS 14 Intel |
| `playwright_workers` | Liczba workerów Playwright |
| `modele` | Model per rola. `opus` to najmocniejszy dostępny Opus. Model reviewera wybiera właściciel; `domyslny` oznacza model z konfiguracji Codex. Decyzja właściciela z 2026-11-02: role Claude na `opus` (Opus 5.5), reviewer Codex na GPT-6-Astra (najmocniejszy model Codexa) z rozumowaniem `high` |
| `hosting` | Proponuje intake, akceptuje właściciel (`zaakceptowany: true`). Domyślnie Vercel + Supabase Cloud (UE) na kontach klienta |
