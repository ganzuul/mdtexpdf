-- pygments_filter.lua
-- Pandoc Lua filter that replaces fenced CodeBlocks with pygmentize output.
-- Reads environment variables:
--   MDTEXPDF_PYGMENTS_NOWRAP  (set to "1" to disable line wrapping)
--   MDTEXPDF_PYGMENTS_FONTSIZE (e.g. "small", "footnotesize", "tiny")

--- Determine lexer from code block's language class.
local function lexer_name(code_block)
  local classes = code_block.classes
  if classes and #classes > 0 then
    return classes[1]
  end
  return "text"
end

--- Check if pygmentize is available.
local function check_pygmentize()
  local proc = io.popen("command -v pygmentize 2>/dev/null")
  if proc then
    local result = proc:read("*a")
    proc:close()
    return result ~= ""
  end
  return false
end

--- Read env var helpers.
local function env_true(name)
  local v = os.getenv(name)
  return v == "1" or v == "true" or v == "yes"
end

--- Run pygmentize on code text and return raw LaTeX output.
local function run_pygmentize(code, lexer)
  local tmp = os.tmpname()
  local f = io.open(tmp, "w")
  if not f then return nil end
  f:write(code)
  f:close()

  local cmd = "pygmentize -f latex -O style=default,stripnl=false -l " .. lexer .. " " .. tmp .. " 2>/dev/null"
  local proc = io.popen(cmd, "r")
  if not proc then os.remove(tmp); return nil end
  local out = proc:read("*a")
  proc:close()
  os.remove(tmp)
  return out
end

return {
  {
    Pandoc = function()
      if not check_pygmentize() then
        io.stderr:write("Warning: pygmentize not found on PATH. Code blocks will use Pandoc's default highlighting.\n")
      end
    end
  },
  {
    CodeBlock = function(code_block)
      if not check_pygmentize() then
        return nil
      end

      local lexer = lexer_name(code_block)
      if lexer == "" then
        return nil
      end

      local pyg_output = run_pygmentize(code_block.text, lexer)
      if not pyg_output or pyg_output == "" then
        return nil
      end

      -- Pygmentize already outputs \begin{Verbatim}[commandchars=...]
      -- with contents and \end{Verbatim}. We inject extra options into
      -- the \begin{Verbatim}[...] line alongside the existing options.
      local extra_opts = ""
      if not env_true("MDTEXPDF_PYGMENTS_NOWRAP") then
        extra_opts = extra_opts .. ",breaklines=true"
      end
      local fontsize = os.getenv("MDTEXPDF_PYGMENTS_FONTSIZE")
      if fontsize and fontsize ~= "" then
        extra_opts = extra_opts .. ",fontsize=" .. fontsize
      end

      -- Inject extra options before the closing bracket of \begin{Verbatim}[...]
      if extra_opts ~= "" then
        local verb_start = "\\begin{Verbatim}"
        local idx = pyg_output:find(verb_start, 1, true)
        if idx then
          local bracket_start = pyg_output:find("%[", idx)
          if bracket_start then
            local bracket_end = pyg_output:find("%]", bracket_start)
            if bracket_end then
              local prefix = pyg_output:sub(1, bracket_end - 1)
              local suffix = pyg_output:sub(bracket_end)
              pyg_output = prefix .. "," .. extra_opts .. suffix
            end
          end
        end
      end

      if not pyg_output:find("\\end{Verbatim}", 1, true) then
        return nil
      end

      return pandoc.RawBlock("latex", pyg_output)
    end
  }
}
