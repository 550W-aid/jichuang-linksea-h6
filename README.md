# jichuang-linksea-h6 eLinx Helper

This repository now keeps only the Codex/eLinx helper scripts and their helper
documentation for the Link-Sea-H6 workflow.

The FPGA source project should live outside this repository, preferably in an
ASCII-only path such as:

```text
C:\Users\Fangr\OneDrive\Desktop\linksea_h6_env\projects
```

## Contents

- `helpers/elinx/`: local helper commands for invoking eLinx flows.
- `docs/elinx-codex-helper.md`: command-line helper usage.
- `docs/elinx-open-project.md`: GUI project opening notes.

## Helper Commands

Run helper commands from the repository root:

```bat
helpers\elinx\elinx-compile.cmd bringup_uart_vga
helpers\elinx\elinx-synth.cmd camera_regread
helpers\elinx\elinx-sta.cmd camera_regread
helpers\elinx\elinx-bitgen.cmd camera_regread
helpers\elinx\elinx-program.cmd camera_regread
```

By default, helper commands resolve known project names under:

```text
C:\Users\Fangr\OneDrive\Desktop\linksea_h6_env\projects
```

To use another project root for the current terminal session:

```bat
set ELINX_WORKSPACE_ROOT=C:\fpga\my_workspace
helpers\elinx\elinx-compile.cmd bringup_uart_vga
```
