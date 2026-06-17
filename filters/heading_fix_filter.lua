-- heading_fix_filter.lua
-- Pandoc Lua filter to fix level 4 and 5 headings so they render as
-- standalone block headings instead of inline \paragraph{} commands.
-- In book class with the chapter/section shift from book_structure.lua,
-- #### maps to \paragraph which runs inline with the following text.
-- This filter converts them to properly formatted block headings.

-- Escape LaTeX special characters in text
local escapes = {
  ['\\'] = '\\textbackslash{}',
  ['_']  = '\\_',
  ['^']  = '\\^{}',
  ['#']  = '\\#',
  ['$']  = '\\textdollar{}',
  ['%']  = '\\%',
  ['&']  = '\\&',
  ['{']  = '\\{',
  ['}']  = '\\}',
  ['~']  = '\\textasciitilde{}'
}

local function escape_latex(s)
  for char, repl in pairs(escapes) do
    s = s:gsub('%' .. char, repl)
  end
  return s
end

function Header(el)
    if el.level == 4 then
        -- Convert #### to a bold, standalone heading with vertical space
        local heading_text = pandoc.utils.stringify(el.content)
        heading_text = escape_latex(heading_text)
        local latex = string.format(
            "\\vspace{0.8em}\\noindent{\\textbf{%s}}\\vspace{0.4em}\\par",
            heading_text
        )
        return pandoc.RawBlock('latex', latex)
    elseif el.level == 5 then
        -- Convert ##### to a bold italic, standalone heading with vertical space
        local heading_text = pandoc.utils.stringify(el.content)
        heading_text = escape_latex(heading_text)
        local latex = string.format(
            "\\vspace{0.6em}\\noindent{\\textbf{\\textit{%s}}}\\vspace{0.3em}\\par",
            heading_text
        )
        return pandoc.RawBlock('latex', latex)
    end
    return el
end
