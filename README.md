# CCIC H6A Collaboration Branch

Branch:
- `dev/person-2`

Purpose:
- Share timing signoff status for the current CCIC H6A delivery set.
- Help collaborators avoid integrating modules that are not yet `138.5MHz` clean.
- Split local work clearly between owners.

Read first:
1. `docs/CCIC_H6A_138P5_TIMING_GATE_2026-04-20.md`
2. `docs/COLLABORATOR_CODEX_PROMPT_2026-04-20.md`

Current ownership split:
- `02_realtime_resize`
  - Being fixed locally by the current owner
  - Do not duplicate work on this module unless asked
- Remaining timing-risk modules
  - Hand off to another collaborator and their Codex using the prompt file above

Rule:
- Only call a module `board-ready` or `138.5MHz clean` if it has a fresh timing report recorded in the timing gate document.
