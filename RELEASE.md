# Winuxsh Codex Release

This file is the manual release checklist for the `winuxsh-first-class-shell`
branch. It intentionally does not add GitHub Actions or local build automation;
use existing release assets from the Winuxsh project when publishing this fork.

## Scope

- Codex detects `winuxsh` and `winuxsh.exe` as `ShellType::Winuxsh`.
- Windows default shell selection prefers Winuxsh when available.
- Winuxsh command execution uses `winuxsh -C` for profile-aware shell sessions
  and `winuxsh -c` for plain shell sessions.
- Bash-like command parsing, safe-command checks, dangerous-command checks,
  approval prefix handling, and `apply_patch` interception include Winuxsh.
- Shell snapshots stay disabled for Winuxsh until replay behavior is explicitly
  supported.

## Manual Asset Checklist

- Do not run Codex release workflows for this branch.
- Use the existing Winuxsh release archive from the sibling Winuxsh repo, for
  example `../winuxsh/dist/winuxsh-v0.10.3.zip`.
- Attach the Winuxsh installer or portable archive from the Winuxsh release page
  if GitHub-hosted assets are preferred.
- Include this repository commit SHA in the release description.
- Smoke test on Windows with:

```shell
winuxsh -c 'printf "winuxsh ok\n"'
codex --version
```

## Suggested Release Body

```markdown
## Codex CLI with first-class Winuxsh support

This fork updates Codex on Windows to treat Winuxsh as a native shell target
instead of routing command execution through PowerShell by default.

### Changes

- Detect `winuxsh` and `winuxsh.exe` as a stable shell type.
- Prefer Winuxsh on Windows when it is installed.
- Execute Winuxsh commands with `winuxsh -C` or `winuxsh -c` depending on shell
  profile requirements.
- Apply bash-like parsing, command safety checks, approval handling, and
  `apply_patch` interception to Winuxsh commands.

### Assets

Use the existing Winuxsh release assets for the shell runtime. This release does
not introduce a Codex GitHub Actions release workflow.

### Notes

Install Winuxsh first, ensure `winuxsh.exe` is available on `PATH`, then run
Codex normally on Windows.
```
