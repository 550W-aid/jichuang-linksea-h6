# PaperPuppet H6 v9 board candidate

This candidate responds to board feedback commit
`fb6af9769972a62acaac1c76678e88970afbd305`: the previous JPSK programmed,
but the default camera image showed severe horizontal tearing.

Download `PaperPuppet_H6_Standalone_VideoChain_20260805_v9.zip` and verify:

```text
SHA256  D16E699449FF6C6DF9040122A531680C105E159EE153421BA9914A8CB0579A36
```

Program file inside the ZIP:

```text
01_FPGA/ov5640_hdmi_1080p.runs/imple_1/ov5640_hdmi_1080p.jpsk
```

JPSK SHA256:

```text
3813BD9CC9CC6CAFA5503FBD0019AAFE1DAF307B1C78B5EBFF86D73B606C4F6A
```

Target: `EQ6HL130 / CSG484_H`, eLinx 3.0.7.

The stable OV5640 -> SDRAM -> HDMI structure remains the default path. Puppet
enable resets to `0`. The standalone build bypasses the merged optional video
features, registers OV5640 inputs in the PCLK IO domain, and configures the
camera for an approximately 74.7 MHz PCLK.

Local release gates passed:

- PaperPuppet RTL simulation passed.
- H6 synthesis and pack passed.
- Route errors: `0`.
- `sys_clk`: `69.156 MHz`.
- `ov5640_pclk`: `79.076 MHz`.
- HDMI `_clk4`: `88.731 MHz`.
- Effective path minimum slack: `0.495 ns`.
- Bitgen passed.

Hardware validation is still required. After programming, reset/power-cycle and
observe default camera pass-through for at least 60 seconds. Reject immediately
for tearing, line streaks, unstable sync, black screen, or pixel displacement.
Only after that gate passes should KEY2 and the puppet overlay be tested.
