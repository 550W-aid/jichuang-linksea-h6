# SDRAM Reference RTL

这个目录存放一份独立的 SDRAM 控制器 RTL，作为 `main` 分支上的参考资料。

来源：
从 `C:\Users\XYH\Downloads\sdram\sdram` 复制而来，保留原始模块拆分，方便同事查看接口和控制流程。

用途：
- 快速理解 SDRAM 控制器的模块分层。
- 对照查看 `sdram_cmd`、`sdram_ctrl`、`sdram_fifo_ctrl` 等模块职责。
- 作为讨论或移植时的参考实现。

边界说明：
- 这里是参考 RTL，不是当前正在联调的完整工程。
- 当前带 UART 写入/读回验证的 VideoProcess 工程仍放在 `dev/person-3` 分支。
- 如果要看已经跑通的联调说明，请切到 `dev/person-3` 查看 `reports/SDRAM_UART_USAGE.md`。

包含文件：
- `sdram_top.v`
- `sdram_cmd.v`
- `sdram_control.v`
- `sdram_ctrl.v`
- `sdram_data.v`
- `sdram_fifo_ctrl.v`
- `sdram_param.v`
