# Teammate Codex Prompt: Virtual Grab Communication Integration

你现在负责把虚拟物品抓取算法本体接入你那边的通信链路，但不要改算法语义本身。

仓库中需要你接手的目录是：

`delivery/CCIC_H6A_BOARD_DELIVERY_2026-04-19/D_reference_not_direct_board_ip/03_virtual_grab_host_algorithm_only`

你的任务边界：

1. 不要重写颜色检测、质心定位、host接口协议本体。
2. 你负责把这套算法接到你那边已有的 UART 或以太网发送接收链路。
3. 你负责整板工程连接、顶层端口连接、约束、时序检查。
4. 若要改协议，只能在外层适配，不要随意改算法内部 `msg_type` 和 payload 字段定义。

你需要优先阅读：

- `delivery/CCIC_H6A_BOARD_DELIVERY_2026-04-19/D_reference_not_direct_board_ip/03_virtual_grab_host_algorithm_only/README.md`
- `delivery/CCIC_H6A_BOARD_DELIVERY_2026-04-19/D_reference_not_direct_board_ip/03_virtual_grab_host_algorithm_only/TIMING_STATUS_138P5MHZ.md`
- `tools/host_pc/virtual_grab_pc_renderer/README.md`

你需要重点使用的 RTL：

- `virtual_grab_host_bridge_top.v`
- `virtual_grab_host_if.v`
- `virtual_grab_cmd_rx.v`
- `virtual_grab_packet_tx.v`

算法当前提供的应用层字节流接口是：

- 输入：`rx_valid`, `rx_data`
- 输出：`tx_valid`, `tx_data`, `tx_last`, `tx_ready`

你的工作内容：

1. 找到你工程里现有的 UART 或网口字节流模块。
2. 把它们和 `virtual_grab_host_bridge_top.v` 的字节流接口对接。
3. 保留两个隐藏按钮输入：
   - `grab_btn_raw`
   - `release_btn_raw`
4. 优先复用仓库里现成的 PC 渲染器 `tools/host_pc/virtual_grab_pc_renderer`，不要无必要重写上位机渲染逻辑。
5. 用你那边的整板工程做综合和时序检查，时钟约束按 `7.22ns`。
6. 如果不过时序，优先在通信外围或顶层路径修，不要先破坏算法边界。

你完成后需要明确汇报：

1. 接的是 UART 还是 Ethernet。
2. 顶层文件路径。
3. 约束文件路径。
4. 138.5MHz 下是否通过时序。
5. 如果不过，最差路径具体在哪里。
