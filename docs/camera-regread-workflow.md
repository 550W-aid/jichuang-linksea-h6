# 无板卡阶段 OV5640 读寄存器工作流

## 当前目标

在 FPGA 板卡暂时不在手上的情况下，先把下面这条验证链的工程骨架和离线验证跑通：

`PC UART -> FPGA 控制寄存器 -> SCCB -> OV5640`

本阶段完成标准不是“板上已经有图像”，而是：

- `eLinx` 工程选择和 revision 划分明确
- SCCB 读写寄存器通路已经落到 RTL
- `UART -> 相机寄存器` 的高层脚本已经准备好
- 离线仿真至少能覆盖 SCCB、寄存器读回和顶层冒烟路径
- 板卡到手后可以直接执行 `probe-id`

## 固定 revision 划分

| Revision | 顶层 | 用途 |
|---|---|---|
| `bringup_uart_vga` | `fpga/rtl/link_sea_h6_bringup_top.v` | 先确认 UART、寄存器、VGA 测试图和下载链路 |
| `camera_regread` | `fpga/rtl/video_pipeline_top.v` | 承接 OV5640 的 SCCB 读写、DVP 像素活动统计和后续图像链路 |

## 当前新增的 FPGA 相机寄存器

| 地址 | 名称 | 说明 |
|---|---|---|
| `0x10` | `cam_cmd` | `0x0001` 读, `0x0002` 写, `0x0004` 清状态 |
| `0x11` | `cam_reg_addr` | OV5640 16 位寄存器地址 |
| `0x12` | `cam_wr_data` | 待写入数据，低 8 位有效 |
| `0x13` | `cam_rd_data` | 读回数据，低 8 位有效 |
| `0x14` | `cam_status` | `busy/done/ack_ok/nack/timeout/init_done/sensor_present/data_active` |
| `0x15` | `cam_frame_count` | 帧计数 |
| `0x16` | `cam_line_count` | 行计数 |
| `0x17` | `cam_last_pixel` | 最近一次有效 RGB565 像素 |
| `0x18` | `cam_error_count` | SCCB 错误累计 |

## 当前脚本入口

### 1. 环境检查

```powershell
python tools/check_startup.py
```

### 2. 列出并运行离线仿真

```powershell
python tools/run_camera_sims.py --list
python tools/run_camera_sims.py --lint-only
python tools/run_camera_sims.py
```

说明：

- 目前这台机器上的 `D:\eLinx3.0` 自带 Verilator 可以稳定执行 `lint-only`
- 如果后续补齐完整 Verilator runtime，`python tools/run_camera_sims.py` 就可以直接继续跑可执行仿真
- 如果当前只看到 `include/verilated.mk` 缺失告警，先不要卡在这里，继续完成无板卡阶段的接口和脚本准备

### 3. 板卡到手后的首个读寄存器命令

```powershell
python tools/ov5640_reg_access.py --port COM5 probe-id
```

### 4. 手动读写 OV5640 寄存器

```powershell
python tools/ov5640_reg_access.py --port COM5 read --reg 0x300A
python tools/ov5640_reg_access.py --port COM5 write --reg 0x3100 --value 0xA5
python tools/ov5640_reg_access.py --port COM5 status
```

## RTL 结构说明

- `fpga/rtl/camera/sccb_master.v`
  - 负责单次 SCCB 读写时序
- `fpga/rtl/camera/ov5640_reg_if.v`
  - 负责命令触发、状态位、芯片 ID 检查和像素活动计数
- `fpga/rtl/control/camera_ctrl_regs.v`
  - 负责把 `0x10..0x18` 的相机寄存器挂到当前 UART 控制平面
- `fpga/rtl/video_pipeline_top.v`
  - 负责把相机寄存器、SCCB 和 DVP 接到比赛主链路骨架

## 当前仿真覆盖

| Testbench | 目标 |
|---|---|
| `tb_sccb_master` | 验证 SCCB 读、写、NACK、超时 |
| `tb_ov5640_reg_if` | 验证芯片 ID 读回、`sensor_present` 和像素活动计数 |
| `tb_uart_camera_readback` | 验证 UART 写地址、启动读、轮询状态、读回数据 |
| `tb_video_pipeline_smoke` | 验证顶层 `video_pipeline_top` 接入后基础链路不被破坏 |

## 板卡到手后的首轮现场步骤

1. 通过 Type-C 连接板卡并确认下载器和串口枚举正常。
2. 摄像头插在 `J1_Camera1`，不是 `J2_Camera2`。
3. 先下载 `bringup_uart_vga` revision，确认 UART 和 VGA 测试图正常。
4. 再切到 `camera_regread` revision。
5. 运行 `python tools/ov5640_reg_access.py --port COMx probe-id`。
6. 只有 `0x300A -> 0x56`、`0x300B -> 0x40` 且 `sensor_present=1` 时，才进入初始化表和实时图像阶段。

## 当前默认不做的事情

- 不把 `STM32/FSMC` 作为首轮主控链路
- 不要求此阶段完成完整 `OV5640` 初始化表
- 不要求此阶段完成完整 `SDRAM` 帧缓存
- 不要求此阶段完成缩放、旋转、直方图均衡化
