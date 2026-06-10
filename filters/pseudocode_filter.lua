-- pseudocode_filter.lua
-- Purpose: Render {.spec} and {.pseudocode} code blocks with proper handling
-- of Unicode mathematical symbols and visually distinguished comment lines.
--
-- Problem being solved:
--   fancyvrb's Highlighting environment (used by pandoc's --highlight-style)
--   wraps code in \NormalTok{...}, which is TEXT mode — not verbatim.
--   Unicode chars (← → ⊗ α etc.) that are missing from the monospace font
--   cause font-substitution churn.
--   For blocks tagged {.spec} or {.pseudocode}, this filter:
--     1. Emits a fancyvrb Verbatim block with commandchars enabled, so
--        \ensuremath{...} calls are processed.
--     2. Pre-escapes all Unicode math to \ensuremath{cmd} equivalents.
--     3. Renders lines beginning with -- in a smaller, italic, grey style
--        (categorical / type-theoretic comment convention).
--
-- For non-latex output the block passes through unchanged as a plain CodeBlock.

local is_latex = FORMAT:match('latex') or FORMAT:match('pdf')

-- ==========================================================================
-- Unicode → LaTeX math substitution table
-- Keys are UTF-8 strings (Lua has no char type; patterns match bytes).
-- ORDER MATTERS for multi-char sequences: longer sequences first.
-- ==========================================================================
local subs = {
  -- Arrows
  { "←",  "\\ensuremath{\\leftarrow}" },
  { "→",  "\\ensuremath{\\rightarrow}" },
  { "↦",  "\\ensuremath{\\mapsto}" },
  { "↣",  "\\ensuremath{\\rightarrowtail}" },
  { "⇒",  "\\ensuremath{\\Rightarrow}" },
  { "⇐",  "\\ensuremath{\\Leftarrow}" },
  { "⇔",  "\\ensuremath{\\Leftrightarrow}" },
  -- Categorical / BV operators
  { "▷",  "\\ensuremath{\\triangleright}" },
  { "◁",  "\\ensuremath{\\triangleleft}" },
  { "⅋",  "\\ensuremath{\\mathbin{\\&}}" },
  { "⊸",  "\\ensuremath{\\multimap}" },
  { "⊗",  "\\ensuremath{\\otimes}" },
  { "⊕",  "\\ensuremath{\\oplus}" },
  { "⊙",  "\\ensuremath{\\odot}" },
  { "⊓",  "\\ensuremath{\\sqcap}" },
  { "⊔",  "\\ensuremath{\\sqcup}" },
  -- Logic / sets
  { "∈",  "\\ensuremath{\\in}" },
  { "∉",  "\\ensuremath{\\notin}" },
  { "∫",  "\\ensuremath{\\int}" },
  { "∀",  "\\ensuremath{\\forall}" },
  { "∃",  "\\ensuremath{\\exists}" },
  { "∅",  "\\ensuremath{\\emptyset}" },
  { "∧",  "\\ensuremath{\\wedge}" },
  { "∨",  "\\ensuremath{\\vee}" },
  { "¬",  "\\ensuremath{\\lnot}" },
  { "∑",  "\\ensuremath{\\sum}" },
  { "∏",  "\\ensuremath{\\prod}" },
  -- Relations
  { "≅",  "\\ensuremath{\\cong}" },
  { "≜",  "\\ensuremath{\\triangleq}" },
  { "≗",  "\\ensuremath{\\circeq}" },
  { "≇",  "\\ensuremath{\\ncong}" },
  { "≠",  "\\ensuremath{\\neq}" },
  { "≤",  "\\ensuremath{\\leq}" },
  { "≥",  "\\ensuremath{\\geq}" },
  { "≪",  "\\ensuremath{\\ll}" },
  { "≫",  "\\ensuremath{\\gg}" },
  { "≈",  "\\ensuremath{\\approx}" },
  -- Proof / turnstile
  { "⊢",  "\\ensuremath{\\vdash}" },
  { "⊣",  "\\ensuremath{\\dashv}" },
  -- Punctuation math (U+2212 MINUS != ASCII hyphen; U+00B7 MIDDLE DOT)
  { "−",  "\\ensuremath{-}" },         -- U+2212
  { "·",  "\\ensuremath{\\cdot}" },    -- U+00B7
  -- Greek lowercase
  { "α",  "\\ensuremath{\\alpha}" },
  { "β",  "\\ensuremath{\\beta}" },
  { "γ",  "\\ensuremath{\\gamma}" },
  { "δ",  "\\ensuremath{\\delta}" },
  { "ε",  "\\ensuremath{\\varepsilon}" },
  { "ζ",  "\\ensuremath{\\zeta}" },
  { "η",  "\\ensuremath{\\eta}" },
  { "θ",  "\\ensuremath{\\theta}" },
  { "ι",  "\\ensuremath{\\iota}" },
  { "κ",  "\\ensuremath{\\kappa}" },
  { "λ",  "\\ensuremath{\\lambda}" },
  { "μ",  "\\ensuremath{\\mu}" },
  { "ν",  "\\ensuremath{\\nu}" },
  { "ξ",  "\\ensuremath{\\xi}" },
  { "π",  "\\ensuremath{\\pi}" },
  { "ρ",  "\\ensuremath{\\rho}" },
  { "σ",  "\\ensuremath{\\sigma}" },
  { "τ",  "\\ensuremath{\\tau}" },
  { "υ",  "\\ensuremath{\\upsilon}" },
  { "φ",  "\\ensuremath{\\phi}" },
  { "χ",  "\\ensuremath{\\chi}" },
  { "ψ",  "\\ensuremath{\\psi}" },
  { "ω",  "\\ensuremath{\\omega}" },
  -- Greek uppercase
  { "Γ",  "\\ensuremath{\\Gamma}" },
  { "Δ",  "\\ensuremath{\\Delta}" },
  { "Θ",  "\\ensuremath{\\Theta}" },
  { "Λ",  "\\ensuremath{\\Lambda}" },
  { "Ξ",  "\\ensuremath{\\Xi}" },
  { "Π",  "\\ensuremath{\\Pi}" },
  { "Σ",  "\\ensuremath{\\Sigma}" },
  { "Υ",  "\\ensuremath{\\Upsilon}" },
  { "Φ",  "\\ensuremath{\\Phi}" },
  { "Ψ",  "\\ensuremath{\\Psi}" },
  { "Ω",  "\\ensuremath{\\Omega}" },
  -- Subscript/superscript digits
  { "⁰",  "\\ensuremath{^{0}}" },
  { "¹",  "\\ensuremath{^{1}}" },
  { "²",  "\\ensuremath{^{2}}" },
  { "³",  "\\ensuremath{^{3}}" },
  { "⁴",  "\\ensuremath{^{4}}" },
  { "⁺",  "\\ensuremath{^{+}}" },
  { "⁻",  "\\ensuremath{^{-}}" },
  { "₀",  "\\ensuremath{_{0}}" },
  { "₁",  "\\ensuremath{_{1}}" },
  { "₂",  "\\ensuremath{_{2}}" },
  { "₃",  "\\ensuremath{_{3}}" },
}

