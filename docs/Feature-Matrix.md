# Replacer Feature Implementation Matrix

## Bewertungskriterien
- **Umfang:** ⭐ (1 Tag) bis ⭐⭐⭐⭐⭐ (>10 Tage)
- **Nutzen:** 🔥 (gering) bis 🔥🔥🔥🔥🔥 (hoch)
- **Performance-Impact:** ⚡ (neutral) bis ⚡⚡⚡⚡⚡ (kritisch)
- **Priorität:** 🅰️ (must-have) 🅱️ (should-have) 🅲️ (nice-to-have) 🅳️ (maybe)

---

## Kategorie: Core Features

### 1. File-Scopes & Filter

**Umfang:** ⭐⭐⭐ (3-4 Tage)
**Nutzen:** 🔥🔥🔥🔥 (sehr hoch)
**Performance:** ⚡⚡ (moderate Auswirkung)
**Priorität:** 🅱️ SHOULD-HAVE

**Beschreibung:**
Erweiterte Filterung beim Replace-Aufruf:
```vim
:Replace pattern new cwd --type lua --size <1M --exclude test/
:Replace pattern new . --git-status modified,staged
:Replace pattern new . --glob "src/**/*.ts" --exclude "*.spec.ts"
```

**Implementierung:**
```lua
-- lua/replacer/command.lua
---@class RP_Filters
---@field filetypes string[]|nil     -- e.g. {"lua", "ts"}
---@field max_size integer|nil       -- in bytes
---@field globs string[]|nil         -- e.g. {"src/**/*.lua"}
---@field excludes string[]|nil      -- e.g. {"test/", "*.spec.lua"}
---@field git_status string[]|nil    -- e.g. {"modified", "staged"}

-- Parse from args
local function parse_filters(args)
  -- :Replace old new . --type lua,ts --size <1M
  local filters = {}
  for i = 4, #args do
    if args[i] == "--type" then
      filters.filetypes = vim.split(args[i+1], ",")
    elseif args[i] == "--size" then
      filters.max_size = parse_size(args[i+1])
    -- ... etc
  end
  return filters
end

-- Apply in rg.lua
local function apply_filters(files, filters)
  if filters.max_size then
    files = vim.tbl_filter(function(f)
      return vim.fn.getfsize(f) <= filters.max_size
    end, files)
  end
  -- ... more filters
  return files
end
```

**Aufwand-Detail:**
- Argument Parsing: 0.5 Tage
- Ripgrep `--type` Integration: 0.5 Tage
- Git-Status Filter (via `git status --porcelain`): 1 Tag
- Glob/Exclude Patterns: 1 Tag
- Tests & Docs: 1 Tag

**Performance-Impact:**
- Git-Status-Check: +50-200ms (einmalig)
- Glob-Matching: +10-50ms pro 1000 Dateien
- Gesamt: Akzeptabel

---

### 2. History & Presets

**Umfang:** ⭐⭐⭐ (3-4 Tage)
**Nutzen:** 🔥🔥🔥 (hoch)
**Performance:** ⚡ (neutral)
**Priorität:** 🅱️ SHOULD-HAVE

**Beschreibung:**
```vim
" History
:ReplaceHistory         " Picker mit letzten 50 Replacements
<CR> auf Eintrag        " Re-run mit gleichen Parametern

" Presets
:ReplaceSavePreset refactor_imports old="import X" new="import Y" scope=src/
:ReplacePreset refactor_imports
```

**Implementierung:**
```lua
-- lua/replacer/history.lua
local M = {}
local history_file = vim.fn.stdpath("data") .. "/replacer_history.json"

---@class RP_HistoryEntry
---@field timestamp number
---@field old string
---@field new string
---@field scope string
---@field files_changed integer
---@field spots_changed integer

function M.add(entry)
  local history = M.load()
  table.insert(history, 1, entry)
  -- Keep last 50
  if #history > 50 then
    table.remove(history)
  end
  M.save(history)
end

function M.load()
  local ok, data = pcall(vim.fn.readfile, history_file)
  if not ok then return {} end
  return vim.json.decode(table.concat(data))
end

-- Picker integration
function M.show_picker()
  local history = M.load()
  -- Format for telescope/fzf
  local entries = vim.tbl_map(function(e)
    return string.format(
      "%s | %s → %s | %d files | %s",
      os.date("%Y-%m-%d %H:%M", e.timestamp),
      e.old:sub(1, 20),
      e.new:sub(1, 20),
      e.files_changed,
      e.scope
    )
  end, history)

  -- Show in picker, on select: re-run
end
```

