# jichuang-linksea-h6

This branch currently carries a trimmed `VideoProcess` FPGA project snapshot suitable for collaboration on the H6 image-processing path.

## Current status

- Top-level entity: `VP_Top`
- Current integration mode: SDRAM and Ethernet are tied off in top-level logic, and the active display path is a minimal VGA demo chain
- Active image chain: `grayscale_stream_std -> window3x3_stream_std -> gaussian3x3_stream_demo`
- Project GUI metadata has been aligned so eLinx no longer defaults the top module to `arp`
- Latest checked implementation timing summary is copied under `reports/imple_1/`
- Both `iverilog` and ModelSim top-level video simulations now pass on the workstation

## What is included

- `VideoProcess.epr`, `VideoProcess.qpf`, `VideoProcess.qsf`
- `VideoProcess.srcs/` design sources, IP wrappers, constraints, and simulation files
- A trimmed copy of `CCIC_H6A_TRIED_ALGO_ARCHIVE_2026-04-19` that keeps:
  - `rtl/`
  - `tb/`
  - `scripts/`
  - `docs/`

## What is intentionally excluded

- `VideoProcess.runs/`
- `db/`
- `incremental_db/`
- Large generated sample data, golden hex dumps, and runtime caches under the algorithm archive

## Notes for next work

- If you want to rerun synthesis or implementation, regenerate run artifacts locally after opening this project in eLinx/Quartus.
- This collaboration branch keeps the active minimal video-processing project; the fuller workstation copy under `D:\Work\FPGA\eLinx\VideoProc` still carries the broader board-level constraints and historical handoff material.
- The default simulation entry in `VideoProcess.epr` now points to `VP_video_tb`.
- `pll_1.v` now has a `SIM_PLL_STUB` branch for lightweight `iverilog` simulation while preserving the original vendor `altpll` path for synthesis and ModelSim.
- Use `scripts/sim/run_vp_top_iverilog.ps1` for the fast stubbed top-level run and `scripts/sim/run_vp_top_modelsim.ps1` for the Quartus-library vendor simulation run.
- The original full archive on the workstation contains much larger reference data that was not committed to keep the branch lightweight.