-- ==========================================================================
-- Helpers
-- ==========================================================================

-- Escape LaTeX special characters that are NOT part of a command we inserted.
-- We do this BEFORE substituting math, then the \ensuremath{...} strings are
-- inserted into already-escaped text.
local function latex_escape(s)
  -- Escape in a specific order to avoid double-escaping backslashes.
  s = s:gsub("\\", "\\textbackslash{}")
  s = s:gsub("{",  "\\{")
  s = s:gsub("}",  "\\}")
  s = s:gsub("%%", "\\%%")
  s = s:gsub("#",  "\\#")
  s = s:gsub("&",  "\\&")
  s = s:gsub("%$", "\\$")
  s = s:gsub("%^", "\\^{}")
  s = s:gsub("_",  "\\_")
  s = s:gsub("~",  "\\textasciitilde{}")
  return s
end

-- Undo the backslash escaping for the \ensuremath{...} strings we will insert,
-- since those backslashes were escaped in the step above.
-- We replace the escaped form of "\\textbackslash{}" that would appear in
-- \ensuremath{...} back to actual backslashes.
-- Strategy: substitute math AFTER escaping plain text, but re-insert \{ \} as
-- literal braces for the commands. We use a placeholder approach:
-- 1. latex_escape the whole line.
-- 2. Apply subs, which insert literal LaTeX command strings. These are safe
--    because they contain only ASCII backslashes and braces that were just
--    introduced by us (not by user text).

