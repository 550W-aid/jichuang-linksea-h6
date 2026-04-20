# 外部资料与厂商文件归档清单

这份清单用于把“板卡到手后必须补齐的外部资料”落到固定路径，避免团队成员各自保存、后期难以接手。

## 资料归档位置

| 类别 | 内容 | 建议放置路径 | 完成标准 |
|---|---|---|---|
| 板卡资料 | 原理图、用户手册、开发板说明 | `reference/board-docs/` | 任一队员接手都能找到板卡接口和引脚说明 |
| 数据手册 | `OV5640`、`SDRAM`、关键器件手册 | `reference/datasheets/` | 能查到初始化、时序和电气参数 |
| 管脚约束 | FPGA 管脚约束、时钟约束 | `fpga/constraints/` | 已可用于当前顶层综合和下载 |
| 摄像头初始化表 | `OV5640` 的 `RGB565 + VGA` 初始化表 | `fpga/rtl/camera/ov5640_init_table.mem` | 可直接被后续 `cam_init` 模块接入 |
| 厂商 PLL/IP | PLL、SDRAM 控制器、工程模板 | `fpga/vendor/` | 目录下已能区分 `pll/`、`sdram/`、`project/` |
| MCU 工程 | `CubeMX/CubeIDE` 生成工程 | `mcu/` 或外部工程目录 | 已明确最终合并点和总线实现方式 |

## 启动前最少要确认的 5 项外部资料

- [ ] `Link-Sea-H6` 板卡原理图
- [ ] `Link-Sea-H6` 用户手册或接口说明
- [ ] `OV5640` 初始化表或可工作的参考配置
- [ ] 板载 `SDRAM` 型号与时序参数
- [ ] `STM32F407 <-> FPGA` 地址映射、互联原理或示例

## 本机环境最少要确认的 6 项工具

- [ ] `eLinx Design Suite`
- [ ] USB-JTAG 驱动
- [ ] USB-UART 驱动
- [ ] `STM32CubeIDE` 或 `STM32CubeCLT`
- [ ] `Python 3`
- [ ] Python 包 `pyserial`

建议在准备完后执行：

```powershell
python tools/check_startup.py
```

## 推荐的目录使用约定

- `reference/` 只放外部参考资料，不放自己编写的比赛文档。
- `fpga/constraints/` 只放真实约束，不把临时笔记混进去。
- `fpga/vendor/` 只放厂商相关内容，避免与通用 RTL 混杂。
- `evidence/` 只放截图、照片、视频和指标表，不放过程草稿。
