# 皮影孙悟空第一阶段返工要求

请先不要直接并入当前总工程。当前阶段目标改为：

**做一个独立的 H6/eLinx 可上板视频链路工程，借鉴当前稳定总工程的视频流链路，把皮影模块跑通。**

也就是说，这一版不是最终总工程集成版，但也不能再交 Quartus/Stratix standalone 空壳。它必须能在我们的 H6 板卡上独立烧录、独立显示 HDMI、独立验证摄像头视频流和皮影替换效果。

## 必须参考的稳定总工程

参考工程路径：

```text
F:\codex\merge_20260723\GrayMedian_D_Work\01_FPGA
```

重点参考这些部分：

```text
ov5640_hdmi_1080p.srcs\sources_1\TOP1.v
ov5640_hdmi_1080p.srcs\sources_1\ov5640\
ov5640_hdmi_1080p.srcs\sources_1\hdmi\
ov5640_hdmi_1080p.srcs\sources_1\SDRAM\
ov5640_hdmi_1080p.srcs\sources_1\system\
ov5640_hdmi_1080p.srcs\sources_1\virtual_grab\
```

核心不是复制所有算法，而是借鉴总工程中已经跑通的：

- OV5640 摄像头采集链路
- RGB565 像素流、坐标、valid/de、帧同步信号
- HDMI 输出链路
- SDRAM/缓存/读写时序组织
- 复位、PLL、时钟域划分
- eLinx 工程结构、约束、bitgen、`.jpsk` 烧录流程

## 第一阶段允许的边界

允许：

- 新建一个独立工程，例如 `PaperPuppet_H6_Standalone_VideoChain`
- 从稳定总工程复制最小视频链路
- 只保留“摄像头输入 -> HDMI 输出 -> 皮影检测/替换”的功能
- 暂时不接入总工程算法切换
- 暂时不接入总上位机
- 暂时不用以太网、旋转、Retinex、多曝光、中值滤波等模块

不允许：

- 再使用 Quartus/Stratix/EP1S80 作为目标工程
- 再提交没有 `.jpsk` 的“参考模块包”
- 再提交未接入真实摄像头/HDMI链路的纯仿真模块
- 使用 `altsyncram` 等 Intel/Quartus 专用原语
- 把 `paper_puppet_standalone.v` 的端口当物理 IO 直接乱绑

## 独立模块应实现的最小功能

上板后 HDMI 应该满足：

1. `puppet_enable = 0`
   - HDMI 正常显示摄像头原始画面。
   - 不允许黑屏、无信号、横闪、错位。

2. `puppet_enable = 1`
   - 摄像头画面仍然作为背景。
   - 检测纯色纸偶区域。
   - 在纸偶 ROI 附近叠加或替换为孙悟空贴图。
   - 至少能看到基础替换效果。

3. 动作第一版可以很简化。
   - 可以先只做待机贴图跟随。
   - 横扫、腾云、火眼可以后续增强。
   - 当前最重要的是：视频链路真实跑通，ROI 坐标对得上，HDMI 能看到效果。

## 必须修改当前 BoardReview 包的问题

上一版 `PaperPuppet_BoardReview_20260803.zip` 的问题如下，请全部修掉：

1. 目标器件错误。
   - 错误：`EP1S80F1508C6`
   - 正确：`EQ6HL130 / CSG484_H`

2. 工具链错误。
   - 错误：Quartus II standalone
   - 正确：eLinx 工程，生成 `.jpsk`

3. 顶层错误。
   - 错误：只有 `paper_puppet_standalone.v`
   - 正确：基于 H6 视频链路顶层，至少接入真实 OV5640 和 HDMI 输出

4. ROM 写法错误。
   - 错误：`altsyncram`
   - 正确：eLinx/EQ6 可综合 ROM/BRAM 写法，或使用现有工程认可的 ROM 初始化方式

5. 交付物错误。
   - 错误：只有源码和仿真报告
   - 正确：必须附带完整 eLinx 工程、`.jpsk`、烧录脚本、日志和说明

## 必须交付的文件

下一版请交：

```text
PaperPuppet_H6_Standalone_VideoChain_YYYYMMDD.zip
```

压缩包内至少包含：

```text
01_FPGA/
  ov5640_hdmi_1080p.epr
  ov5640_hdmi_1080p.qpf
  ov5640_hdmi_1080p.qsf
  ov5640_hdmi_1080p.sdc
  ov5640_hdmi_1080p.srcs/
  ov5640_hdmi_1080p.runs/imple_1/ov5640_hdmi_1080p.jpsk
  program_paper_puppet_jpsk.cmd
  program_paper_puppet_jpsk.tcl

release_manifest.json
BOARD_TEST_STEPS.md
build_log.txt
bitgen_log.txt
sha256.txt
```

## release_manifest.json 必填字段

```json
{
  "project_name": "PaperPuppet_H6_Standalone_VideoChain",
  "stage": "H6 standalone video-chain board candidate",
  "target_device": "EQ6HL130",
  "package": "CSG484_H",
  "toolchain": "eLinx",
  "based_on_reference_project": "F:\\codex\\merge_20260723\\GrayMedian_D_Work\\01_FPGA",
  "top_entity": "TODO",
  "program_file": "01_FPGA/ov5640_hdmi_1080p.runs/imple_1/ov5640_hdmi_1080p.jpsk",
  "program_file_sha256": "TODO",
  "puppet_enable_default": "TODO",
  "expected_behavior_enable_0": "HDMI shows camera pass-through",
  "expected_behavior_enable_1": "HDMI shows camera background with paper puppet replacement/overlay",
  "known_issues": [],
  "rollback_version": "current stable total project C"
}
```

## 验收标准

这版完成后，我这边只验收三件事：

1. 能烧录。
   - `.jpsk` 对应 EQ6HL130。
   - 烧录脚本路径正确。

2. 能出 HDMI。
   - 默认必须能显示摄像头原始画面。
   - 不能上来就是黑屏或无信号。

3. 能看到最小皮影效果。
   - 纸偶进入画面后，HDMI 中能看到孙悟空贴图/替换/叠加跟随。
   - 动作可以先简单，后面再增强。

## 给队友 Codex 的一句话目标

请把上一版 Quartus/Stratix 的皮影参考模块，迁移成一个 **H6/eLinx 独立视频链路上板候选工程**。当前不要求并入总工程，但必须借鉴稳定总工程的 OV5640->SDRAM/视频流->HDMI 链路，生成可烧录 `.jpsk`，并保证默认状态能显示原摄像头画面，开启后能看到基础皮影替换效果。
