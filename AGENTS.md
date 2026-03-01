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
