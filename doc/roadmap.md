# Roadmap für 'Replacer'

<<<<<<< Updated upstream
1. mehrmalige vorkommen innerhalb einer Zeile mpssen kebenfalls replaced werden fc
2. literal und andere optionen ssollem auch im command mitgegeben werden können
3. user config weiter ausbauen
4. Nichtn ur rigrep, sondern auch vimgrep sollte verwendbar sein
5. Comments lectures
6. :h
7. github repo detaillierter mit infos versorgen
8.  check, ob fzf lua installiert ist, dann dies benutzen, oder nur telescope, dann dies benuzen, wenn beide, dann fzf-lua
9. errormessages besser schreiben die an user gehen, so wie "wrong number of arguments" ist nicht besonders ...
=======
- :h
- github repo detaillierter mit infos versorgen
- Range erlauben

- Zusätzliche Funktion, die neben dem Source Code auch Änderungen von Dateinamen und Ordnern möglich macht
    - Eigener Picker nur mit Dateinamen/Ordnern
    - Gemeinsamen Picker, indem Source Code und Dateinamen (speziell highlighted) aufgelistet werden
    - Änderung wird auf importe/exporte angewandt
>>>>>>> Stashed changes

## Features

* Diff-Preview vor/nach
  Zeigt im Picker eine zweispaltige Diff-Vorschau je Treffer, optional umschaltbar.

* Case-Preserving Replace
  Passt die Groß-/Kleinschreibung des Ersatztextes an das jeweilige Match an (z. B. foo→bar, Foo→Bar).

* Wortgrenzen/Token-Modus
  „Ganzes Wort“, Wortgrenzen, oder nur Identifiers; optional Tree-sitter-gestützt (keine Treffer in Strings/Comments).

* Regex-Modus mit Hilfen
  Umschalter „literal/regex“, Escaping-Helfer, Test-Panel für Pattern, Backreferences im Replacement.

* Batch-Replaces
  Mehrere {old→new}-Paare in einem Lauf; aus Datei/Quickfix/Clipboard importierbar.

* File-Scopes & Filter
  Zusätzliche Filter: `--type`/Filetypes, Globs, Pfadmuster, Größenlimit, geänderte Dateien (git-status), Exclude-Listen.

* Monorepo-/Root-Erkennung
  Automatische Root-Bestimmung (git, package.json, go.mod, pylintrc …), optional Auswahl bei Mehrfach-Roots.

* Nur-Changed-Modus
  Ersetze nur in „changed“/„staged“/„unstaged“/„untracked“ Dateien (git-integriert).

* History & Presets
  Verlauf der letzten Suchen/Ersetzungen, benannte Presets, Re-Run per Picker.

* Plan/Review ohne Apply
  „Dry-Run“ mit Statistik (Treffer gesamt/Dateien), exportierbar als Patch/JSON.

* Quickfix/Loclist-Export
  Trefferliste in Quickfix/Lokalliste übertragen für alternative Workflows (`:cfdo`, eigene Macros).

* Per-File-Bestätigung
  „All“ mit Zwischenschritt je Datei (A-alle in Datei, S-skip Datei, O-nur einzelne Hunks).

* Undo-Checkpoint
  Vor Apply automatisch `:write`/Swap-Checkpoint/Git-Stash oder temporärer Branch; One-Click-Rollback.

* LSP-Integration (sanft)
  Optional: LSP-Rename anbieten, wenn Symbol exakt getroffen; sonst auf Text-Replace fallen.

* Encoding/Line-Endings
  Erkennung/Normalisierung von BOM/CRLF/LF; Option, Line-Endings beizubehalten.

* Streaming-Suche
  rg-Output streamen und den Picker „live“ füllen; früh selektieren, während die Suche weiterläuft.

* Preview-Highlighting
  Syntax/Tree-sitter-Highlight im Preview, Markierung der Match-Region; Umschalten Kontextzeilen.

* Hook-System
  Vor/Nach-Hooks (Lua-Callbacks) je Datei oder global: Linter/Formatter ausführen, Cache invalidieren, etc.

* Status/Progress
  Fortschrittsanzeige (Dateien/Treffer), Timer, Throughput; Integration in Statusline/Picker-Header.

* Preserves-Whitespace Option
  Ersetzt nur den Token, lässt umliegende Whitespace/Formatierung unberührt (nützlich bei Code-Refactors).

* Safe-Mode: Nur lesbare Dateien
  Skips für Binärdateien, große Dateien, schreibgeschützte Pfade; konfigurierbare Grenzen.

* Patch-Export
  Änderungen als `.patch`/`diff` ausgeben, zum späteren Einspielen oder Code-Review.

* Rename-Assist
  Kombiniert Content-Replace mit optionalem Dateiumbenennen (z. B. Klassennamen ↔ Dateiname), mit Preview.

* i18n/Meldungen
  Mehrsprachige Meldungen, konfigurierbare Prompts/Bestätigungen, stille/verbose Modi.

### Picker

- hervorhebung des 'old' im preview window /new mit hervorhebung'
