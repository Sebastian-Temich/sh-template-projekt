# Dashboard projektu

Widok tylko do odczytu dla Obsidiana z wtyczką Dataview (w ustawieniach włączone „Enable JavaScript
Queries”). Ścieżki liczy względem tego pliku, więc działa w `SH/Projekty/NAZWA/docs/` i w samym repo.
Niczego tu nie edytuj: zmiana w klonie zatrzymuje synchronizację.

Źródła: frontmatter `docs/*/DoD.md` (`etap`, `status`, `iteracja`, `akceptacja_wlasciciela`),
frontmatter `docs/status.md` (liczniki i `wstrzymania` z `scripts/sync-status.sh`), frontmatter
`docs/07-realizacja/escalations/E-NNN.md` (`status: otwarta`, zapisuje `shctl escalate`),
tabela `docs/decyzje.md`.

## Czeka na Ciebie

```dataviewjs
const docs = dv.current().file.folder;
const esk = dv.pages(`"${docs}/07-realizacja/escalations"`)
  .where(p => p.status === "otwarta")
  .sort(p => p.file.name, "asc");
const etapy = dv.pages(`"${docs}"`)
  .where(p => p.file.name === "DoD" && p.akceptacja_wlasciciela === true && p.status === "review")
  .sort(p => p.etap, "asc");
const pozycje = [
  ...esk.map(p => `Eskalacja ${p.file.link} (${p.dotyczy ?? "-"}, ${p.priorytet ?? "-"}): ${p.powod ?? ""}`),
  ...etapy.map(p => `Etap ${p.file.link} \`${p.etap}\` w review: po PASS czeka na Twoją akceptację`),
];
if (pozycje.length) dv.list(pozycje); else dv.paragraph("Nic nie czeka.");
```

## Etapy

```dataviewjs
const docs = dv.current().file.folder;
const etapy = dv.pages(`"${docs}"`)
  .where(p => p.file.name === "DoD" && p.etap)
  .sort(p => p.etap, "asc");
dv.table(["Etap", "Status", "Iteracja", "Akceptacja właściciela"],
  etapy.map(p => [p.file.link, p.status, p.iteracja, p.akceptacja_wlasciciela ? "tak" : "-"]));
```

## Zadania

```dataviewjs
const s = dv.page(`${dv.current().file.folder}/status`);
if (!s) { dv.paragraph("Brak `status.md`."); } else {
  const n = k => s[k] ?? 0;
  dv.table(["todo", "in progress", "review", "blocked", "escalated", "done", "anulowane", "PR otwarte", "CI fail"],
    [[n("zadania_todo"), n("zadania_in_progress"), n("zadania_review"), n("zadania_blocked"),
      n("zadania_escalated"), n("zadania_done"), n("zadania_anulowane"), n("pr_otwarte"), n("ci_fail")]]);
  dv.paragraph(`Ostatnia synchronizacja: ${s.ostatnia_synchronizacja ?? "brak"}. Lista zadań: ${dv.fileLink(`${dv.current().file.folder}/06-zadania/index.md`, false, "index")}.`);
}
```

## Wstrzymania z limitów

```dataviewjs
const s = dv.page(`${dv.current().file.folder}/status`);
const w = s?.wstrzymania ? Array.from(s.wstrzymania) : [];
if (w.length) dv.list(w); else dv.paragraph("Brak wstrzymań.");
dv.paragraph(`Stan z synchronizacji: ${s?.ostatnia_synchronizacja ?? "brak"}.`);
```

## Otwarte eskalacje

```dataviewjs
const esk = dv.pages(`"${dv.current().file.folder}/07-realizacja/escalations"`)
  .where(p => p.status === "otwarta")
  .sort(p => p.file.name, "asc");
if (esk.length) {
  dv.table(["Eskalacja", "Dotyczy", "Powód", "Priorytet", "Data"],
    esk.map(p => [p.file.link, p.dotyczy, p.powod, p.priorytet, p.data]));
} else dv.paragraph("Brak otwartych eskalacji.");
```

## Ostatnie decyzje

```dataviewjs
const ILE = 5;
const tekst = await dv.io.load(`${dv.current().file.folder}/decyzje.md`);
const wiersze = (tekst ?? "").split("\n")
  .filter(l => l.startsWith("| ") && !/^\|[- |:]*$/.test(l) && !l.startsWith("| Data |"))
  .map(l => l.trim().replace(/^\|/, "").replace(/\|$/, "")
    .split(/(?<!\\)\|/).map(c => c.trim().replace(/\\\|/g, "|")));
if (wiersze.length) {
  dv.table(["Data", "Źródło", "Pytanie", "Decyzja"], wiersze.slice(-ILE).reverse());
} else dv.paragraph("Brak decyzji.");
dv.paragraph(`Wszystkie: ${dv.fileLink(`${dv.current().file.folder}/decyzje.md`, false, "decyzje")}.`);
```
