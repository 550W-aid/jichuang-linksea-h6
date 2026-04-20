# jichuang-linksea-h6 eLinx Helper 工作区说明

这个仓库目前只用来共享和维护 **eLinx helper**，也就是一组帮助 Codex 或本地终端调用 eLinx 流程的脚本与说明文档。

它不是 FPGA 源码主仓库。RTL、仿真工程、板级资料、比赛文档、截图证据链等内容不放在这个仓库主分支里。

## 这个工作区放什么

主分支 `main` 只保留以下内容：

- `helpers/elinx/`：eLinx 命令行 helper 脚本。
- `docs/elinx-codex-helper.md`：helper 命令的使用说明。
- `docs/elinx-open-project.md`：用 eLinx GUI 打开工程的说明。
- `README.md`：当前工作区说明。
- `.gitignore`：避免把临时文件、构建产物等内容提交到 GitHub。

## 这个工作区不放什么

以下内容不要提交到这个仓库主分支：

- FPGA RTL 源码。
- 仿真 testbench。
- `tools/` 下的串口、寄存器、仿真辅助脚本。
- bitstream、build、log、report 等生成文件。
- 官方资料包、PDF、Excel、图片和比赛附件。

如果后续要多人协作 FPGA 代码，建议单独建立一个 FPGA 工程仓库，不和这个 helper 仓库混在一起。

## 本地路径的意义

本地文件夹是实际工作的地方，GitHub 是共享版本的地方。

也就是说：

```text
本地文件夹 = 工作台
GitHub 仓库 = 云端版本库
```

你在本地修改文件，不会自动改变 GitHub。只有执行下面流程后，GitHub 才会更新：

```powershell
git add README.md
git commit -m "docs: update workspace description"
git push
```

## eLinx 工程建议放在哪里

因为部分 FPGA/eLinx 工具对中文路径不友好，真正用于打开、综合、布局布线和 bitgen 的工程建议放到 ASCII 路径，例如：

```text
C:\Users\Fangr\OneDrive\Desktop\linksea_h6_env\projects
```

helper 默认会从这个路径解析已知工程名。

## 常用 helper 命令

在仓库根目录运行：

```bat
helpers\elinx\elinx-compile.cmd bringup_uart_vga
helpers\elinx\elinx-synth.cmd camera_regread
helpers\elinx\elinx-sta.cmd camera_regread
helpers\elinx\elinx-bitgen.cmd camera_regread
helpers\elinx\elinx-program.cmd camera_regread
```

如果工程根目录换了，可以先设置：

```bat
set ELINX_WORKSPACE_ROOT=C:\fpga\my_workspace
helpers\elinx\elinx-compile.cmd bringup_uart_vga
```

## 分支说明

- `main`：主分支，只保留 eLinx helper 相关内容。
- `integration`：预留整合分支，目前保持空内容。
- `dev/person-1`、`dev/person-2`、`dev/person-3`：预留个人分支，目前保持空内容。

这些空分支只是为以后协作预留位置。当前如果只是维护 helper，直接使用 `main` 即可。
