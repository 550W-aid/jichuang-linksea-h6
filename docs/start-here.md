# 板卡到手后第一周启动手册

这份手册只解决一件事：拿到板卡之后，如何用最短路径把项目推进到“能下载、能亮屏、能控制、能展示”。

## 起步原则

- 先保最小闭环：`LED + UART + VGA` 跑通后，再接摄像头。
- 控制链先走 `PC UART`，不要一开始就把 `STM32` 一起拉进联调。
- `v1` 只保留 4 个模式：直通/测试图、灰度、低照增强、巡检叠加。
- `直方图均衡化 / 缩放 / 旋转 / 完整 SDRAM` 先不作为起步阶段阻塞项。
- 每完成一个阶段就立刻截图、拍照、记录参数，不把证据链拖到最后。

## 第 0 天：资料和环境归位

1. 把板卡原理图、用户手册放到 `reference/board-docs/`。
2. 把 `OV5640`、`SDRAM` 等数据手册放到 `reference/datasheets/`。
3. 把厂商约束文件放到 `fpga/constraints/`。
4. 把厂商 PLL、SDRAM 控制器、工程模板放到 `fpga/vendor/`。
5. 把 `OV5640` 初始化表放到 `fpga/rtl/camera/ov5640_init_table.mem`。
6. 运行环境自检：

```powershell
python tools/check_startup.py
```

如果需要把外部资料缺口列成待办，直接用 `docs/materials-checklist.md` 打勾。

## 第 1-2 天：最小板级 Bring-Up

只使用 `fpga/rtl/link_sea_h6_bringup_top.v`，目标是先证明下载、时钟、串口和显示链路都可控。

建议顺序：

1. 下载 bitstream，确认板卡上电稳定。
2. 观察 `LED` 心跳。
3. 接上 VGA 显示器，确认彩条或测试图能稳定锁到 `640x480@60`。
4. 接 USB-UART，执行：

```powershell
python tools/uart_control.py --port COM5 ping
python tools/uart_control.py --port COM5 dump
python tools/uart_control.py --port COM5 write --addr 0x02 --value 0x0020
python tools/uart_control.py --port COM5 read --addr 0x02
```

5. 把下载成功、串口回读和 VGA 画面保存到 `evidence/board-bringup/`。

阶段退出标准：

- JTAG 可识别 FPGA
- 下载成功
- `LED` 心跳正常
- `UART ping/read/write/dump` 可重复成功
- VGA 测试图连续运行无异常

## 第 3-4 天：接入比赛主链路

板级基础稳定后，再切到 `fpga/rtl/video_pipeline_top.v`。

此时只做 3 件事：

1. 接入真实约束、PLL 和摄像头初始化。
2. 验证 `OV5640 -> dvp_rx -> 显示` 的最小图像通路。
3. 观察方向、颜色、同步是否正确，优先排掉黑屏、错行、雪花。

如果完整 `SDRAM` 帧缓存一时不能稳定：

- 不要停在这里空耗时间。
- 先保住最小可演示链路，再把完整缓存列为下一阶段任务。

阶段退出标准：

- `cam_init_done` 可判断
- 实时图像能稳定显示
- 断电重启后可重复恢复
- 无持续黑屏、严重色彩错误或明显错行

## 第 5-7 天：冻结 v1 演示功能

`v1` 只演示以下内容：

- 直通/测试图
- 灰度
- 低照增强
- 巡检叠加

现场只保留 3 个主要调参项：

- `brightness_gain`
- `gamma_sel`
- `edge_sel`

推荐的 3 套演示 profile：

```powershell
python tools/apply_profile.py --list
python tools/apply_profile.py --port COM5 --verify grayscale_demo
python tools/apply_profile.py --port COM5 --verify lowlight_demo
python tools/apply_profile.py --port COM5 --verify inspection_overlay
```

直通/测试图模式直接用：

```powershell
python tools/uart_control.py --port COM5 mode --value 0x0000
```

阶段退出标准：

- 暗光场景下低照增强前后差异肉眼可见
- 巡检叠加模式能稳定显示轮廓
- 模式切换和参数调节不引起死机或长时间黑屏

## 证据链同步要求

每完成一个阶段，至少保存以下材料到 `evidence/`：

- 板卡和接线照片
- VGA 或摄像头画面照片
- 串口回读结果
- 当前寄存器配置
- 当前帧率和资源利用率

命名规则和记录模板见 `docs/evidence-template.md`。
