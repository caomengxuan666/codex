# NiuBash Codex Release

This file is the manual release checklist for the `niu-first-class-shell`
branch. It intentionally does not add GitHub Actions or local build automation;
use existing release assets from the NiuBash project when publishing this fork.

## Scope

- Codex detects `niu` and `niu.exe` as `ShellType::NiuBash`.
- Windows default shell selection prefers NiuBash when available.
- NiuBash command execution uses `niu -C` for profile-aware shell sessions
  and `niu -c` for plain shell sessions.
- Bash-like command parsing, safe-command checks, dangerous-command checks,
  approval prefix handling, and `apply_patch` interception include NiuBash.
- Shell snapshots stay disabled for NiuBash until replay behavior is explicitly
  supported.

## Manual Asset Checklist

- Do not run Codex release workflows for this branch.
- Use the existing NiuBash release archive from the sibling NiuBash repo, for
  example `../niu/dist/niu-v0.10.3.zip`.
- Attach the NiuBash installer or portable archive from the NiuBash release page
  if GitHub-hosted assets are preferred.
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

Use the existing NiuBash release assets for the shell runtime. This release does
not introduce a Codex GitHub Actions release workflow.

### Notes

Install NiuBash first, ensure `niu.exe` is available on `PATH`, then run
Codex normally on Windows.
```
