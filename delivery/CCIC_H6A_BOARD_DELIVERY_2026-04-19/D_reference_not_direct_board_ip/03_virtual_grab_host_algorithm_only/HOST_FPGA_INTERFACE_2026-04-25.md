# 虚拟物品抓取宿主机-FPGA接口口径

## 1. 目标

本文档用于冻结虚拟物品抓取初审版本的系统边界。

本版本不追求全自动抓取/释放判定，优先保证：

- 演示稳定
- FPGA实现简单
- 上位机逻辑清楚
- 后续可逐步升级为更自动的方案

## 2. 总体分工

### 2.1 FPGA负责

- 识别蓝色手套中心
- 在标定阶段识别一次红色圆柱中心
- 接收上位机的“标定/开始/停止”命令
- 读取隐藏物理按键
- 周期性上报手的位置和按键事件

### 2.2 上位机负责

- 提供“标定”“开始”“停止”按钮
- 保存标定得到的红色圆柱初始位置
- 渲染虚拟手和虚拟圆柱
- 维护抓取状态机
- 根据手位置和按键事件决定圆柱是否跟手运动

## 3. 演示流程

### 3.1 标定前

- 真实红色圆柱放在桌面指定位置
- 蓝色手套可以暂时不参与
- 上位机处于 `IDLE`

### 3.2 标定

- 用户点击上位机“标定”
- 上位机向FPGA发送一次 `CALIBRATE_REQ`
- FPGA在当前画面中检测红色圆柱中心
- FPGA回传一次 `CALIBRATE_RSP`
- 上位机保存 `red_x0, red_y0`

此后允许把真实红色圆柱从桌面拿走。

### 3.3 开始运行

- 用户点击上位机“开始”
- 上位机向FPGA发送 `START_REQ`
- FPGA开始周期性回传蓝色手套中心
- 上位机进入 `RUNNING`

### 3.4 抓取

- 评委看不到的隐藏按键由操作者在FPGA侧按下
- FPGA发出一次 `GRAB_EVENT`
- 上位机检查当前手位置是否有效
- 可选保护条件：手中心与虚拟圆柱中心距离小于阈值
- 若条件满足，上位机进入 `HOLDING`

### 3.5 释放

- 隐藏按键再次按下
- FPGA发出一次 `RELEASE_EVENT`
- 上位机退出 `HOLDING`
- 虚拟圆柱停留在释放瞬间的位置

## 4. 坐标定义

### 4.1 图像坐标

- 原点：图像左上角
- `x` 向右增大
- `y` 向下增大

### 4.2 手的位置定义

当前版本中：

- 手 = 最大蓝色有效连通域
- 手位置 = 蓝色连通域质心

输出字段：

- `hand_valid`
- `hand_x`
- `hand_y`

可选增强字段：

- `hand_area`

### 4.3 红色圆柱位置定义

当前版本中：

- 红色圆柱 = 标定阶段检测到的红色连通域
- 圆柱位置 = 红色连通域质心
- 半径暂时不由FPGA传输，先在上位机固定

输出字段：

- `red_valid`
- `red_x0`
- `red_y0`

## 5. 抓取状态机

上位机状态机建议如下：

- `IDLE`
- `CALIBRATED`
- `RUNNING`
- `HOLDING`

状态说明：

- `IDLE`：尚未完成标定
- `CALIBRATED`：已经拿到红色圆柱初始位置，但还未开始实时运行
- `RUNNING`：实时显示手位置，圆柱未被抓取
- `HOLDING`：圆柱跟随手运动

### 5.1 状态转移

- `IDLE -> CALIBRATED`
  条件：收到有效 `CALIBRATE_RSP`

- `CALIBRATED -> RUNNING`
  条件：用户点击“开始”

- `RUNNING -> HOLDING`
  条件：收到 `GRAB_EVENT`
  建议保护：`hand_valid == 1` 且手与圆柱距离小于阈值

- `HOLDING -> RUNNING`
  条件：收到 `RELEASE_EVENT`

### 5.2 HOLDING阶段行为

进入 `HOLDING` 时记录：

- `grab_offset_x = object_x - hand_x`
- `grab_offset_y = object_y - hand_y`

后续每帧更新：

