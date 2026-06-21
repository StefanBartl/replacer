# TODO – Richtlinien-Review `replacer`

**Status: alle 10 Punkte implementiert & via `tests/feature_smoke.lua` verifiziert (22/22).**

- [x] 1. Mehrfach-Vorkommen pro Zeile → je ein eigener Picker-Eintrag (ripgrep & vimgrep). *(rg.lua `find_all_occurrences`)*
- [x] 2. `--literal` / `--no-literal` / `--regex` (+ weitere Optionen) als Command-Flags. *(command.lua)*
- [x] 3. Kommentare/Doku: alle neuen Module ausführlich annotiert; README + `doc/replacer.txt` aktualisiert.
- [x] 4. `search_engine = "ripgrep"|"vimgrep"|"auto"`; vimgrep als automatischer Fallback wenn `rg` fehlt. *(rg.lua `pick_backend`)*
- [x] 5. Picker-Auto-Detect: `engine="auto"` → fzf-lua falls vorhanden, sonst telescope. *(init.lua `pick_picker`)*
- [x] 6. Range-Support: `:'<,'>Replace` beschränkt auf Zeilenbereich. *(command.lua `range=true`)*
- [x] 7. Klare Fehlermeldungen (missing / too many / unknown option), deferred notify. *(command.lua)*
- [x] 8. Filter als Argumente `--type=` / `--glob=` / `--exclude=` + in Config (`file_types`/`globs`/`exclude`).
- [x] 9. `--dry` (Plan-only) mit Statistik (Treffer/Dateien) + `--export=` (Patch/JSON). *(export.lua, init.lua)*
- [x] 10. Patch-Export: git-applybare unified diff (`vim.diff`) oder JSON. *(export.lua)*

