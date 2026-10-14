# NiuBash First-Class Shell Plan

## Goal

Make NiuBash a first-class Codex shell on Windows instead of relying only on a configurable shell path workaround.

## Current Upstream Shape

- Shell identity is centralized in `codex-shell-command::shell_detect::ShellType`.
- Command argv generation happens in `codex-core::shell::Shell::derive_exec_args`.
- Approval, safety, dangerous-command detection, and apply_patch interception reuse bash-like shell parsing for `bash`, `zsh`, and `sh`.
- Windows currently defaults to PowerShell when no explicit shell path is provided.

## Implementation Phases

1. Add `ShellType::NiuBash`
   - Recognize `niu` and `niu.exe`.
   - Report the stable shell name as `niu`.
   - Resolve via PATH first, then common Windows install locations.

2. Make NiuBash the preferred Windows default
   - On Windows, choose NiuBash when it is installed.
   - Fall back to PowerShell and then the ultimate `cmd.exe` fallback.

3. Generate native NiuBash exec argv
   - Use `niu -C <script>` for login/profile calls so user configuration is loaded.
   - Use `niu -c <script>` when login/profile loading is disabled.
   - Do not emit `-lc`; current NiuBash exposes `-C` instead of bash/zsh-style login-shell flags.

4. Integrate Codex safety behavior
   - Treat NiuBash as bash-like for command parsing, safe-command checks, dangerous-command checks, approval canonicalization, and apply_patch heredoc interception.
   - Ban broad persisted approval prefixes such as `niu`, `niu -C`, `niu --repl-command`, and `niu -c`.

5. Preserve environment/snapshot behavior
   - Use the portable sh snapshot script for NiuBash when snapshotting is available.
   - Keep PowerShell-only UTF-8 and profile handling scoped to PowerShell.

6. Update protocol comments and tests
   - Document `niu` as a stable shell name.
   - Add targeted tests for detection, argv generation, safety parsing, dangerous parsing, canonicalization, and apply_patch interception.

## Follow-Up Work

- Add a formal user-facing config knob only if upstream wants shell selection to be configurable independently from auto-detection.
- Add NiuBash CI coverage once a stable installer or test binary is available on Windows runners.
- Consider adding `-lc` compatibility in NiuBash itself later; Codex should not depend on it for first-class support.
