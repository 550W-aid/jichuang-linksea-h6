# 约束与厂商 IP 接入说明

把厂商提供的实际文件放到这个目录或其子目录，建议结构如下：

```text
fpga/constraints/
|-- link_sea_h6_pins.*
|-- clocks.*
|-- sdram.*
`-- camera_ov5640.*
```

## 必需接入项

- FPGA 管脚约束
- `pix_clk` 或 PLL 生成约束
- SDRAM 引脚和时序约束
- VGA 输出引脚约束
- OV5640 DVP 和 SCCB 引脚约束

## 接入建议

- 顶层优先从 `link_sea_h6_bringup_top.v` 开始，先只接 `UART + VGA + LED`。
- 约束稳定后，再切换到 `video_pipeline_top.v` 并逐步接入摄像头和 SDRAM。
- 厂商专用 PLL、SDRAM 控制器、RAM IP 建议单独放在 `fpga/vendor/`，避免污染可复用 RTL。