**Presets:**
```lua
-- lua/replacer/presets.lua
local presets_file = vim.fn.stdpath("data") .. "/replacer_presets.json"

---@class RP_Preset
---@field name string
---@field old string
---@field new string
---@field scope string
---@field filters RP_Filters|nil

function M.save_preset(name, config)
  -- Store preset
end

function M.run_preset(name)
  local preset = M.load_preset(name)
  require("replacer").run(preset.old, preset.new, preset.scope, false)
end
```

**Aufwand:**
- History Storage: 1 Tag
- History Picker UI: 1 Tag
- Presets Storage & Commands: 1 Tag
- Tests & Docs: 1 Tag

**Performance:** Keine, Disk-IO minimal (<10ms)

---

### 3. Plan/Review ohne Apply (Dry-Run)

**Umfang:** ⭐⭐ (2 Tage)
**Nutzen:** 🔥🔥🔥🔥 (sehr hoch)
**Performance:** ⚡ (neutral)
**Priorität:** 🅱️ SHOULD-HAVE

**Beschreibung:**
```vim
:Replace pattern new . --dry-run
" Zeigt:
" - 145 matches across 23 files
" - Grouped by file with counts
" - Export as patch/JSON
```

**Implementierung:**
```lua
-- In command.lua: detect --dry-run flag
function M.run(old, new_text, scope, all, opts)
  if opts.dry_run then
    return run_dry_run(old, new_text, scope)
  end
  -- ... normal flow
end

function run_dry_run(old, new_text, scope)
  local roots, _ = resolve_scope(scope)
  local items = RG.collect(old, roots, M.options)

  -- Group by file
  local by_file = {}
  for _, it in ipairs(items) do
    by_file[it.path] = (by_file[it.path] or 0) + 1
  end

  -- Show summary
  print("Dry Run Results:")
  print(string.format("  Total: %d matches in %d files", #items, vim.tbl_count(by_file)))
  print("\nBy File:")
  for path, count in pairs(by_file) do
    print(string.format("  %3d  %s", count, vim.fn.fnamemodify(path, ":.")))
  end

  -- Offer export
  local choice = vim.fn.confirm("Export results?", "&Patch\n&JSON\n&Cancel", 3)
  if choice == 1 then
    export_patch(items, new_text)
  elseif choice == 2 then
    export_json(items)
  end
end
```

**Aufwand:**
- Dry-Run Logic: 0.5 Tage
- Summary Formatting: 0.5 Tage
- Patch Export: 0.5 Tage (unified diff format)
- JSON Export: 0.25 Tage
- Tests: 0.25 Tage

---

### 4. Quickfix/Loclist Export

**Umfang:** ⭐ (1 Tag)
**Nutzen:** 🔥🔥🔥 (hoch)
**Performance:** ⚡ (neutral)
**Priorität:** 🅱️ SHOULD-HAVE

**Beschreibung:**
```vim
:Replace pattern new . --to-quickfix
" Sendet Matches in Quickfix-Liste
:copen  " Zeigt Treffer
:cfdo %s/old/new/g | w  " Apply via Vim-Makro
```

**Implementierung:**
```lua
function export_to_quickfix(items)
  local qf_list = vim.tbl_map(function(it)
    return {
      filename = it.path,
      lnum = it.lnum,
      col = it.col0 + 1,  -- 1-based
      text = it.line,
      type = "I",  -- Info
    }
  end, items)

  vim.fn.setqflist(qf_list, "r")
  vim.cmd("copen")
  vim.notify(string.format("[replacer] Sent %d matches to quickfix", #items))
end
```

**Aufwand:** 1 Tag (inkl. loclist variant + docs)

---

### 5. Per-File-Bestätigung

**Umfang:** ⭐⭐ (2 Tage)
**Nutzen:** 🔥🔥🔥 (hoch)
**Performance:** ⚡ (neutral)
**Priorität:** 🅲️ NICE-TO-HAVE

**Beschreibung:**
```vim
:Replace pattern new . --confirm-per-file
" For each file:
"   file.lua (12 matches)
"   [A]ll | [S]kip | [O]nly selected | [Q]uit
```

