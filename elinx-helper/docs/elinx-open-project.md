# eLinx 工程打开方式

现在的原则很简单：

- `集创` 主分支只放 FPGA 资料、辅助工具和独立整理的 helper
- 真正的 FPGA 工程代码、RTL、testbench 和 eLinx 工程壳不放在这个仓库主分支
- 真正用于 eLinx GUI/CLI 编译的工程，统一放在 ASCII 路径

当前可直接打开的工程在这里：

- [bringup_uart_vga.epr](/C:/Users/Fangr/OneDrive/Desktop/linksea_h6_env/projects/bringup_uart_vga/bringup_uart_vga.epr)
- [camera_regread.epr](/C:/Users/Fangr/OneDrive/Desktop/linksea_h6_env/projects/camera_regread/camera_regread.epr)

## 在 eLinx GUI 里打开

1. 打开 `D:\eLinx3.0\eLinx3.0.exe`
2. 选择 `File -> Project -> Open...`
3. 直接打开上面的 `.epr`
4. 确认顶层分别是：
   - `link_sea_h6_bringup_elinx_top`
   - `video_pipeline_elinx_top`

## 在 Codex/helper 里打开

helper 已经默认指向这个 ASCII 工作区，所以可以直接传项目名：

```bat
elinx-helper\elinx-compile.cmd bringup_uart_vga
elinx-helper\elinx-compile.cmd camera_regread
elinx-helper\elinx-sta.cmd camera_regread
```

如果你想显式传路径，也可以：

```bat
elinx-helper\elinx-compile.cmd C:\Users\Fangr\OneDrive\Desktop\linksea_h6_env\projects\camera_regread\camera_regread.epr
```

## 不再建议的做法

- 不再在 `C:\Users\Fangr\OneDrive\Desktop\集创` 主分支里保留 eLinx 工程壳
- 不再从中文路径直接打开或编译 eLinx 工程
