# Dashboard projektu

Widok tylko do odczytu dla Obsidiana z wtyczką Dataview. Używa wyłącznie zapytań DQL, więc
„Enable JavaScript Queries” może zostać wyłączone. Ścieżki liczy względem tego pliku
(`this.file.folder`), więc działa w `SH/Projekty/NAZWA/docs/` i w samym repo. Niczego tu nie
edytuj: zmiana w klonie zatrzymuje synchronizację.

Źródła, wszystkie z frontmattera:

- `docs/*/DoD.md`: `etap`, `status`, `iteracja`, `akceptacja_wlasciciela`;
- `docs/07-realizacja/escalations/E-NNN.md`: `status: otwarta`, `dotyczy`, `powod`, `priorytet`,
  `data` (zapisuje `shctl escalate`);
- `docs/status.md`: liczniki zadań, `wstrzymania`, `ostatnie_decyzje`, `ostatnia_synchronizacja`
  (zapisuje `scripts/sync-status.sh`, więc dane są z chwili ostatniej synchronizacji).

## Czeka na Ciebie

Otwarte eskalacje:

```dataview
TABLE WITHOUT ID file.link AS "Eskalacja", dotyczy AS "Dotyczy", powod AS "Powód", priorytet AS "Priorytet"
WHERE startswith(file.folder, this.file.folder + "/07-realizacja/escalations") AND status = "otwarta"
SORT file.name ASC
```

Etapy w review, które po PASS czekają na Twoją akceptację:

```dataview
TABLE WITHOUT ID link(file.path, etap) AS "Etap", status AS "Status", iteracja AS "Iteracja"
WHERE file.name = "DoD" AND startswith(file.folder, this.file.folder + "/")
  AND akceptacja_wlasciciela = true AND status = "review"
SORT etap ASC
```

## Etapy

```dataview
TABLE WITHOUT ID link(file.path, etap) AS "Etap", status AS "Status", iteracja AS "Iteracja",
  choice(akceptacja_wlasciciela, "tak", "-") AS "Akceptacja właściciela"
WHERE file.name = "DoD" AND startswith(file.folder, this.file.folder + "/")
SORT etap ASC
```

## Zadania

```dataview
TABLE WITHOUT ID zadania_todo AS "todo", zadania_in_progress AS "in progress", zadania_review AS "review",
  zadania_blocked AS "blocked", zadania_escalated AS "escalated", zadania_done AS "done",
  zadania_anulowane AS "anulowane", pr_otwarte AS "PR otwarte", ci_fail AS "CI fail",
  ostatnia_synchronizacja AS "Synchronizacja"
WHERE file.folder = this.file.folder AND file.name = "status"
```

Lista zadań: [index](06-zadania/index.md).

## Wstrzymania z limitów

Brak wyników oznacza brak wstrzymań w chwili ostatniej synchronizacji.

```dataview
LIST WITHOUT ID w
WHERE file.folder = this.file.folder AND file.name = "status"
FLATTEN wstrzymania AS w
WHERE w
```

## Otwarte eskalacje

```dataview
TABLE WITHOUT ID file.link AS "Eskalacja", dotyczy AS "Dotyczy", powod AS "Powód", priorytet AS "Priorytet", data AS "Data"
WHERE startswith(file.folder, this.file.folder + "/07-realizacja/escalations") AND status = "otwarta"
SORT file.name ASC
```

## Ostatnie decyzje

Najnowsza pierwsza, z chwili ostatniej synchronizacji. Wszystkie: [decyzje](decyzje.md).

```dataview
TABLE WITHOUT ID d.data AS "Data", d.zrodlo AS "Źródło", d.pytanie AS "Pytanie", d.decyzja AS "Decyzja"
WHERE file.folder = this.file.folder AND file.name = "status"
FLATTEN ostatnie_decyzje AS d
WHERE d
```