**Implementierung:**
```lua
function apply_with_file_confirmation(items, new_text, cfg)
  local by_file = group_by_file(items)

  for path, file_items in pairs(by_file) do
    local rel = vim.fn.fnamemodify(path, ":.")
    local choice = vim.fn.confirm(
      string.format("%s (%d matches)", rel, #file_items),
      "&All\n&Skip\n&Only selected\n&Quit",
      1
    )

    if choice == 1 then  -- All
      Apply.apply(file_items, new_text, cfg.write_changes)
    elseif choice == 3 then  -- Only selected
      -- Show picker with only this file's matches
      show_picker_for_file(file_items, new_text, cfg)
    elseif choice == 4 then  -- Quit
      break
    end
    -- choice == 2: Skip, continue to next file
  end
end
```

**Aufwand:** 2 Tage

---

### 6. Undo-Checkpoint

**Umfang:** ⭐⭐ (2 Tage)
**Nutzen:** 🔥🔥🔥🔥🔥 (kritisch)
**Performance:** ⚡⚡ (moderate)
**Priorität:** 🅰️ MUST-HAVE

**Beschreibung:**
```vim
:Replace pattern new . --checkpoint
" Before apply:
" - Creates git stash or
" - Saves buffer states or
" - Creates temp branch
:ReplaceUndo  " Rollback last operation
```

**Implementierung:**
```lua
-- lua/replacer/checkpoint.lua
local M = {}

function M.create(strategy)
  if strategy == "git-stash" then
    vim.fn.system("git stash push -m 'replacer checkpoint'")
  elseif strategy == "buffer-snapshot" then
    -- Save undo history per buffer
    M.save_buffer_states()
  elseif strategy == "git-branch" then
    local branch = "replacer-backup-" .. os.time()
    vim.fn.system("git checkout -b " .. branch)
  end
end

function M.rollback(strategy)
  if strategy == "git-stash" then
    vim.fn.system("git stash pop")
  -- ... etc
end
```

**Aufwand:** 2 Tage (Git integration, Buffer-State persistence)

---

## Kategorie: UI/UX Features

### 7. Status/Progress

**Umfang:** ⭐⭐ (2 Tage)
**Nutzen:** 🔥🔥🔥 (hoch)
**Performance:** ⚡⚡ (moderate - muss async sein)
**Priorität:** 🅱️ SHOULD-HAVE

**Beschreibung:**
```vim
" During search:
Replacer: Scanning 1234/5000 files (24%)...
" During apply:
Replacer: Applying 45/145 matches (31%)...
```

**Implementierung:**
```lua
-- lua/replacer/progress.lua
local M = {}

function M.show(message, progress)
  -- Option 1: fidget.nvim integration
  local ok, fidget = pcall(require, "fidget")
  if ok then
    fidget.notify(message, nil, { percentage = progress })
  else
    -- Option 2: vim.notify with title
    vim.notify(string.format("%s (%d%%)", message, progress), vim.log.levels.INFO)
  end
end

-- In rg.lua: add progress callbacks
function collect_with_progress(pattern, roots, cfg)
  local total_files = #roots
  local processed = 0

  -- ... async file processing ...

  if processed % 100 == 0 then
    M.show("Scanning files", math.floor(processed / total_files * 100))
  end
end
```

**Aufwand:** 2 Tage (async integration, fidget.nvim compat)

---

### 8. Preserves-Whitespace Option

**Umfang:** ⭐ (1 Tag)
**Nutzen:** 🔥🔥 (mittel)
**Performance:** ⚡ (neutral)
**Priorität:** 🅲️ NICE-TO-HAVE

**Beschreibung:**
```lua
-- Before:
"  function old()"
-- After (normal):
"  function new()"
-- After (preserve-ws):
"  function new()"  -- same indentation
```

**Implementierung:**
```lua
-- In apply.lua
if cfg.preserve_whitespace then
  -- Extract leading/trailing whitespace from old match
  local leading = it.old:match("^(%s*)")
  local trailing = it.old:match("(%s*)$")
  local trimmed_old = vim.trim(it.old)

  -- Apply to new text
  local new_with_ws = leading .. new_text .. trailing
  vim.api.nvim_buf_set_text(bufnr, row, s, row, e, { new_with_ws })
else
  -- Normal replace
end
```

**Aufwand:** 1 Tag

---

### 9. Safe-Mode: Nur lesbare Dateien

**Umfang:** ⭐ (0.5 Tage)
**Nutzen:** 🔥🔥🔥🔥 (sehr hoch - Sicherheit)
**Performance:** ⚡ (neutral)
**Priorität:** 🅰️ MUST-HAVE

