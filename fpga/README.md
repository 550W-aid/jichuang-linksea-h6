# FPGA 工程说明

## 当前顶层分工

- `fpga/rtl/link_sea_h6_bringup_top.v`
  - 用于最小板级 bring-up
  - 目标是先跑通 `LED + UART + VGA 测试图`
- `fpga/rtl/video_pipeline_top.v`
  - 用于比赛主链路和无板卡阶段的 OV5640 读寄存器准备
  - 当前已经接入 `camera_ctrl_regs + ov5640_reg_if + sccb_master`

## 当前无板卡阶段已经固定的事情

- 控制面仍然沿用现有 UART 6 字节协议
- 相机寄存器窗口固定为 `0x10..0x18`
- 读寄存器验证目标固定为 `OV5640 chip ID`
  - `0x300A -> 0x56`
  - `0x300B -> 0x40`
- `sensor_present` 只有在两次芯片 ID 读回都正确时才置位
- `frame_count / line_count / last_pixel / error_count` 已经接入寄存器读回

## 目录说明

- `constraints/`
  - 放正式板卡约束
  - 当前仍等待你们整理官方真实约束文件
- `rtl/`
  - 通用可维护 RTL
  - 与厂商专用 IP 分开存放
- `sim/`
  - 无板卡阶段的离线验证 testbench
- `vendor/`
  - 放厂商工程模板、PLL、SDRAM 控制器等文件

## 当前建议的推进顺序

1. 先运行 `python tools/check_startup.py`
2. 先用 `python tools/run_camera_sims.py --lint-only` 做离线接口检查
3. 板卡到手前继续补约束、初始化表和厂商工程文件
4. 板卡到手后先下载 `link_sea_h6_bringup_top`
5. 再切换到 `video_pipeline_top` 做 `probe-id`

## 当前限制

- `frame_buf_stub` 仍然只是占位，不是正式跨时钟帧缓存
- `OV5640` 完整初始化表还未接入
- `SDRAM`、缩放、旋转、直方图均衡化仍是后续阶段任务
- 当前 `D:\eLinx3.0` 自带的 Verilator 缺少完整 runtime，所以本机默认先做 `lint-only`
