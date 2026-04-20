# eLinx Codex Helper

这组 helper 的目标是让 Codex 在 Windows 下稳定驱动本地 `eLinx 3.0`，同时把真正的工程编译留在 ASCII 路径里。

## 现在的约定

- 源码维护目录：`C:\Users\Fangr\OneDrive\Desktop\集创`
- ASCII 工程目录：`C:\Users\Fangr\OneDrive\Desktop\linksea_h6_env\projects`
- eLinx 安装目录默认：`D:\eLinx3.0`

helper 已经全部收拢到：

- [helpers/elinx](/C:/Users/Fangr/OneDrive/Desktop/集创/helpers/elinx)

## 脚本入口

- [elinx-env.cmd](/C:/Users/Fangr/OneDrive/Desktop/集创/helpers/elinx/elinx-env.cmd)
- [elinx-synth.cmd](/C:/Users/Fangr/OneDrive/Desktop/集创/helpers/elinx/elinx-synth.cmd)
- [elinx-compile.cmd](/C:/Users/Fangr/OneDrive/Desktop/集创/helpers/elinx/elinx-compile.cmd)
- [elinx-sta.cmd](/C:/Users/Fangr/OneDrive/Desktop/集创/helpers/elinx/elinx-sta.cmd)
- [elinx-bitgen.cmd](/C:/Users/Fangr/OneDrive/Desktop/集创/helpers/elinx/elinx-bitgen.cmd)
- [elinx-program.cmd](/C:/Users/Fangr/OneDrive/Desktop/集创/helpers/elinx/elinx-program.cmd)
- [elinx-tcl.cmd](/C:/Users/Fangr/OneDrive/Desktop/集创/helpers/elinx/elinx-tcl.cmd)
- [elinx-server-start.cmd](/C:/Users/Fangr/OneDrive/Desktop/集创/helpers/elinx/elinx-server-start.cmd)
- [elinx-server-client.tcl](/C:/Users/Fangr/OneDrive/Desktop/集创/helpers/elinx/elinx-server-client.tcl)

## 工程解析规则

- public 项目名优先按 `.epr` 理解
- native `.epr` 优先走原生 eLinx shell flow
- 如果 native synth 不适配，且工程目录下存在同名 `.qpf`，会自动回退到 `quartus_map`
- helper 默认把已知项目名映射到 `linksea_h6_env\projects\<project>\<project>.epr`

当前已知项目：

- [bringup_uart_vga.epr](/C:/Users/Fangr/OneDrive/Desktop/linksea_h6_env/projects/bringup_uart_vga/bringup_uart_vga.epr)
- [camera_regread.epr](/C:/Users/Fangr/OneDrive/Desktop/linksea_h6_env/projects/camera_regread/camera_regread.epr)

## 常用命令

初始化环境：

```bat
helpers\elinx\elinx-env.cmd
```

按项目名运行：

```bat
helpers\elinx\elinx-synth.cmd bringup_uart_vga
helpers\elinx\elinx-compile.cmd bringup_uart_vga
helpers\elinx\elinx-sta.cmd bringup_uart_vga
helpers\elinx\elinx-bitgen.cmd bringup_uart_vga
```

按绝对路径运行：

```bat
helpers\elinx\elinx-compile.cmd C:\Users\Fangr\OneDrive\Desktop\linksea_h6_env\projects\camera_regread\camera_regread.epr
helpers\elinx\elinx-sta.cmd C:\Users\Fangr\OneDrive\Desktop\linksea_h6_env\projects\camera_regread\camera_regread.epr
```

Tcl 透传：

```bat
helpers\elinx\elinx-tcl.cmd --tcl_eval "puts [pwd]"
helpers\elinx\elinx-tcl.cmd -t C:\fpga\scripts\report_top.tcl
```

下载器枚举与烧录：

```bat
helpers\elinx\elinx-program.cmd --list-cables
helpers\elinx\elinx-program.cmd --list-devices "USB-Blaster"
helpers\elinx\elinx-program.cmd "USB-Blaster" JTAG C:\path\to\output.sof
```

## 工作区切换

如果你以后把 ASCII 工程目录搬走了，先设置：

```bat
set ELINX_WORKSPACE_ROOT=C:\fpga\new_workspace
helpers\elinx\elinx-compile.cmd bringup_uart_vga
```

只要 `ELINX_WORKSPACE_ROOT\projects\bringup_uart_vga\bringup_uart_vga.epr` 这种结构还在，helper 就能继续按项目名解析。

## 当前边界

- `集创` 这个目录不再保留可编译的 eLinx 工程壳
- helper 只负责调原生 eLinx 与 Quartus-compatible backend，不替代 GUI 编辑工程
- `elinx-server-client.tcl` 只暴露受限的 `project/device/cmp/sim` 能力，不承诺任意 Tcl 命令透传