**Implementierung:**
```lua
-- In config.lua
---@class RP_Config
---@field safe_mode boolean
---@field max_file_size integer  -- bytes, default 5MB
---@field skip_binary boolean    -- default true

-- In apply.lua
function apply(items, new_text, cfg)
  for path, list in pairs(by_path) do
    -- Check file permissions
    if vim.fn.filewritable(path) == 0 then
      vim.notify(string.format("Skip (read-only): %s", path), vim.log.levels.WARN)
      goto next_file
    end

    -- Check file size
    if vim.fn.getfsize(path) > cfg.max_file_size then
      vim.notify(string.format("Skip (too large): %s", path), vim.log.levels.WARN)
      goto next_file
    end

    -- Check binary
    if cfg.skip_binary and is_binary(path) then
      vim.notify(string.format("Skip (binary): %s", path), vim.log.levels.WARN)
      goto next_file
    end

    -- ... proceed with apply
    ::next_file::
  end
end

function is_binary(path)
  local fd = io.open(path, "rb")
  if not fd then return false end
  local chunk = fd:read(512)
  fd:close()
  return chunk:find("\0") ~= nil  -- NULL byte = binary
end
```

**Aufwand:** 0.5 Tage

---

### 10. Patch-Export

**Umfang:** ⭐⭐ (1.5 Tage)
**Nutzen:** 🔥🔥🔥 (hoch)
**Performance:** ⚡ (neutral)
**Priorität:** 🅲️ NICE-TO-HAVE

**Implementierung:**
```lua
function export_patch(items, new_text, output_file)
  local by_file = group_by_file(items)
  local patch_lines = {}

  for path, file_items in pairs(by_file) do
    -- Read original file
    local orig_lines = vim.fn.readfile(path)
    local modified_lines = vim.deepcopy(orig_lines)

    -- Apply replacements (bottom-up)
    for _, it in ipairs(file_items) do
      local line = modified_lines[it.lnum]
      local new_line = line:sub(1, it.col0)
                     .. new_text
                     .. line:sub(it.col0 + #it.old + 1)
      modified_lines[it.lnum] = new_line
    end

    -- Generate unified diff
    table.insert(patch_lines, string.format("--- %s", path))
    table.insert(patch_lines, string.format("+++ %s", path))
    -- ... diff algorithm (simplified)
  end

  vim.fn.writefile(patch_lines, output_file)
end
```

**Aufwand:** 1.5 Tage (inkl. proper unified diff)

---

## Kategorie: Advanced Features (Ideas)

### 11. Case-Preserving Replace

**Umfang:** ⭐⭐ (2 Tage)
**Nutzen:** 🔥🔥🔥 (hoch)
**Performance:** ⚡ (neutral)
**Priorität:** 🅲️ NICE-TO-HAVE

**Beispiel:**
```
foo → bar
Foo → Bar
FOO → BAR
```

**Implementierung:**
```lua
function apply_case_preserving(old, new, match_text)
  local case_style = detect_case(match_text)

  if case_style == "lower" then
    return new:lower()
  elseif case_style == "upper" then
    return new:upper()
  elseif case_style == "title" then
    return new:sub(1,1):upper() .. new:sub(2):lower()
  elseif case_style == "camel" then
    -- ... camelCase logic
  end
end
```

**Aufwand:** 2 Tage (complex case detection)

---

### 12. LSP-Integration

**Umfang:** ⭐⭐⭐⭐ (4-5 Tage)
**Nutzen:** 🔥🔥🔥🔥 (sehr hoch für Code)
**Performance:** ⚡⚡⚡ (LSP-Call Overhead)
**Priorität:** 🅲️ NICE-TO-HAVE (aber komplex)

**Beschreibung:**
```vim
:Replace MyClass NewClass . --lsp
" Wenn MyClass ein Symbol ist:
"   → Nutze LSP rename
" Sonst:
"   → Fallback auf Text-Replace
```

**Herausforderungen:**
- LSP-Server möglicherweise nicht verfügbar
- Cross-File-References müssen korrekt sein
- Konflikte bei gleichzeitigem Text-Replace

**Aufwand:** 4-5 Tage (LSP-Integration, Fallback-Logic, Tests)

---

### 13. Streaming-Suche

**Umfang:** ⭐⭐⭐⭐ (4 Tage)
**Nutzen:** 🔥🔥🔥 (hoch bei großen Projekten)
**Performance:** ⚡⚡⚡⚡ (kritisch - muss effizient sein)
**Priorität:** 🅳️ MAYBE (komplex)

