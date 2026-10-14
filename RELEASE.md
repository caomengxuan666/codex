# NiuBash Codex Release

This file is the manual release checklist for the `niu-first-class-shell`
branch. It intentionally does not add GitHub Actions or local build automation;
use existing release assets from the NiuBash project when publishing this fork.

## Scope

- Codex detects `niu` and `niu.exe` as `ShellType::Niu`.
- Windows default shell selection prefers NiuBash when available.
- NiuBash command execution uses `niu -C` for profile-aware shell sessions
  and `niu -c` for plain shell sessions.
- Bash-like command parsing, safe-command checks, dangerous-command checks,
  approval prefix handling, and `apply_patch` interception include NiuBash.
- Shell snapshots stay disabled for NiuBash until replay behavior is explicitly
  supported.

## Manual Asset Checklist

- Build the Windows x64 zip either locally or with the
  `niu-codex-windows-build` workflow (manual dispatch).
- Name the release and tag `niu-codex-preview-<YYYYMMDD>` and the asset
  `niu-codex-preview-<YYYYMMDD>-windows-x86_64.zip`.
- The zip contains a top-level directory of the same name holding:
  `codex.exe`, `codex-command-runner.exe`, `codex-windows-sandbox-setup.exe`,
  `README.md`, and this `RELEASE.md`.
- Include this repository commit SHA in the release description.
- Smoke test on Windows with:

```shell
niu -c 'printf "niu ok\n"'
codex --version
```

## Suggested Release Body

```markdown
## Codex CLI with first-class NiuBash support

This fork updates Codex on Windows to treat NiuBash as a native shell target
instead of routing command execution through PowerShell by default.

### Changes

- Detect `niu` and `niu.exe` as a stable shell type.
- Prefer NiuBash on Windows when it is installed.
- Execute NiuBash commands with `niu -C` or `niu -c` depending on shell
  profile requirements.
- Apply bash-like parsing, command safety checks, approval handling, and
  `apply_patch` interception to NiuBash commands.

### Assets

- `niu-codex-preview-<YYYYMMDD>-windows-x86_64.zip` — Codex CLI plus the
  Windows sandbox helpers (`codex-command-runner.exe`,
  `codex-windows-sandbox-setup.exe`), built from this branch.
- The NiuBash shell runtime itself is installed separately from the
  [NiuBash releases page](https://github.com/caomengxuan666/dsh-niu/releases).

### Notes

Install NiuBash first, ensure `niu.exe` is available on `PATH`, then run
Codex normally on Windows.
```
