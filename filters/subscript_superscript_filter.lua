-- subscript_superscript_filter.lua
-- Pandoc Lua filter that maps Unicode subscript/superscript characters to
-- explicit LaTeX math-mode commands.  Replaces the old template-level
-- \newunicodechar approach so that the full charset is covered in one
-- maintainable file.
--
-- Handles:
--   Str  (regular text)  – split into Str + RawInline('latex', …)
--   Code (inline code)   – replaced by RawInline('latex', \texttt{…})
-- Does NOT touch CodeBlock (fenced code) – left for pygments_filter.

local function escape_latex(s)
  local map = {
    ['\\'] = '\\textbackslash{}',
    ['{']  = '\\{',
    ['}']  = '\\}',
    ['$']  = '\\$',
    ['#']  = '\\#',
    ['%']  = '\\%',
    ['&']  = '\\&',
    ['_']  = '\\_',
    ['^']  = '\\^{}',
    ['~']  = '\\textasciitilde{}',
  }
  return s:gsub('[\\{}$#%&_^~]', map)
end

-- Mapping: Unicode subscript/superscript char → {type='sub'|'sup', base=...}
local map = {}
local function add(cp, kind, base)
  map[utf8.char(tonumber(cp, 16))] = {type=kind, base=base}
end

-- Subscript digits & symbols  U+2080 – U+208E
add('2080','sub','0') add('2081','sub','1') add('2082','sub','2')
add('2083','sub','3') add('2084','sub','4') add('2085','sub','5')
add('2086','sub','6') add('2087','sub','7') add('2088','sub','8')
add('2089','sub','9')
add('208A','sub','+') add('208B','sub','-') add('208C','sub','=')
add('208D','sub','(') add('208E','sub',')')

-- Latin subscript small letters  U+2090 – U+209C
add('2090','sub','a') add('2091','sub','e') add('2092','sub','o')
add('2093','sub','x') add('2094','sub','\\textschwa{}')
add('2095','sub','h') add('2096','sub','k') add('2097','sub','l')
add('2098','sub','m') add('2099','sub','n') add('209A','sub','p')
add('209B','sub','s') add('209C','sub','t')

-- Latin subscript letters  U+1D62 – U+1D65
add('1D62','sub','i') add('1D63','sub','r') add('1D64','sub','u')
add('1D65','sub','v')

-- Greek subscript letters  U+1D66 – U+1D6A
add('1D66','sub','\\beta')   add('1D67','sub','\\gamma')
add('1D68','sub','\\rho')    add('1D69','sub','\\phi')
add('1D6A','sub','\\chi')

-- Superscript digits & symbols  U+2070 – U+207F
add('2070','sup','0')
add('2071','sup','i')
-- 2072-2073 unassigned
add('2074','sup','4') add('2075','sup','5') add('2076','sup','6')
add('2077','sup','7') add('2078','sup','8') add('2079','sup','9')
add('207A','sup','+') add('207B','sup','-') add('207C','sup','=')
add('207D','sup','(') add('207E','sup',')') add('207F','sup','n')

-- Superscript modifier letters (common)  U+00B2, U+00B3, U+00B9
add('00B2','sup','2') add('00B3','sup','3') add('00B9','sup','1')

-- Superscript modifier letters  U+1D2C – U+1D7F  (common subset)
add('1D2C','sup','A') add('1D2D','sup','\\AE{}')
add('1D2E','sup','B') add('1D30','sup','D') add('1D31','sup','E')
add('1D32','sup','F') add('1D33','sup','G')
add('1D34','sup','H') add('1D35','sup','I') add('1D36','sup','J')
add('1D37','sup','K') add('1D38','sup','L') add('1D39','sup','M')
add('1D3A','sup','N') add('1D3C','sup','O') add('1D3D','sup','P')
add('1D3E','sup','R') add('1D3F','sup','T')
add('1D40','sup','U') add('1D41','sup','W')
add('1D42','sup','Z')
add('1D43','sup','a') add('1D44','sup','b') add('1D45','sup','c')
add('1D46','sup','d') add('1D47','sup','e') add('1D48','sup','f')
add('1D49','sup','g') add('1D4A','sup','h') add('1D4B','sup','i')
add('1D4C','sup','j') add('1D4D','sup','k') add('1D4E','sup','l')
add('1D4F','sup','m') add('1D50','sup','n') add('1D51','sup','o')
add('1D52','sup','p') -- 1D53-1D54 unassigned in this range
add('1D55','sup','q')
add('1D56','sup','r') add('1D57','sup','s') add('1D58','sup','t')
add('1D59','sup','u') add('1D5A','sup','v') add('1D5B','sup','w')
add('1D5C','sup','x') add('1D5D','sup','y') add('1D5E','sup','z')

