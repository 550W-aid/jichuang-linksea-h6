# Frame Protocol

渲染器统一使用“单行 JSON 一帧”的协议，传输层可为：

- TCP
- 串口 UART / USB CDC
- 文件回放

每一行必须是一个完整 JSON 对象，以 `\n` 结尾：

```json
{"frame_id":1,"origin":{"x":960,"y":540},"green":{"x":1080,"y":540,"radius":30},"red":{"x":850,"y":610,"radius":42},"blue":{"x":810,"y":560,"radius":55}}
```

## 字段说明

- `frame_id`：帧编号
- `origin`：`O` 点像素坐标
- `green`：绿色参考区中心与半径
- `red`：红色圆柱体中心与半径
- `blue`：蓝色手套中心与半径

## 推荐做法

### FPGA -> 电脑

建议 FPGA 最终输出 ASCII 文本行：

```text
{"frame_id":123,"origin":{"x":960,"y":540},"green":{"x":1100,"y":540,"radius":36},"red":{"x":850,"y":620,"radius":42},"blue":{"x":800,"y":560,"radius":58}}
```

这样 Python、MATLAB、Qt 都能直接解析。

### MATLAB

- 若 MATLAB 做上位机，推荐 `serialport` 读取 FPGA 串口，再经 `tcpclient` 转发给渲染器。
- 也可直接由 MATLAB 生成或修改 JSON 帧，再发送给渲染器。

### Qt

- 若 Qt 做上位机，串口端使用 `QSerialPort`
- 渲染器对接端使用 `QTcpSocket`
- 若要直接在 Qt 中重写渲染，也建议保留同一帧协议
