# Timing Status: C_shared_dependencies

Status:
- `DEPENDENCY LAYER ONLY`

Meaning:
- Files in `C_shared_dependencies/rtl` are shared building blocks.
- They are not standalone board-ready top modules.
- Do not describe this folder as `138.5MHz signed off` by itself.

Rule for collaborators:
- Timing signoff belongs to the consuming top module, not to this folder in isolation.
