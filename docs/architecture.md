# 系统架构

## 1. 目标架构

系统围绕一条统一的视频流接口组织：

- `pixel[15:0]`
- `valid`
- `sof`
- `eol`

这样做的目的是把摄像头接入、算法流水线、OSD 叠加、显示输出全部统一成可插拔模块，避免后期因为模块之间信号风格不一致而返工。

## 2. 数据流

```text
OV5640
  -> cam_init / SCCB
  -> dvp_rx
  -> frame_buf
  -> algo_pipe
  -> osd_overlay
  -> vga_tx
  -> VGA Monitor
```

辅助控制链路：

```text
PC UART / STM32F407
  -> uart_ctrl 或 fsmc_ctrl
  -> ctrl_regs
  -> 各算法和状态模块
```

## 3. 模块职责

### `cam_init`

- 上电后通过 SCCB/I2C 向 `OV5640` 下发寄存器表。
- 负责传感器工作在 `RGB565 + VGA` 输出模式。

### `dvp_rx`

- 在摄像头像素时钟域下采集 `VSYNC/HREF/PCLK/DATA`。
- 将 DVP 输入重组为统一视频流接口。

### `frame_buf`

- 用 `SDRAM` 做乒乓帧缓存或行缓存。
- 负责采集时钟域和显示时钟域之间的解耦。
- 当前仓库中的 `frame_buf_stub.v` 只做接口保留和通路验证。

### `algo_pipe`

- 统一串接基础算法和进阶算法。
- 所有算法都接受相同的流接口，便于按寄存器开关组合演示。

### `ctrl_regs`

- 统一管理模式开关和运行时参数。
- 当前保留寄存器：
  - `mode`
  - `algo_enable`
  - `brightness_gain`
  - `gamma_sel`
  - `scale_sel`
  - `rotate_sel`
  - `edge_sel`
  - `osd_sel`
  - `fps_counter`

### `uart_ctrl / fsmc_ctrl`

- `uart_ctrl` 用于早期联调和无 MCU 状态下的快速调参。
- `fsmc_ctrl` 预留给最终版本 MCU 菜单控制。

### `osd_overlay`

- 叠加运行模式、算法状态和调试边框。
- 首版实现保持轻量，只做状态可视化，不在这里堆复杂图形。

### `perf_counter`

- 统计帧频和心跳。
- 供 OSD、串口状态查询和答辩指标页使用。

## 4. 时钟建议

- `sys_clk`：板上主系统时钟，用于寄存器、UART、控制逻辑。
- `cam_pclk`：来自 `OV5640` 的 DVP 采集时钟。
- `vga_clk`：`640x480@60` 推荐使用 `25.175MHz`，早期 bring-up 可先用接近值。

建议在厂商 PLL IP 接入后，将采集域、控制域、显示域明确隔离，并对跨域信号统一加同步器或 FIFO。

## 5. 当前仓库的实现策略

- `link_sea_h6_bringup_top.v` 优先面向“先亮屏、先可控、先能测”。
- `video_pipeline_top.v` 面向最终比赛版本的模块组织。
- 算法模块分为两类：
  - 已提供可直接运行的轻量算法：灰度、低照增强、简单边缘叠加。
  - 已提供接口骨架、等待补全的算法：直方图均衡化、缩放、旋转、完整帧缓冲。