- `object_x = hand_x + grab_offset_x`
- `object_y = hand_y + grab_offset_y`

这样虚拟圆柱不会突然跳到手中心，而是保留抓取瞬间的相对位置。

## 6. 通信建议

本阶段建议使用简单固定帧格式，串口和以太网都可复用同一应用层消息定义。

### 6.1 通用帧结构

```
+------------+----------+----------+-------------+----------+
| header[2]  | msg_type | length   | payload[N]  | checksum |
+------------+----------+----------+-------------+----------+
```

字段定义：

- `header`：固定 `16'h55AA`
- `msg_type`：消息类型
- `length`：payload字节数
- `checksum`：对 `msg_type + length + payload` 做8位累加和

## 7. 消息定义

### 7.1 上位机发给FPGA

#### `0x10` `CALIBRATE_REQ`

作用：

- 请求FPGA立即采集一次红色圆柱中心

payload：

- 无

#### `0x11` `START_REQ`

作用：

- 请求FPGA开始周期性发送手位置

payload：

- 无

#### `0x12` `STOP_REQ`

作用：

- 请求FPGA停止周期性发送手位置

payload：

- 无

### 7.2 FPGA发给上位机

#### `0x20` `CALIBRATE_RSP`

作用：

- 返回标定结果

payload定义：

```
byte0   : calib_valid
byte1-2 : red_x0
byte3-4 : red_y0
byte5   : origin_valid
byte6-7 : origin_x
byte8-9 : origin_y
byte10  : green_valid
byte11-12 : green_x
byte13-14 : green_y
```

说明：

- `origin/green` 当前可选传输
- 如果上位机暂时不用参考点，也可以先只用 `red_x0/red_y0`

#### `0x21` `HAND_REPORT`

作用：

- 周期性发送手的位置

payload定义：

```
byte0-1 : frame_id
byte2   : hand_valid
byte3-4 : hand_x
byte5-6 : hand_y
byte7-8 : hand_area   // 可选，当前建议保留
byte9   : grab_event
byte10  : release_event
```

说明：

- `grab_event` 和 `release_event` 为单次脉冲事件
- 正常情况下同一帧内两者不能同时为1

#### `0x22` `STATUS_RSP`

作用：

- 返回FPGA当前工作状态

payload定义：

```
byte0 : run_state
```

建议编码：

- `0x00`：idle
- `0x01`：calibrate_wait
- `0x02`：streaming

## 8. FPGA侧实现要求

### 8.1 标定阶段

- 只需成功上报一次红色圆柱中心
- 标定完成后可以不再继续依赖红色圆柱

### 8.2 运行阶段

- 重点稳定输出蓝色手套中心
- 建议每帧输出一次
- 若视频帧率过高，也可每 `N` 帧输出一次

### 8.3 隐藏按键

按键必须做：

- 消抖
- 上升沿检测
- 单次脉冲输出

建议两个独立事件：

- `grab_event`
- `release_event`

不建议一个按键直接翻转状态，避免上位机与FPGA状态不同步。

## 9. 上位机侧实现要求

### 9.1 界面

至少包含：

- 标定按钮
- 开始按钮
- 停止按钮
- 当前状态显示
- 当前手坐标显示
- 当前圆柱坐标显示

### 9.2 逻辑

- 标定成功后保存 `red_x0, red_y0`
- 开始运行后持续接收 `HAND_REPORT`
- 若未进入 `HOLDING`，圆柱保持静止
- 若进入 `HOLDING`，圆柱跟随手位置更新

### 9.3 安全保护

建议加入：

- 连续若干帧 `hand_valid == 0` 时，保留最后位置但不更新
- `GRAB_EVENT` 触发时若 `hand_valid == 0`，忽略本次抓取
- `RELEASE_EVENT` 无条件允许释放

## 10. 当前版本结论

当前初审版本正式采用以下工程口径：

- 标定与开始由上位机按钮控制
- 抓取与释放由FPGA侧隐藏按键控制
- FPGA只负责检测和发送
- 上位机负责状态机和渲染
- 红色圆柱只在标定阶段检测一次
- 运行阶段重点跟踪蓝色手套中心

这套方案优先保证“能演示、能解释、能稳定通过初审”，后续再升级为自动抓取/自动释放版本。
