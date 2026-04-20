# 仿真目录

当前 `fpga/sim/` 主要服务于“板卡暂时不在手上，但先把 OV5640 读寄存器链路准备好”这个阶段。

## 当前 testbench

- `tb_sccb_master`
  - 验证 SCCB 读、写、NACK、超时
- `tb_ov5640_reg_if`
  - 验证芯片 ID 读回和 `sensor_present`
- `tb_uart_camera_readback`
  - 验证 `UART -> 控制寄存器 -> SCCB -> 读回`
- `tb_video_pipeline_smoke`
  - 验证 `video_pipeline_top` 接入相机寄存器后没有破坏主骨架

## 当前行为模型

- `ov5640_sccb_model.v`
  - 用行为级方式模拟 OV5640 的 SCCB 响应
  - 默认支持 `0x300A / 0x300B` 芯片 ID 读回

## 运行方式

列出仿真目标：

```powershell
python tools/run_camera_sims.py --list
```

执行当前机器可稳定完成的 lint/elaboration：

```powershell
python tools/run_camera_sims.py --lint-only
```

如果后续补齐完整 Verilator runtime，再执行完整仿真：

```powershell
python tools/run_camera_sims.py
```

## 说明

- 当前脚本会自动把 `video_regs.vh` 的宏替换展开成 Verilator 友好的中间源文件
- 生成文件默认落在 `build/sim/<testbench>/generated/`
- 当前 eLinx 自带 Verilator 缺少 `include/verilated.mk`，因此这台机器默认先做 `lint-only`
