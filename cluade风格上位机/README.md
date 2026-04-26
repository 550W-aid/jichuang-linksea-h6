# cluade风格上位机 工作区

这个目录作为 `Fang_550W` 的固定上传工作区。

当前内容分为两个独立文件夹：

1. `host_gui/`
   当前使用的 Claude 风格上位机代码，来源于本地 `C:\Users\Fangr\OneDrive\Desktop\ccic_host_gui`。
2. `fpga_project_02/`
   当前使用的 FPGA 工程精简版，来源于本地 `C:\Users\Fangr\OneDrive\Desktop\02`。

后续约定：

1. 以后新的上位机版本继续更新到 `host_gui/`。
2. 以后新的 FPGA 工程版本继续更新到 `fpga_project_02/`，或在同级增加新的明确命名工程目录。
3. 上传时默认只保留源码、工程配置、脚本和必要说明文件，不提交 `.venv`、`backups`、综合布线输出、数据库、仿真缓存等生成物。

这次提交保留了可复现和可继续开发所需的核心文件，并刻意排除了以下内容：

1. Python 虚拟环境与缓存目录。
2. FPGA `backups/`、`*.runs/`、`db/`、`incremental_db/`、仿真缓存目录。
3. 其他明显属于本地生成的临时文件。