-- Superscript small letters (extended) U+1D5F – U+1D7F
add('1D5F','sup','\\beta') add('1D60','sup','\\varphi')
add('1D61','sup','\\chi')
add('1D78','sup','\\cyrchar\\text{en}')

-- Sup/sub in other blocks
add('02B0','sup','h') add('02B1','sup','\\textturnh{}')
add('02B2','sup','j') add('02B3','sup','r')
add('02B4','sup','\\textturnr{}') add('02B5','sup','\\textturnR{}')
add('02B6','sup','\\textturnR{}')
add('02B7','sup','w') add('02B8','sup','y')

-- Helper: build LaTeX for a subscript/superscript character
local function latex_for(entry)
  if entry.type == 'sub' then
    return '\\ensuremath{{}_{' .. entry.base .. '}}'
  else
    return '\\ensuremath{{}^{' .. entry.base .. '}}'
  end
end

-- Split a string into parts at subscript/superscript characters.
-- Returns a flat list of {is_plain, text} pairs.
local function split_text(s)
  local parts = {}
  local buf = {}
  for cp in s:gmatch(utf8.charpattern) do
    local entry = map[cp]
    if entry then
      if #buf > 0 then
        table.insert(parts, {is_plain=true, text=table.concat(buf)})
        buf = {}
      end
      table.insert(parts, {is_plain=false, text=latex_for(entry)})
    else
      table.insert(buf, cp)
    end
  end
  if #buf > 0 then
    table.insert(parts, {is_plain=true, text=table.concat(buf)})
  end
  return parts
end

-- Walk a list of Inlines and replace any sub/superscript characters with
-- RawInline('latex', …) elements.  Returns a new list of Inlines.
local function process_inlines(inlines)
  local result = {}
  for _, el in ipairs(inlines) do
    if el.t == 'Str' then
      local parts = split_text(el.text)
      for _, p in ipairs(parts) do
        if p.is_plain then
          table.insert(result, pandoc.Str(p.text))
        else
          table.insert(result, pandoc.RawInline('latex', p.text))
        end
      end
    elseif el.t == 'Code' then
      -- Replace Code with a manually constructed \texttt{…} containing
      -- LaTeX-escaped text with sub/superscript characters expanded.
      local buf = {}
      for cp in el.text:gmatch(utf8.charpattern) do
        local entry = map[cp]
        if entry then
          table.insert(buf, latex_for(entry))
        else
          local escaped = escape_latex(cp)
          table.insert(buf, escaped)
        end
      end
      local inner = table.concat(buf)
      table.insert(result, pandoc.RawInline('latex', '\\texttt{' .. inner .. '}'))
    else
      table.insert(result, el)
    end
  end
  return result
end

-- Top-level Pandoc filters
function Para(el)
  el.content = process_inlines(el.content)
  return el
end

function Plain(el)
  el.content = process_inlines(el.content)
  return el
end

function Header(el)
  el.content = process_inlines(el.content)
  return el
end

function Table(el)
  -- Caption and cell content also contain Inlines
  if el.caption and el.caption.long then
    for i, block in ipairs(el.caption.long) do
      if block.content then
        el.caption.long[i].content = process_inlines(block.content)
      end
    end
  end
  return el
end

function Cite(el)
  el.content = process_inlines(el.content)
  return el
end

function Link(el)
  el.content = process_inlines(el.content)
  return el
end

function Span(el)
  el.content = process_inlines(el.content)
  return el
end

function Emph(el)
  el.content = process_inlines(el.content)
  return el
end

function Strong(el)
  el.content = process_inlines(el.content)
  return el
end

function Strikeout(el)
  el.content = process_inlines(el.content)
  return el
end

function Superscript(el)
  el.content = process_inlines(el.content)
  return el
end

function Subscript(el)
  el.content = process_inlines(el.content)
  return el
end

function SmallCaps(el)
  el.content = process_inlines(el.content)
  return el
end

function Underline(el)
  el.content = process_inlines(el.content)
  return el
end

function Quoted(el)
  el.content = process_inlines(el.content)
  return el
end
