# Link-Sea-H6A 板卡速查表

这份速查表把当前无板卡阶段最需要反复查的官方信息收成一个入口，避免开发时在多个 PDF、Excel 和 FAQ 之间来回翻。

## 官方单一真源

当前默认以本地 `集创赛-中科亿海微杯/` 目录里的 5 份资料为准：

- `集创赛-中科亿海微杯/中科亿海微Link-Sea-H6A图像处理套件快速使用指南.pdf`
- `集创赛-中科亿海微杯/Link_Sea_H6A板卡接口IO对应关系表.xlsx`
- `集创赛-中科亿海微杯/常见问题答复.xls`
- `集创赛-中科亿海微杯/板卡硬件原理图/集创赛EQ6HL130核心板-原理图.pdf`
- `集创赛-中科亿海微杯/板卡硬件原理图/集创赛图像底板-原理图.pdf`

## 固定结论

- FPGA 器件固定为 `EQ6HL130`
- 开发软件当前先使用本机已安装的 `D:\eLinx3.0`，版本为 `eLinx 3.0.7`
- 官方材料提到推荐版本为 `eLinx 3.0.8`，只有当器件库、工程模板或下载链路不兼容时再升级
- 摄像头默认走 `J1_Camera1`
- `J1_Camera1` 使用 `CMOS_*` 信号
- `J2_Camera2` 使用 `CAM_*` 信号
- 当前显示路径默认走 `J4_VGA`
- 板上 `STM32F407` 与 FPGA 通过 `FSMC` 互联，但本轮先不把 MCU 纳入主验证链

## 起步阶段固定接口

| 功能 | 信号 | 管脚 | 备注 |
|---|---|---|---|
| 系统时钟 | `SYS_50M` | `AB12` | 无板卡阶段所有系统级时序都按它假定 |
| FPGA UART RX | `FPGA_UART_RX` | `AB15` | 下载/调试复用链路 |
| FPGA UART TX | `FPGA_UART_TX` | `Y15` | 下载/调试复用链路 |
| VGA 同步 | `VGA_HSYNC` | `K8` | `J4_VGA` |
| VGA 同步 | `VGA_VSYNC` | `K7` | `J4_VGA` |
| 摄像头像素时钟 | `CMOS_PCLK` | `K17` | `J1_Camera1` |
| 摄像头场同步 | `CMOS_VSYNC` | `R16` | `J1_Camera1` |
| 摄像头行同步 | `CMOS_HREF` | `R19` | `J1_Camera1` |
| 摄像头 SCCB SCL | `CMOS_SCL` | `R15` | `J1_Camera1` |
| 摄像头 SCCB SDA | `CMOS_SDA` | `P17` | `J1_Camera1` |
| 摄像头时钟输出 | `CMOS_XCLK` | `L17` | `J1_Camera1` |
| 摄像头复位 | `CMOS_RESET` | `AB20` | `J1_Camera1` |
| 摄像头掉电 | `CMOS_PWDN` | `V20` | `J1_Camera1` |

## Camera1 8-bit DVP 数据脚

| 信号 | 管脚 |
|---|---|
| `CMOS_D0` | `V19` |
| `CMOS_D1` | `Y20` |
| `CMOS_D2` | `P18` |
| `CMOS_D3` | `R17` |
| `CMOS_D4` | `Y19` |
| `CMOS_D5` | `AB19` |
| `CMOS_D6` | `T18` |
| `CMOS_D7` | `P19` |

## VGA 输出说明

- 当前仓库 `RGB565 + HS + VS` 的输出接口与 `J4_VGA` 对应
- 完整 `VGA_D0..VGA_D15` 管脚请直接查 `Link_Sea_H6A板卡接口IO对应关系表.xlsx`
- 无板卡阶段默认先不生成正式约束文件，只把信号命名和接口方向固定下来

## FAQ 提炼结论

- 不依赖 `Vivado`
- 不依赖 `HLS`
- 官方不提供现成的摄像头到显示 demo
- 官方不提供现成的 UART/摄像头驱动
- 核心算法必须放在 FPGA 侧
- 可使用 `STM32` 做辅助控制，但不是本轮主目标
- 当前板卡路线以 `SDRAM` 为主，不走 DDR/MIG 思路

## 当前建议的工程固定项

- `bringup_uart_vga` revision: 顶层固定为 `fpga/rtl/link_sea_h6_bringup_top.v`
- `camera_regread` revision: 顶层固定为 `fpga/rtl/video_pipeline_top.v`
- 仿真入口固定为 `python tools/run_camera_sims.py`
- 板卡到手后的首个现场命令固定为 `python tools/ov5640_reg_access.py --port COMx probe-id`
