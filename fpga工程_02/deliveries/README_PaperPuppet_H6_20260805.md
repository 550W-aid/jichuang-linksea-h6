# PaperPuppet H6 board candidate

Download `PaperPuppet_H6_Standalone_VideoChain_20260805.zip` and verify:

```text
SHA256  9940B449C6C112D1DB2603A5FC2C0880079756146040CBA4FF95FF6A64807573
```

The ZIP contains the complete source/constraint project subset needed to reopen and rebuild the independent candidate, plus the generated programming file:

```text
01_FPGA/ov5640_hdmi_1080p.runs/imple_1/ov5640_hdmi_1080p.jpsk
```

JPSK SHA256:

```text
0355DDDE969D8B7335E88E040769DA2A086EA4D25040005CF80547F30DFF84D7
```

Target: `EQ6HL130 / CSG484_H`, eLinx 3.0.7. Run `01_FPGA/program_paper_puppet_jpsk.cmd` to program, then follow `BOARD_TEST_STEPS.md`.

This artifact has passed RTL simulation, H6 native pack, zero-error routing, bitgen, ZIP extraction, and hash checks. Hardware validation remains pending.