**Beschreibung:**
- Ripgrep-Output streamen
- Picker progressiv füllen
- Nutzer kann schon selektieren während Suche läuft

**Implementierung:**
```lua
function collect_streaming(pattern, roots, cfg, callback)
  local stdout = vim.loop.new_pipe()
  local handle

  handle = vim.loop.spawn("rg", {
    args = { "--json", pattern },
    stdio = { nil, stdout, nil },
  }, function(code)
    stdout:close()
    handle:close()
  end)

  local buffer = ""
  stdout:read_start(function(err, data)
    if data then
      buffer = buffer .. data

      -- Parse complete JSON lines
      for line in buffer:gmatch("([^\n]+)\n") do
        local ok, item = pcall(vim.json.decode, line)
        if ok then
          callback(item)  -- Send to picker incrementally
        end
      end
    end
  end)
end
```

**Herausforderungen:**
- Picker-API muss incremental updates unterstützen
- Race conditions bei früher Selektion
- Progress-Reporting komplex

**Aufwand:** 4 Tage

---

## Feature-Prioritäts-Matrix

| Feature | Umfang | Nutzen | Performance | Priorität | Empfehlung |
|---------|--------|--------|-------------|-----------|------------|
| **Help & Health** | ⭐⭐ | 🔥🔥🔥🔥🔥 | ⚡ | 🅰️ | ✅ IMPLEMENT |
| **Safe-Mode** | ⭐ | 🔥🔥🔥🔥 | ⚡ | 🅰️ | ✅ IMPLEMENT |
| **Undo-Checkpoint** | ⭐⭐ | 🔥🔥🔥🔥🔥 | ⚡⚡ | 🅰️ | ✅ IMPLEMENT |
| **File-Scopes** | ⭐⭐⭐ | 🔥🔥🔥🔥 | ⚡⚡ | 🅱️ | ✅ IMPLEMENT |
| **Dry-Run** | ⭐⭐ | 🔥🔥🔥🔥 | ⚡ | 🅱️ | ✅ IMPLEMENT |
| **Quickfix Export** | ⭐ | 🔥🔥🔥 | ⚡ | 🅱️ | ✅ IMPLEMENT |
| **History** | ⭐⭐⭐ | 🔥🔥🔥 | ⚡ | 🅱️ | ✅ IMPLEMENT |
| **Progress** | ⭐⭐ | 🔥🔥🔥 | ⚡⚡ | 🅱️ | ✅ IMPLEMENT |
| **Patch Export** | ⭐⭐ | 🔥🔥🔥 | ⚡ | 🅲️ | ⏸️ LATER |
| **Per-File Confirm** | ⭐⭐ | 🔥🔥🔥 | ⚡ | 🅲️ | ⏸️ LATER |
| **Preserve-WS** | ⭐ | 🔥🔥 | ⚡ | 🅲️ | ⏸️ LATER |
| **Case-Preserve** | ⭐⭐ | 🔥🔥🔥 | ⚡ | 🅲️ | ⏸️ LATER |
| **LSP Integration** | ⭐⭐⭐⭐ | 🔥🔥🔥🔥 | ⚡⚡⚡ | 🅲️ | ⏸️ LATER |
| **Streaming** | ⭐⭐⭐⭐ | 🔥🔥🔥 | ⚡⚡⚡⚡ | 🅳️ | ❌ SKIP |
| **Vimgrep** | ⭐⭐⭐⭐ | 🔥 | ⚡⚡⚡⚡⚡ | 🅳️ | ❌ SKIP |

## Implementierungs-Roadmap

### Phase 1: Critical (1-2 Wochen)
1. ✅ Help Documentation (2 Tage) - DONE
2. ✅ Health Check (1 Tag) - DONE
3. Safe-Mode (0.5 Tage)
4. Undo-Checkpoint (2 Tage)

### Phase 2: High-Value (2-3 Wochen)
5. Dry-Run (2 Tage)
6. Quickfix Export (1 Tag)
7. File-Scopes & Filter (3-4 Tage)
8. Progress Reporting (2 Tage)

### Phase 3: Enhancement (2-3 Wochen)
9. History & Presets (3-4 Tage)
10. Patch Export (1.5 Tage)
11. Per-File Confirmation (2 Tage)

### Phase 4: Polish (1-2 Wochen)
12. Preserve-Whitespace (1 Tag)
13. Case-Preserving (2 Tage)

**Total: 8-10 Wochen für alle High-Priority Features**