Zusätzlich behoben: `confirm_all=false` wurde durch `as_bool(x) or default` verschluckt
(Lua-`false`-Falle) → `pick_bool` eingeführt; Windows-Pfade mit `\` wurden vom Tokenizer
zerstört → Backslash-Escape nur noch vor Quotes/Space/Backslash.

---

## 1. Aufräumen der restlichen Merge-Reste

- [x] 🔴 **Tote Picker-Duplikate entfernt.** `pickers/fzf/` & `pickers/telescope/` (~620 LOC, von
  niemandem require't) gelöscht; `init.lua` nutzt die monolithischen `fzf.lua`/`telescope.lua`.
- [x] 🔴 **`health.lua` auf neue Config-API umgestellt.** Nutzt jetzt `require("replacer.config").get()`,
  kennt `engine="auto"`/`search_engine`/Filter, meldet vimgrep-Fallback statt rg-Hard-Error.

## 2. Sicherheit & Fehlerbehandlung (Regel 1, 3, 7)

- [x] 🔴 **API-Guards + `pcall` in `apply.lua`.** `bufadd`/`bufload`/`nvim_buf_set_text`/`write` jetzt
  `pcall`-gekapselt + `nvim_buf_is_valid`/`is_loaded`-Checks; Fehler werden gesammelt statt zu werfen.
- [x] 🔴 **Strukturierte Fehler statt stiller Fehler.** Neues Modul [error.lua](../lua/replacer/error.lua)
  (`safe_call` + `WriteError`/`SearchError`/`InvalidScopeError`); `apply_matches` gibt `RP_Error[]` zurück,
  rg-Suchfehler fließen via `err` an die Aufrufschicht; stiller `fzf.lua`-pcall als optional kommentiert.
- [x] 🟡 **`notify()` im Low-Level reduziert.** Apply sammelt Fehler & gibt sie zurück; rg-Suchfehler
  (async) werden in `init.run` per `err` notifyt. Verbleibende Notifies sind rein informativ
  (Buffer-Scan-Hinweis, vimgrep-Fallback-Warnung) — bewusst beibehalten.

## 3. Architektur & Testbarkeit (Regel 2, 6)

- [x] 🟡 **`apply` als reine Funktion.** `apply.compute_file_edits(lines, matches, new)` ist seiteneffektfrei
  und unit-getestet; reale Buffer-Anwendung getrennt in `apply_matches`.
- [x] 🟡 **Test-Harness.** [tests/feature_smoke.lua](../tests/feature_smoke.lua) (22) +
  [tests/async_utf8.lua](../tests/async_utf8.lua) (7), `make test`, CI-Workflow. Lauf via `nvim -l`.
- [ ] 🟢 **`/config`-Struktur (DEFAULTS.lua).** Bewusst zurückgestellt — geringer Nutzen, Defaults sind
  bereits sauber in `config.lua` gekapselt.

## 4. Dokumentation & Annotationen (Regel 5)

- [x] 🟡 **Doku-Drift behoben.** `README.md` + `doc/replacer.txt` vollständig aktualisiert (neue Flags,
  `engine="auto"`, `search_engine`, Filter, Dry-run/Export); alle `ext_highlight_opts`/`:ReplaceDebug`/
  `replacer.options`-Verweise entfernt.
- [~] 🟡 **Datei-/Funktions-Tags.** Alle neuen/überarbeiteten Module ausführlich annotiert
  (`@param`/`@return`/`@class`). Vollständiger `@brief`-Sweep über *alle* Altdateien noch offen.

## 5. Tooling (Checklist Abschnitt 7)

- [x] 🟡 **`stylua.toml` + `.luacheckrc` + CI.** Angelegt + `Makefile` (`fmt`/`lint`/`test`/`check`) +
  GitHub-Actions-Workflow ([.github/workflows/ci.yml](../.github/workflows/ci.yml)).
- [x] 🟡 **`.luarc.json`** mit `diagnostics.globals=["vim"]`, Workspace-Library, Hints.

---

## 6. Zusätzliche Vorschläge (über die Checklisten hinaus)

### Sicherheit
- [x] 🔴 **`confirm_wide_scope` erzwungen.** `:Replace … cwd --all` löst bei Nicht-Buffer-Scope einen
  Bestätigungsdialog aus (`init.lua` `dispatch`, `wide`-Check).
- [x] 🟡 **Multi-File-Replace nicht atomar — dokumentiert.** Hinweis in README (Safety) und
  `doc/replacer.txt` (*replacer-troubleshooting-not-atomic*) inkl. Dry-run/Export als Review-Weg.

### Performance
- [x] 🟡 **`rg` läuft jetzt async.** `rg.collect_async` nutzt `vim.system(..., on_exit)` + `vim.schedule`;
  vimgrep/Buffer-Pfad bleibt synchron. `init.run` dispatcht im Callback. Kein UI-Block mehr bei großen Repos.
- [x] 🟢 Tabellenaufbau-Mikro-Opt (`t[#t+1]` → `t[i]=v`). Heiße Flat-List-Schleifen
  (`find_all_occurrences`, `parse_rg_json`, `collect_from_buffer`, `scan_file`, `list_files`,
  `apply_line_range`, `read_lines`) nutzen jetzt einen expliziten Index-Zähler; `group_by_path`-Buckets
  eine parallele Count-Map. Bounded Per-File-Schleifen unverändert gelassen.

### Cross-Plattform & Korrektheit
- [x] 🟡 **UTF-8-Regression geprüft.** [tests/async_utf8.lua](../tests/async_utf8.lua) testet Umlaute + Emoji
  (`Grüße Müller 😀 Müller` → `Mueller`), Byte-Offsets korrekt, keine Regression.
- [x] 🟢 **Windows-Pfade/Backslash.** `vim.system` (Arg-Vektor, keine Shell) ist der Standardpfad;
  `shellescape` nur Legacy-Fallback. Zusätzlich Tokenizer-Fix für `\` in Pfaden. Auf Windows verifiziert.

