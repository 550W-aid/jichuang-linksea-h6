# PaperPuppet H6 v11 animated target candidate

Status: `BUILT_NOT_BOARD_VERIFIED`

Feedback source: `dev/person-3` through
`ceaa175561e03eae71a584a960465a82941b844e`.

Artifact: `PaperPuppet_H6_v11_animated_blue_target_20260806.zip`

ZIP SHA256:

```text
A736969014CF3BE85B2BA9169DC434CD4092FAD4B42375B4C609E475093859B9
```

JPSK SHA256:

```text
77BBBF3DDAFC77CC2F2AAAAC0C99D49184D6DFAE1FE2CA0F1E63CEDA0112AA21
```

This release keeps the v10A stable camera baseline (`3036 = 8'h54`, posedge
PCLK capture) and adds animated PaperPuppet states, a state-colored target
marker, and an A4 printable blue recognition target. It remains a standalone
candidate and is not merged into the total project.

Main changed files:

- `paper_puppet_h6_overlay.v`: idle, left, right, jump, and sweep poses.
- `eth_video_rx_to_sdram.v`: registered packet-finalization decision for
  Ethernet timing closure, with protocol behavior preserved.
- `eth_video_rotate_system.v`: isolated camera line-modulo state update for
  PCLK timing closure.
- `tb_paper_puppet_h6_overlay.v`: right/jump/sweep state checks.
- `physical_target/*`: A4 SVG, PNG preview, and print guidance.

Local gates passed:

- ModelSim RTL compile and animation simulation: PASS.
- Ethernet contract tests: 4/4 PASS.
- Quartus synthesis: 0 errors.
- H6 pack/route/bitgen: PASS.
- WNS/WHS/TNS/THS: `0.000 / 0.000 / 0.000 / 0.000 ns`.
- Fmax: sys_clk `66.640 MHz`, camera `93.058 MHz`, Ethernet `134.427 MHz`,
  HDMI `_clk4` `89.518 MHz`.
- ZIP stream verification: 190 entries; extracted JPSK hash matches above.

Board test order is mandatory: first verify default camera pass-through for at
least 60 seconds without pressing KEY2. Only after a clean baseline may KEY2
and the printed target be tested. Full steps and the state-color legend are in
the ZIP's `BOARD_TEST_STEPS.md` and `README.md`.
