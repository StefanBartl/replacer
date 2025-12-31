# Roadmap für 'Replacer'

- eine doc/replacer.txt file für dasd´nvim :h help
- Health-Module to provide :checkhealth


-weitrhin das Problem, dass sehr oft relacements nicht durchgeführt werden nachdem sie selektiert wurden im picker, mit folgender Meldung:
  Warn  10:23:40 notify.warn [replacer] skip changed spot: C:\Users\Bernhard\AppData\Local\nvim\lua\lib\hover_select\highlight.lua:45:5
  Warn  10:23:40 notify.warn [replacer] skip changed spot: C:\Users\Bernhard\AppData\Local\nvim\lua\lib\hover_select\highlight.lua:42:5
  Warn  10:23:40 notify.warn [replacer] skip changed spot: C:\Users\Bernhard\AppData\Local\nvim\lua\lib\hover_select\highlight.lua:33:5
  Warn  10:23:40 notify.warn [replacer] skip changed spot: C:\Users\Bernhard\AppData\Local\nvim\lua\lib\hover_select\highlight.lua:30:5
  Info  10:23:40 notify.info [replacer] 0 spot(s) in 1 file(s)

leider nicht mehr infos. Es wäre spannend zu wissen, warum das ausftaucht. manchmal ist es gar nicht, manchmal kann ich 20 hintereinander nicht durchführen deswegen.



## Genau ausarbeiten

* vimgrep iplementierunfg einen vorteil hätte. mindestens jedenalls für jenmde die riügrep nicht installert haben, das werden aber eher weniges ein, denn die meitsen die nvim replace plugin nutzen werden, werden devs sein und da ist rg weit verbreitete. aber aonsonsten: gibt es da vorttiele,  nachteile? wie umfangreich  wäre eine Implementierung, wo müsste was eratellt werden? Kurzen überblick ausarbeiten.

## Features

Einschätzung des Umfangs, "Kosten"/Nutzen, Auswirmugn auf Performance:

* File-Scopes & Filter für die prompt
Zusätzliche Filter: `--type`/Filetypes, Globs,V Pfadmuster, Größenlimit, geänderte Dateien (git-status), Exclude-Listen.

* History & Presets
Verlauf der letzten Suchen/Ersetzungen, benannte Presets, Re-Run per Picker.

* Plan/Review ohne Apply
„Dry-Run“ mit Statistik (Treffer gesamt/Dateien), exportierbar als Patch/JSON.

* Quickfix/Loclist-Export
Trefferliste in Quickfix/Lokalliste übertragen für alternative Workflows (`:cfdo`, eigene Macros).

* Per-File-Bestätigung
„All“ mit Zwischenschritt je Datei (A-alle in Datei, S-skip Datei, O-nur einzelne Hunks). Per arg im usercommand anfordern.

* Undo-Checkpoint
Vor Apply automatisch `:write`/Swap-Checkpoint/Git-Stash oder temporärer Branch; One-Click-Rollback.

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

## ideas

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

 Monorepo-/Root-Erkennung
  Automatische Root-Bestimmung (git, package.json, go.mod, pylintrc …), optional Auswahl bei Mehrfach-Roots.

* Nur-Changed-Modus
  Ersetze nur in „changed“/„staged“/„unstaged“/„untracked“ Dateien (git-integriert).

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


* i18n/Meldungen
  Mehrsprachige Meldungen, konfigurierbare Prompts/Bestätigungen, stille/verbose Modi.

### Picker

- hervorhebung des 'old' im preview window /new mit hervorhebung'
