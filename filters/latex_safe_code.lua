-- latex_safe_code.lua
-- Pandoc Lua filter to prevent LaTeX errors caused by special characters
-- inside syntax-highlighted code blocks.
--
-- Problem:
--   When Pandoc applies syntax highlighting (e.g. --highlight-style=tango),
--   it wraps code tokens in \textcolor[rgb]{...}{...}.  A bare $ inside one
--   of these tokens enters math mode and breaks LaTeX's {/} grouping,
--   producing "Extra }, or forgotten $" errors.
--
--   This is the #1 cause of LaTeX build failures in documents that contain
--   shell variables ($VAR), SQL ($param), or any code with dollar signs.
--
-- Solution (AST-level, not regex):
--   1. CodeBlock: strip the language class from fenced code blocks that
--      contain $ — this disables highlighting for that block while
--      preserving the monospace Verbatim rendering.  The original language
--      is preserved as a source-language attribute for reference.
--   2. --force-preprocess: additionally strip highlighting from code blocks
--      containing { } # characters that can also break inside \textcolor.
--
-- Why a Lua filter instead of bash preprocessing?
--   The Pandoc AST already knows what is code and what is math/prose.
--   Regex-based approaches in bash must track fenced-block state manually
--   and cannot distinguish `$var` in code from `$x^2$` in prose.
--   The DOM exists precisely for this.

local force = os.getenv("MDTEXPDF_FORCE_PREPROCESS") == "1"

---------------------------------------------------------------------------
-- CodeBlock: strip language tag when content contains characters that
-- break inside \textcolor{...}{...}
---------------------------------------------------------------------------
function CodeBlock(el)
  -- Only act on blocks that have a language class (i.e. would be highlighted)
  if #el.classes == 0 then return nil end

  local text = el.text
  local strip = false
  local reason = ""

  -- Always strip language tag if the block contains $
  -- This is the primary fix for "Extra }, or forgotten $" errors
  if text:match('%$') then
    strip = true
    reason = "contains $"
  end

  -- In force mode, also strip for { } # that can break inside \textcolor
  if not strip and force then
    if text:match('[{}]') then
      strip = true
      reason = "contains {/} [force-preprocess]"
    elseif text:match('#') then
      strip = true
      reason = "contains # [force-preprocess]"
    end
  end

  if strip then
    local lang = el.classes[1]
    io.stderr:write("[latex_safe_code] Stripped language tag '"
      .. lang .. "' from code block (" .. reason .. ")\n")
    el.classes = {}
    el.attributes['source-language'] = lang  -- preserve for reference
    return el
  end

  return nil
end

return {
  { CodeBlock = CodeBlock },
}
