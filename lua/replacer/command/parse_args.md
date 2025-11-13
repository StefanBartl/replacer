
Man kann das wie bei Shells handhaben: entweder unterschiedliche Quote-Arten kombinieren oder Backslash-Escapes verwenden. Übliche, einfache Regeln:

* Verwende unterschiedliche Quote-Arten, um Escapes zu vermeiden:

  * `:Replace '"test"' ok %`  — token ist `"test"` inklusive doppelter Anführungszeichen
  * `:Replace "'test'" ok %`  — token ist `'test'` inklusive einfacher Anführungszeichen
* Wenn man innerhalb derselben Quote-Art Anführungszeichen braucht, escapen mit `\`:

  * `:Replace "\"test\"" ok %`  — token ist `"test"` (doppelte Quotes sind Teil des Tokens)
  * `:Replace '\''test'\'' ok %` — (Beispiel mit verschachteltem Escape)
* Unquoted ist weiterhin möglich:

  * `:Replace DAS DAS %`
  * `:Replace DAS "DAS mit leer" %`

Vorteile / Empfehlungen:

* Am einfachsten und am ehesten erwartbar für Nutzer ist die Shell-artige Variante: erlauben `"` und `'` als Umgrenzung und `\` als Escape innerhalb von Quotes.
* Zusätzlich kann man Backslash als Escape auch *außerhalb* von Quotes akzeptieren (z. B. `:\"test\"` oder `\"test\"`), damit Nutzer `:Replace \"test\" ok %` schreiben können, falls sie es so gewohnt sind.

Implementationsvorschlag — minimaler Parser-Patch:

* Der vorhandene `parse_args` unterstützt bereits escapes **innerhalb** von Quotes.
* Man kann ergänzen, dass ein Backslash auch außerhalb von Quotes das nächste Zeichen nimmt (also `\` als allgemeines Escape), damit `\"test\"` als ein Token erkannt wird, selbst wenn der Nutzer nicht in einer Quote startet.

Beispiel: angepasster `parse_args`-Abschnitt (nur die relevante Ergänzung). Die Kommentare sind in Englisch (wie gewünscht) and the code is ready to drop into the existing parser.

```lua
-- Extend tokenizer so backslash escapes are honored even outside of quotes.
-- This allows inputs like: :Replace \"test\" ok %
-- Comments in English to follow project convention.

---@param s string
---@return string[] tokens
local function parse_args(s)
  local out = {} ---@type string[]
  if not s or s == "" then return out end

  local i, n = 1, #s
  while i <= n do
    -- skip whitespace
    while i <= n and s:sub(i,i):match("%s") do i = i + 1 end
    if i > n then break end

    local c = s:sub(i,i)
    if c == '"' or c == "'" then
      -- quoted token (existing behavior)
      local q = c
      i = i + 1
      local buf = {} ---@type string[]
      while i <= n do
        local ch = s:sub(i,i)
        if ch == "\\" and i < n then
          -- escape next char inside quotes
          buf[#buf+1] = s:sub(i+1,i+1)
          i = i + 2
        elseif ch == q then
          i = i + 1
          break
        else
          buf[#buf+1] = ch
          i = i + 1
        end
      end
      out[#out+1] = table.concat(buf)
    else
      -- unquoted token, but honor backslash escapes here as well
      local j = i
      local buf = {} ---@type string[]
      while j <= n and not s:sub(j,j):match("%s") do
        local ch = s:sub(j,j)
        if ch == "\\" and j < n then
          -- consume backslash and take next char verbatim
          buf[#buf+1] = s:sub(j+1,j+1)
          j = j + 2
        else
          buf[#buf+1] = ch
          j = j + 1
        end
      end
      out[#out+1] = table.concat(buf)
      i = j
    end
  end

  return out
end
```

Praxis-Beispiele (wie der Parser die Tokens liefert):

* Eingabe: `:Replace "test" "ok" %` → Tokens: `{"test", "ok", "%"}`
* Eingabe: `:Replace "\"test\"" ok %` → Tokens: `{"\"test\"", "ok", "%"}` (erstes Token enthält die doppelten Anführungszeichen als Teil des Texts)
* Eingabe: `:Replace '"test"' ok %` → Tokens: `{"\"test\"", "ok", "%"}`
* Eingabe: `:Replace \'test\' test %` → Tokens: `{"'test'", "test", "%"}`

Weiteres Feature, das man optional anbieten kann:

* Ein kleiner "quote mode" Flag (z. B. `--raw` oder `--q`), der sagt: „Interpret tokens exakt wie eingegeben, ohne Neovim/cli-Interpolation“ — hilfreich, falls man noch weitere Sonderfälle abfangen will. Meist reicht aber die kombinierte Strategie: different quote types + backslash escape + die Parser-Erweiterung oben.

Empfehlung:

* Man kann die parser-Erweiterung wie oben einbauen (Backslash outside quotes). Danach dokumentieren, wie Nutzer Anführungszeichen ersetzen: Beispiele in der README (mit `:Replace "\"from\"" "to"` und mit `:Replace '"from"' 'to'`).
* Tests hinzufügen, die `parse_args` direkt mit typischen Eingaben prüfen (unit tests), um Regressionen zu vermeiden.
