# 给队员的 Codex 提示词（可直接复制）

你现在是集创赛 H6A 工程协作 Codex。请在仓库内执行以下任务，不要只给方案，直接落地代码与报告。

## 背景与路径

- 仓库根目录下交付包路径：
  - `delivery/CCIC_H6A_BOARD_DELIVERY_2026-04-19/`
- 先读：
  1. `delivery/CCIC_H6A_BOARD_DELIVERY_2026-04-19/04_TIMING_SIGNOFF_GATE_138P5MHZ.md`
  2. `delivery/CCIC_H6A_BOARD_DELIVERY_2026-04-19/05_TIMING_CLASSIFICATION_AND_WORK_SPLIT_2026-04-21.md`

## 任务目标

1. 不要动已经签核通过的模块基线（特别是 `02_realtime_resize`，该部分由另一位同学本地推进）。
2. 优先修复并签核以下未通过模块：
   - `A_staging_validated_board_ready/03_fixed_angle_rotate/rtl/fixed_angle_rotate_stream_std.v`
   - `A_staging_validated_board_ready/07_affine_wrapper/rtl/affine_nearest_stream_std.v`
3. 继续覆盖验证以下“未做独立 138.5MHz 签核”的模块（B/C）：
   - `B_external_stream_std_library/**/rtl/*.v`
   - `C_shared_dependencies/rtl/*.v`（需在合理 consuming top 下签核）

## 强制工程规则

1. 时序目标统一：
   - Device: `xc7z020clg400-1`
   - Clock: `138.5MHz`
   - Constraint: `create_clock -name clk -period 7.220 [get_ports clk]`
2. 大型乘法/乘加/地址计算链必须流水线化。
3. 禁止在 RTL 中加入仿真语句（`$display/$finish/error/while` 等）。
4. 不要把所有逻辑塞进单一大文件；可复用模块要拆分。
5. 每个 input/output、每个 always、每个函数都要加清晰注释说明意义。

## 交付要求

1. 每个处理过的模块目录必须新增或更新：
   - `TIMING_STATUS_138P5MHZ.md`
2. 状态文件必须包含：
   - 是否 PASS
   - setup/hold 的 WNS/TNS/WHS/THS
   - 签核边界（参数、lane 数、是否依赖外部存储）
   - 报告文件路径
3. 若不通过，必须明确：
   - 当前最差路径类型（控制/算术/地址/跨模块 net delay）
   - 下一步流水线拆分点

## 工作方式

请直接修改代码、跑约束与实现、生成报告并提交。不要只停留在分析阶段。

