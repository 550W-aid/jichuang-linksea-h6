# jichuang-linksea-h6 FPGA 资料与工具工作区

这个仓库的 `main` 分支用于共享 **FPGA 项目相关资料、辅助工具和 eLinx helper**。

它不是 FPGA 工程代码仓库。真正的 RTL、testbench、eLinx 工程壳、综合/布局布线输出、bitstream 等内容不放在这个仓库主分支里。

## 主分支放什么

- `docs/`：FPGA 项目说明、bring-up 清单、架构说明、寄存器表、交付物说明等文字资料。
- `tools/`：串口控制、寄存器访问、profile 应用、gamma LUT 生成、环境检查、仿真辅助等工具脚本。
- `elinx-helper/`：单独整理的 eLinx helper，包含 helper 脚本和 helper 专用文档。
- `README.md`：当前工作区说明。
- `.gitignore`：避免误提交工程代码、构建产物和本地临时文件。

## 主分支不放什么

以下内容不要提交到 `main`：

- FPGA RTL 源码，例如 `fpga/rtl/`。
- 仿真 testbench 和完整仿真工程。
- eLinx、Quartus 或其他 IDE 的工程代码目录。
- `build/`、`out/`、`dist/`、报告、日志、bitstream、bin、sof 等生成产物。
- 安装包、压缩包和体积很大的官方二进制资料。

如果后续要多人协作 FPGA 代码，建议另建一个专门的 FPGA 工程仓库，或者在私有仓库中管理工程代码。

## 目录说明

```text
.
├─ docs/           FPGA 项目资料和流程说明
├─ tools/          FPGA 调试、检查和辅助脚本
└─ elinx-helper/   eLinx helper 脚本与说明文档
```

`elinx-helper/` 是独立文件夹，helper 相关内容都放在这里，避免和普通工具脚本混在一起。

## 本地文件夹和 GitHub 的关系

本地文件夹是实际工作的地方，GitHub 是共享版本的地方：

```text
本地文件夹 = 工作台
GitHub 仓库 = 云端版本库
```

你在本地修改文件，不会自动改变 GitHub。只有执行下面流程后，GitHub 才会更新：

```powershell
git add README.md docs tools elinx-helper
git commit -m "docs: update fpga workspace materials"
git push
```

## eLinx 工程建议放在哪里

因为部分 FPGA/eLinx 工具对中文路径不友好，真正用于打开、综合、布局布线和 bitgen 的工程建议放到 ASCII 路径，例如：

```text
C:\Users\Fangr\OneDrive\Desktop\linksea_h6_env\projects
```

`elinx-helper/` 默认会从这个路径解析已知工程名。

## 常用 helper 命令

在仓库根目录运行：

```bat
elinx-helper\elinx-compile.cmd bringup_uart_vga
elinx-helper\elinx-synth.cmd camera_regread
elinx-helper\elinx-sta.cmd camera_regread
elinx-helper\elinx-bitgen.cmd camera_regread
elinx-helper\elinx-program.cmd camera_regread
```

如果工程根目录换了，可以先设置：

```bat
set ELINX_WORKSPACE_ROOT=C:\fpga\my_workspace
elinx-helper\elinx-compile.cmd bringup_uart_vga
```

## 分支说明

- `main`：FPGA 资料、工具和 eLinx helper。
- `integration`：预留整合分支，目前保持空内容。
- `dev/Fang_550W`：Fang_550W 的个人工作分支，由原 `dev/person-1` 改名而来，目前保持空内容。
- `dev/person-2`、`dev/person-3`：预留个人分支，目前保持空内容。

当前如果只是整理资料、工具和 helper，直接使用 `main` 即可。
