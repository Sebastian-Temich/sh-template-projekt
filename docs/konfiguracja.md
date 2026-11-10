---
wersja_procesu: 2
etap_wdrozenia: A
tryb_procesu: M
odbior_S: reczny
# Początek bieżącego zlecenia (UTC, np. 2026-12-01T09:00:00Z) dla „Zrobione” i postępu zadań w
# Projekt.md. Wpisuje orkiestrator przy kolejnym zleceniu M w tym projekcie; puste: od początku.
zlecenie_od: ""
# max_local: limit workerów Maca jest w /Users/Shared/sh/konfiguracja.md (domyślnie 2). Wpis tutaj
# może go tylko obniżyć dla tego projektu, np. max_local: 1.
max_review_queue: 3
min_wolne_gb: 15
# Dodatkowe pliki env (ścieżki względne w repo, bez ..) kopiowane do worktree workera obok .env.local.
# Reviewer ich nie dostaje. Przykład: [config/dev.local.json]
env_files: []
playwright_version: 1.61.1
playwright_workers: 1
# Adres stagingu dla joba qa-staging w CI (e2e i Lighthouse na gałęzi stage/08-qa); pusty: job pomija testy.
staging_url: ""
modele:
  orkiestrator: opus
  intake: opus
  architekt: opus
  zadania: opus
  worker: opus
  qa: opus
  status: opus
# Review PR i etapów: wartości wspólne są w /Users/Shared/sh/konfiguracja.md (review). Tu tylko
# nadpisanie dla projektu, pole po polu, np.:
# review:
#   zwykle: {silnik: codex, model: gpt-6-luna, effort: medium}
#   gdy_limit: drugi_silnik
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
| `wersja_procesu` | Wersja procesu SH. `2` (SH-lite F3a): etap `04-plan` zamiast `04-architektura` i `05-plan`. Brak pola to wersja 1 (projekty sprzed migracji); shctl obsługuje obie |
| `etap_wdrozenia` | `A` albo `B`. Etap A: tylko tryby S i M, tylko `runner:local` i `wykonawca:claude` |
| `tryb_procesu` | `S`, `M` albo `L` (L od etapu B). Nowy projekt zaczyna od M lub L. Proponuje `sh-intake`, akceptuje właściciel |
| `odbior_S` | Odbiór zleceń S: `reczny` (domyślnie; merge po Twoim „odbieram #NR”) albo `auto_bez_zmian_widocznych` (zlecenie z etykietą `widoczne:nie`, bez zmian widocznych dla użytkownika, merguje się po PASS i zielonym CI, a Ty dostajesz powiadomienie). Zlecenie ze zmianą widoczną zawsze czeka na Twój odbiór |
| `zlecenie_od` | Początek bieżącego zlecenia (UTC). `Projekt.md` pokazuje w „Zrobione” i w postępie zadań tylko zadania od tej chwili, a starsze są w `historia.md`. Puste: od początku projektu. Zlecenia S po zleceniu M i przebiegi dryrun (`metryki.md`) rozpoznaje `sync-status.sh` sam |
| `max_local` | Opcjonalne obniżenie limitu workerów dla projektu; limit Maca (domyślnie 2) jest w `/Users/Shared/sh/konfiguracja.md` |
| `max_review_queue` | Liczba PR czekających na review, przy której dispatch staje |
| `min_wolne_gb` | Minimum wolnego miejsca na dysku |
| `env_files` | Dodatkowe pliki env, które `shctl task dispatch` kopiuje do worktree workera obok `.env.local`. Ścieżki względne, bez `..`; tylko klucze testowe. Reviewer ich nie dostaje |
| `playwright_version` | Przypięta wersja, ostatnia z działającym WebKit na macOS 14 Intel |
| `playwright_workers` | Liczba workerów Playwright |
| `staging_url` | Adres stagingu; job `qa-staging` w CI uruchamia na nim e2e (`BASE_URL`) i Lighthouse dla PR z `stage/08-qa` |
| `modele` | Model per rola Claude. `opus` to najmocniejszy dostępny Opus. Decyzja właściciela z 2026-11-02: role Claude na `opus` (Opus 5.5). Reviewer nie jest tu wpisany: patrz `review` |
| `review` | Opcjonalne nadpisanie silnika review dla projektu (`zwykle`, `ryzyko`: `silnik` `claude` albo `codex`, `model`, `effort`; `gdy_limit`: `czekaj` albo `drugi_silnik`). Bez wpisu obowiązuje `/Users/Shared/sh/konfiguracja.md`. Stare `modele.reviewer` shctl pomija (SH-lite F6) |
| `hosting` | Proponuje intake, akceptuje właściciel (`zaakceptowany: true`). Domyślnie Vercel + Supabase Cloud (UE) na kontach klienta |
