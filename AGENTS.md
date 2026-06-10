# Agent Notes

## System-vs-Workspace Binary
This repository may be used on machines that already have a system/user-installed `mdtexpdf` on `PATH` (for example `~/.local/bin/mdtexpdf`).

When fixing bugs in this repo:
1. Test with the workspace script first to validate local code changes:
   - `./mdtexpdf.sh ...`
2. If you test with `mdtexpdf ...`, verify which binary is running:
   - `command -v mdtexpdf`
   - `readlink -f "$(command -v mdtexpdf)"`
3. After a fix is confirmed, reinstall from this repo so the installed copy matches the fix:
   - `make build`
4. Prefer the scripted verification flow to avoid terminal drift and PATH confusion:
   - `./scripts/verify-install.sh --install`
   - Optional conversion smoke test: `./scripts/verify-install.sh --convert your-file.md`

## Quick sanity check
After reinstalling:
- `command -v mdtexpdf`
- `mdtexpdf --version`
- Re-run the previously failing conversion command.

## Recommended one-liner
Use this as the default post-fix workflow:

`./scripts/verify-install.sh --install --convert your-file.md`

## Non-interactive conversion (for agents and CI)

`mdtexpdf convert` prompts interactively for title, author, date, and
footer when no template.tex exists.  To run non-interactively, always
provide all four flags:

```bash
./mdtexpdf.sh convert \
  -t "Document Title" \
  -a "Author Name" \
  -d "yes" \
  --no-footer \
  input.md
```

The four interactive prompts and their flags:

| Prompt          | Flag              | Example                       |
|-----------------|-------------------|-------------------------------|
| Title           | `-t` / `--title`  | `-t "My Doc"`                |
| Author          | `-a` / `--author` | `-a "Jane Doe"`              |
| Date            | `-d` / `--date`   | `-d "yes"` (current date)    |
| Footer          | `--no-footer`     | `--no-footer` to skip        |

Date flag values: `yes` = current date, `no` = disabled, `YYYY-MM-DD` /
`DD/MM/YY` / `"Month Day, Year"` = formatted current date, any other
string = literal date text.  Footer: use `--no-footer` to skip, or
`-f "text"` to set custom footer text.

If a template.tex already exists in the working directory, these flags
are not needed — pandoc uses it directly.

## LaTeX-safe code blocks (latex_safe_code.lua)

A Lua filter that prevents the #1 LaTeX build failure: bare `$` inside
syntax-highlighted code blocks.  When Pandoc applies `--highlight-style=tango`,
code tokens get wrapped in `\textcolor[rgb]{...}{...}`.  A `$` inside one
of those tokens enters math mode and breaks LaTeX's brace grouping,
producing `"Extra }, or forgotten $"` errors.

The filter strips the language tag from fenced code blocks that contain
`$`, disabling highlighting for that block while preserving monospace
Verbatim rendering.  It is loaded unconditionally and is a no-op for
code blocks without problematic characters.

`--force-preprocess` extends this to also strip highlighting from code
blocks containing `{`, `}`, or `#`.  The flag is communicated to the
filter via the `MDTEXPDF_FORCE_PREPROCESS` environment variable.

## Pygments syntax highlighting (`--pygments`)

The `--pygments` flag replaces Pandoc's built-in syntax highlighting
(Skylighting) with pygmentize.  It uses bold/italic/underline instead
of color commands, avoiding `\textcolor`-related LaTeX errors entirely.

**Usage:**
```bash
./mdtexpdf.sh convert --pygments \
  -t "My Doc" -a "Jane Doe" -d "yes" --no-footer \
  input.md
```

**Flags:**
| Flag | Default | Description |
|------|---------|-------------|
| `--pygments` | off | Enable pygmentize-based highlighting |
| `--pygments-no-wrap` | off (wrap on) | Disable line wrapping in code blocks |
| `--pygments-fontsize SIZE` | (default) | Set font size (`small`, `footnotesize`, `tiny`, etc.) |

**How it works:**
1. A Pandoc Lua filter (`pygments_filter.lua`) pipes each fenced code
   block through `pygmentize -f latex` and returns the result as raw
   LaTeX (`\begin{Verbatim}...\end{Verbatim}` with `\PY` token commands).
2. The template includes a `$if(pygments)$` conditional block that
   defines all `\PY@tok@...` style commands using only markdown primitives
   (`\textbf`, `\textit`, `\underline` — never `\textcolor`).
3. When `--pygments` is active, `latex_safe_code.lua` is **skipped**
   (pygments handles `$`, `{`, `}`, `#` natively via `\PYZdl`, `\PYZob`,
   etc.).

**Key facts for debugging:**
- The style definitions live in template.sh as a heredoc block inside
  `$if(pygments)$…$endif$`.  They were mechanically generated from
  `styles/mdtexpdf-pygments.sty`.
- Heredoc escaping rules: `\\` → `\`, `\$` → `$`, `` \` `` → `` ` ``.
- Pandoc's template engine uses `$$` for a literal `$` (not `\$`).
- The `\PYZbs` definition must use `\\\\` at the end to produce `\\`
  (double backslash) in the Pandoc output.
- pygments_filter.lua replaces `CodeBlock` elements only; inline code
  (`Code` / `` ` ``) still uses Pandoc's default highlighting.
