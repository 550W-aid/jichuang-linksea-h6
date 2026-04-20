# 5 分钟演示脚本

## 0:00 - 0:30 项目开场

- 展示板卡、摄像头、显示器和整体接线
- 说明项目目标：基于国产 FPGA 实现实时低照增强巡检图像处理系统
- 演示前先准备好 `evidence/` 中的对比图和指标截图，避免现场临时翻找

## 0:30 - 1:20 基础视频链路

- 展示实时画面已经跑通
- 说明链路为 `OV5640 -> FPGA -> VGA`
- 快速切换直通、灰度等基础模式
- 推荐命令：`python tools/uart_control.py --port COM5 mode --value 0x0000`
- 推荐命令：`python tools/apply_profile.py --port COM5 --verify grayscale_demo`

## 1:20 - 2:30 低照增强

- 把场景切到暗光环境
- 对比增强前后图像亮度和可见性
- 展示 `brightness_gain`、`gamma_sel` 实时调节效果
- 推荐命令：`python tools/apply_profile.py --port COM5 --verify lowlight_demo`

## 2:30 - 3:20 巡检叠加

- 打开边缘叠加或巡检辅助模式
- 展示目标轮廓在低照场景下更清晰
- 说明这个模式适用于低照巡检或辅助观察
- 推荐命令：`python tools/apply_profile.py --port COM5 --verify inspection_overlay`

## 3:20 - 4:10 控制与工程实现

- 展示串口或 STM32 控制界面
- 演示模式切换、参数下发和 FPS 状态读取
- 简述 FPGA 和 ARM 的职责划分

## 4:10 - 5:00 指标总结

- 展示资源利用率和帧率
- 展示项目亮点页
- 总结创新点：国产 FPGA、实时视频处理、低照增强、可调巡检辅助
