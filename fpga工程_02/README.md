# fpga工程_02

这个目录只存放当前使用的 FPGA 工程。

来源：

- 本地源目录：`C:\Users\Fangr\OneDrive\Desktop\02`

当前保留内容：

1. `hdmi_sdram_1024x600_60Hz.srcs/`
   主要 HDL 源码与约束。
2. `hdmi_sdram_1024x600_60Hz.pr/`
   工程相关配置与分配文件。
3. `*.qpf` `*.qsf` `*.sdc` `*.epr`
   工程入口与约束配置。
4. `codex_run_bitgen.tcl` `codex_run_route.tcl` `debug_sta.tcl`
   调试和实现脚本。
5. `README_LAST_GOOD.md`
   之前保留的版本说明。

后续约定：

1. 以后 FPGA 工程相关改动继续直接更新这个目录。
2. 不提交 `backups/`、`*.runs/`、`db/`、`incremental_db/`、仿真缓存和其他生成物。
