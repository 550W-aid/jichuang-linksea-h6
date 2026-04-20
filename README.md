# 集创工作区

这个目录现在只承担两件事：

- 维护 FPGA 源码、仿真和辅助脚本
- 存放 Codex/eLinx helper 与说明文档

由于当前路径包含中文，`eLinx` 工程不再放在这里直接编译。真正用于打开、综合、布局布线和 bitgen 的工程，统一放到同级 ASCII 工作区：

- `C:\Users\Fangr\OneDrive\Desktop\linksea_h6_env\projects`

## 当前目录划分

- `fpga/`
  - RTL、仿真、约束、vendor 占位内容
- `tools/`
  - UART、寄存器访问、仿真和离线辅助脚本
- `helpers/elinx/`
  - Codex 调 eLinx 的本地 helper
- `docs/`
  - helper 使用说明和工程打开说明
- `archive/`
  - 暂时不参与 FPGA 编码主线的资料和旧内容

## Helper 入口

helper 已经收拢到单独目录：

- [helpers/elinx/elinx-env.cmd](/C:/Users/Fangr/OneDrive/Desktop/集创/helpers/elinx/elinx-env.cmd)
- [helpers/elinx/elinx-synth.cmd](/C:/Users/Fangr/OneDrive/Desktop/集创/helpers/elinx/elinx-synth.cmd)
- [helpers/elinx/elinx-compile.cmd](/C:/Users/Fangr/OneDrive/Desktop/集创/helpers/elinx/elinx-compile.cmd)
- [helpers/elinx/elinx-sta.cmd](/C:/Users/Fangr/OneDrive/Desktop/集创/helpers/elinx/elinx-sta.cmd)
- [helpers/elinx/elinx-bitgen.cmd](/C:/Users/Fangr/OneDrive/Desktop/集创/helpers/elinx/elinx-bitgen.cmd)
- [helpers/elinx/elinx-program.cmd](/C:/Users/Fangr/OneDrive/Desktop/集创/helpers/elinx/elinx-program.cmd)
- [helpers/elinx/elinx-tcl.cmd](/C:/Users/Fangr/OneDrive/Desktop/集创/helpers/elinx/elinx-tcl.cmd)

helper 默认会把已知工程名解析到：

- `C:\Users\Fangr\OneDrive\Desktop\linksea_h6_env\projects`

也就是说，现在直接传项目名就行：

```bat
helpers\elinx\elinx-compile.cmd bringup_uart_vga
helpers\elinx\elinx-compile.cmd camera_regread
helpers\elinx\elinx-sta.cmd camera_regread
```

如果以后 ASCII 工作区改位置，可以先设置：

```bat
set ELINX_WORKSPACE_ROOT=C:\fpga\my_workspace
helpers\elinx\elinx-compile.cmd bringup_uart_vga
```

## 现在的建议工作方式

1. 在 `集创` 里改 RTL、约束、仿真脚本和 helper。
2. 在 `linksea_h6_env\projects` 里打开 `.epr` 或跑 helper。
3. 非 FPGA 主线资料如果要查，去 `archive/`。

详细命令见 [docs/elinx-codex-helper.md](/C:/Users/Fangr/OneDrive/Desktop/集创/docs/elinx-codex-helper.md)。
GUI 打开工程见 [docs/elinx-open-project.md](/C:/Users/Fangr/OneDrive/Desktop/集创/docs/elinx-open-project.md)。
