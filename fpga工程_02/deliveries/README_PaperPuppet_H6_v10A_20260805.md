# PaperPuppet H6 v10A board candidate

This candidate responds to the v9 residual-stripe feedback in
`dev/person-3` commit `9d247500fcc95c681e52e266975b422edb23f681`.

Artifact: `PaperPuppet_H6_v10A_input_reg_stable_3036_54.zip`

ZIP SHA256:

```text
C5275D3C4D4B46B7B3B8AAF024F319681CF90910DB4A909D4022B35BA15DC003
```

JPSK SHA256:

```text
B0B870BC1474D58F586F043342FCAF841182D6D9261DF3B712867EF65489AA52
```

Hypothesis: v9 residual fine stripes were caused by changing OV5640 register
`3036` from the stable reference value `8'h54` to `8'h48`.

Changes from v9:

- `ov5640_cfg.v`: restore `3036 = 8'h54`.
- No camera capture, SDRAM, HDMI timing, overlay, PLL/reset, or pin-constraint
  logic changes.
- Default puppet enable remains `0`.

Local gates passed: synthesis, VQM, H6 pack, zero-error route, timing, and
bitgen. Reported Fmax: sys_clk `76.214 MHz`, ov5640_pclk `80.802 MHz`, HDMI
`_clk4` `97.078 MHz`.

After programming, observe default camera pass-through for at least 60 seconds
before pressing KEY2. Reject for any horizontal stripe, tearing, line streak,
unstable sync, black screen, or pixel displacement.

The requested v10B falling-edge input-sampling experiment was not released:
H6 routing did not converge and no valid v10B JPSK was generated.
