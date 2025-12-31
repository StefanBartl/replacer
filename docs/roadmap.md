# Roadmap für 'Replacer'

1. Default scope im init wird anscheinand nicht berücksichtigt
2. literal und andere optionen ssollem auch im command mitgegeben werden können
3. user config weiter ausbauen
8.  check, ob fzf lua installiert ist, dann dies benutzen, oder nur telescope, dann dies benuzen, wenn beide, dann fzf-lua
9. errormessages besser schreiben die an user gehen, so wie "wrong number of arguments" ist nicht besonders ...
10. Telescope bevorhehehe solange fzf-lua nicht korrekt highlighbar ist1
11. im idealfall würde das wort mit signalfarbe als background, viellecht orange oder rot, gehighlighted werden (im besten fall auch ncoh durchgetrichen), und das neue wort daneben in grün highlightes. DAS ist aber nur ein Bonus wenn das winfach machbar ist.Wenn das möglich ist, dann soll in
local options= require("replacer") .options
options. ext_higlight = true
gesetzt sein (oder ein besser benanntes field als ext_hoghlight, das ist mir hal dazu eingefalln)
12. Clean Code durchführen

## Table of content

  - [Features](#features)
  - [ideas](#ideas)
    - [Picker](#picker)
  - [Abwägung](#abwgung)
    - [2. Vimgrep Implementation - Analyse](#2-vimgrep-implementation-analyse)
    - [3. Feature-Bewertungen## Zusammenfassung & Empfehlungen](#3-feature-bewertungen-zusammenfassung-empfehlungen)
      - [✅ Sofort implementieren (Kritisch)](#sofort-implementieren-kritisch)
      - [✅ Nächste Priorität (High-Value)](#nchste-prioritt-high-value)
      - [⏸️ Später (Nice-to-Have)](#spter-nice-to-have)
      - [❌ Nicht empfohlen](#nicht-empfohlen)

---

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

---

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

---

### Picker

- hervorhebung des 'old' im preview window /new mit hervorhebung'

---

## Abwägung

### 2. Vimgrep Implementation - Analyse

**Umfang:** ⭐⭐⭐⭐ (4/5) - Groß

---

#### Vorteile
✅ Keine externe Abhängigkeit (ripgrep)
✅ Funktioniert überall (Windows, embedded systems)
✅ Respektiert Vim's wildignore/suffixes
✅ Nutzt Vim's native regex engine

---

#### Nachteile
❌ **Sehr langsam** bei großen Projekten (10-100x langsamer als ripgrep)
❌ Keine Parallel-Verarbeitung
❌ Kein JSON-Output → manuelles Parsing nötig
❌ Keine native Multi-Byte-UTF-8 Column-Offsets

---

#### Implementierungsaufwand---

```
lua/replacer/
├── engines/
│   ├── init.lua           # Engine registry/dispatcher
│   ├── ripgrep.lua        # Existing rg implementation (rename from rg.lua)
│   └── vimgrep.lua        # New vimgrep implementation
└── init.lua               # Updated to dispatch to engine
```

##### 1. **Vimgrep Output Parsing**

Vimgrep liefert:
```vim
:vimgrep /pattern/ **/*.lua
file.lua:45:5: line text here
```

**Keine** nativen Column-Offsets → müssen manuell berechnet werden.

**Pseudo-Code:**
```lua
function parse_vimgrep_line(line, pattern)
  -- Extract: file:lnum:col: text
  local file, lnum, col, text = line:match("^([^:]+):(%d+):(%d+):(.*)$")

  -- Find all occurrences in text (like rg.lua fallback)
  local occurrences = find_all_in_line(text, pattern, literal)

  -- Return RP_Match[] with byte offsets
end
```

##### 2. **Performance bei großen Projekten**

```lua
-- Vimgrep blockiert UI komplett
:vimgrep /pattern/ **/*.lua  -- 10-60 seconds für große Projekte

-- Lösung: Async wrapper via vim.loop
local function vimgrep_async(pattern, files, callback)
  local results = {}
  local total = #files
  local processed = 0

  for _, file in ipairs(files) do
    vim.schedule(function()
      -- Process file
      local matches = vim.fn.readfile(file)
      -- ... parse matches ...
      processed = processed + 1

      if processed == total then
        callback(results)
      end
    end)
  end
end
```

**Aber:** Auch mit Async ist es langsamer als ripgrep wegen:
- Lua/Vim-Overhead pro Zeile
- Keine nativen optimierten Regex-Scans
- Keine SIMD/Parallel-Verarbeitung

##### 3. **UTF-8 Column Offsets**

Vimgrep's `:col` ist **display column** (character-based), nicht byte-based.

**Problem:**
```lua
local line = "Müller test"
-- Vimgrep col=1 (character)
-- Byte offset=0 (M)
-- BUT: ü at char 2 = bytes 2-3
```

**Lösung:** Gleiche Strategie wie in rg.lua:
```lua
local byte_col = vim.str_byteindex(line, vimgrep_col - 1, true)
```

#### Implementierungs-Plan

##### Phase 1: Engine-Abstraktion (1-2 Tage)

    **lua/replacer/engines/init.lua:**
    ```lua
    ---@class SearchEngine
    ---@field name string
    ---@field collect fun(pattern: string, roots: string[], cfg: RP_Config): RP_Match[]

    local engines = {
      ripgrep = require("replacer.engines.ripgrep"),
      vimgrep = require("replacer.engines.vimgrep"),
    }

    function M.get_engine(name)
      return engines[name] or engines.ripgrep
    end
    ```

##### Phase 2: Vimgrep Implementierung (2-3 Tage)

    **lua/replacer/engines/vimgrep.lua:**
    ```lua
    local function collect(pattern, roots, cfg)
      -- 1. Build file list (respecting cfg.hidden, cfg.git_ignore)
      local files = build_file_list(roots, cfg)

      -- 2. Async scan files
      local results = {}
      for _, file in ipairs(files) do
        local ok, lines = pcall(vim.fn.readfile, file)
        if ok then
          for lnum, line_text in ipairs(lines) do
            local occs = find_all_in_line(line_text, pattern, cfg.literal)
            for _, occ in ipairs(occs) do
              table.insert(results, {
                id = next_id(),
                path = file,
                lnum = lnum,
                col0 = occ.byte_start,
                old = occ.text,
                line = line_text,
              })
            end
          end
        end
      end

      return results
    end
    ```

    **Aufwand-Detail:**
    - `build_file_list()`: 0.5 Tage (glob patterns, gitignore parsing)
    - `find_all_in_line()`: 0.5 Tage (regex vs literal, byte offsets)
    - `async_wrapper()`: 1 Tag (vim.schedule, chunking, progress)
    - UTF-8 handling: 0.5 Tage (integration mit vorhandenem Code)
    - Tests: 0.5 Tage

##### Phase 3: Config & Integration (1 Tag)

    **lua/replacer/config.lua:**
    ```lua
    ---@class RP_Config
    ---@field engine "ripgrep" | "vimgrep"
    ---@field vimgrep_max_files integer  -- Limit für Performance
    ---@field vimgrep_chunk_size integer -- Async chunk size
    ```

    **lua/replacer/init.lua:**
    ```lua
    function M.run(old, new_text, scope, all)
      local engine = require("replacer.engines").get_engine(M.options.engine)
      local items = engine.collect(old, roots, M.options)
      -- ... rest unchanged ...
    end
    ```

##### Phase 4: Dokumentation & Tests (1 Tag)

    - Update doc/replacer.txt
    - Health check für vimgrep
    - Benchmark tests (rg vs vimgrep)

#### Performance-Vergleich (Geschätzt)

    | Projekt-Größe | Ripgrep | Vimgrep (Sync) | Vimgrep (Async) |
    |---------------|---------|----------------|-----------------|
    | 100 Dateien   | 0.1s    | 2s             | 1.5s            |
    | 1000 Dateien  | 0.5s    | 20s            | 15s             |
    | 10k Dateien   | 2s      | 200s           | 150s            |

    **Fazit:** Vimgrep nur für kleine Projekte praktikabel (<500 Dateien).

#### Kosten/Nutzen-Analyse

##### Kosten
    - **Implementierung:** 5-7 Tage
    - **Maintenance:** Höher (mehr Code, mehr Edge-Cases)
    - **Performance:** Signifikant schlechter
    - **Tests:** Zusätzliche Test-Matrix (rg × vimgrep)

##### Nutzen
    - **Keine rg-Abhängigkeit:** Funktioniert überall
    - **Nutzergruppe:** <5% (Nutzer ohne ripgrep)
    - **Alternative:** Nutzer können ripgrep installieren (5 Minuten)

##### Empfehlung
    ⚠️ **NICHT PRIORITÄR**

    **Gründe:**
    1. 95%+ der Neovim-Power-User haben ripgrep bereits
    2. Vimgrep ist 10-100x langsamer (schlechte UX)
    3. Implementierung bindet Ressourcen (7 Tage) bei minimalem Nutzen
    4. Ripgrep-Installation ist trivial (brew/apt/choco)

    **Alternative:** Health-Check mit Install-Anleitung ausreichend.

#### Wenn dennoch implementiert

    **Minimal-Variante (2-3 Tage):**
    - Nur synchroner Vimgrep (kein Async)
    - Warning bei >100 Dateien
    - Kein Progress-Reporting
    - Basis-Funktionalität

    **Code-Sketch:**
    ```lua
    -- lua/replacer/engines/vimgrep.lua (minimal)
    local function collect(pattern, roots, cfg)
      -- Warning if too many files
      local files = vim.fn.glob(roots[1] .. "/**/*.lua", false, true)
      if #files > 100 then
        vim.notify(
          "[replacer] Vimgrep with >100 files is slow. Consider installing ripgrep.",
          vim.log.levels.WARN
        )
      end

      local results = {}
      for _, file in ipairs(files) do
        local lines = vim.fn.readfile(file)
        for lnum, line in ipairs(lines) do
          -- Simple string.find for literal
          if cfg.literal then
            local pos = 1
            while true do
              local s, e = line:find(pattern, pos, true)
              if not s then break end
              table.insert(results, {
                id = #results + 1,
                path = file,
                lnum = lnum,
                col0 = s - 1,
                old = pattern,
                line = line,
              })
              pos = e + 1
            end
          end
        end
      end

      return results
    end
    ```

    **Umfang Minimal:** 2-3 Tage total

### 3. Feature-Bewertungen## Zusammenfassung & Empfehlungen

#### ✅ Sofort implementieren (Kritisch)

1. **Help & Health** (bereits erstellt)  ✅ erledigt
   - `doc/replacer.txt` - Vollständige Vim-Hilfe
   - `lua/replacer/health.lua` - `:checkhealth replacer`

2. **Safe-Mode** (0.5 Tage)
   - Binärdateien skip
   - Dateigröße-Limit
   - Read-only Check

3. **Undo-Checkpoint** (2 Tage)
   - Git-Stash Integration
   - Buffer-State-Snapshot
   - `:ReplaceUndo` Befehl

---

#### ✅ Nächste Priorität (High-Value)

4. **Dry-Run** (2 Tage)
   - `--dry-run` Flag
   - Summary-Output
   - Patch/JSON Export

5. **Quickfix Export** (1 Tag)
   - `--to-quickfix` Flag
   - Loclist Variant

6. **File-Scopes** (3-4 Tage)
   - `--type`, `--size`, `--glob`
   - Git-Status Filter

7. **Progress** (2 Tage)
   - Async Progress-Reporting
   - fidget.nvim Integration

---

#### ⏸️ Später (Nice-to-Have)

- History & Presets
- Patch Export
- Per-File Confirmation
- Preserve-Whitespace
- Case-Preserving

---

#### ❌ Nicht empfohlen

- **Vimgrep:** 10-100x langsamer, 7 Tage Aufwand, <5% Nutzen
- **Streaming:** 4 Tage, komplex, marginaler Nutzen
- **LSP:** 5 Tage, hohe Komplexität, Scope-Creep

---