-- Actually the cleanest approach: substitute math chars BEFORE escaping,
-- using a placeholder that won't be touched by latex_escape, then restore.
-- Placeholder: \x01MATH\x01{index}\x01

local function apply_math_subs(line)
  local placeholders = {}
  -- Replace Unicode math chars with placeholders
  for i, pair in ipairs(subs) do
    local ch, cmd = pair[1], pair[2]
    local count = 0
    line, count = line:gsub(ch, function()
      local idx = #placeholders + 1
      placeholders[idx] = cmd
      return "\x01" .. idx .. "\x01"
    end)
    _ = count  -- silence unused warning
  end
  -- Escape the remaining ASCII/Latin text (no math chars left)
  line = latex_escape(line)
  -- Restore placeholders as literal LaTeX commands
  line = line:gsub("\x01(%d+)\x01", function(idx_str)
    local idx = tonumber(idx_str)
    return placeholders[idx] or ""
  end)
  return line
end

-- Render a single line of the spec block.
-- Lines beginning with -- (optionally preceded by whitespace) are comment lines:
-- rendered smaller, italic, grey. Preserving leading whitespace as \hphantom
-- would complicate things; instead we keep the indent via \quad per 2-space group,
-- but for simplicity here we just emit the full line styled.
local function render_line(raw_line)
  local trimmed = raw_line:match("^%s*(.-)%s*$")  -- for comment detection only
  -- Check for comment marker
  if trimmed:match("^%-%-") then
    -- Comment line: escape and style as italic grey small text
    local processed = apply_math_subs(raw_line)
    -- Wrap in comment style command
    return "{\\small\\color{speccomment}\\textit{" .. processed .. "}}"
  else
    -- Code line: escape and render in monospace (alltt/Verbatim inherits it)
    return apply_math_subs(raw_line)
  end
end

-- ==========================================================================
-- Main filter function
-- ==========================================================================

function CodeBlock(elem)
  -- Only activate for LaTeX output and only for tagged blocks
  if not is_latex then return nil end

  local classes = elem.classes
  local is_spec = false
  for _, cls in ipairs(classes) do
    if cls == "spec" or cls == "pseudocode" or cls == "specblock" then
      is_spec = true
      break
    end
  end
  if not is_spec then return nil end

  -- Split into lines, process each, rejoin
  local lines = {}
  for line in (elem.text .. "\n"):gmatch("([^\n]*)\n") do
    table.insert(lines, render_line(line))
  end
  -- Remove trailing empty line added by the gmatch pattern
  if lines[#lines] == "" then table.remove(lines) end

  local body = table.concat(lines, "\n")

  -- Emit as a fancyvrb Verbatim with commandchars so our \ensuremath calls fire.
  -- We surround with a color definition for the comment style (colour is
  -- defined once per document via an AtBeginDocument hook inserted below).
  local latex_block = table.concat({
    "\\begin{Verbatim}[commandchars=\\\\\\{\\},",
    "  fontsize=\\small, frame=single, framesep=4pt]",
    body,
    "\\end{Verbatim}"
  }, "\n")

  return pandoc.RawBlock("latex", latex_block)
end

-- Inject the speccomment colour definition into the preamble once.
-- We use a Meta filter to append to header-includes.
function Meta(meta)
  if not is_latex then return nil end

  local color_def = pandoc.RawInline("latex",
    "\\colorlet{speccomment}{gray!60!black}")

  local hi = meta["header-includes"]
  if hi == nil then
    meta["header-includes"] = pandoc.MetaList({
      pandoc.MetaInlines({ color_def })
    })
  elseif hi.t == "MetaList" then
    table.insert(hi, pandoc.MetaInlines({ color_def }))
  elseif hi.t == "MetaInlines" then
    meta["header-includes"] = pandoc.MetaList({
      hi,
      pandoc.MetaInlines({ color_def })
    })
  end
  return meta
end
