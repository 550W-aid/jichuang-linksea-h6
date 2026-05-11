# codex任务完成的桌面与手机提示：桌面端与仓库复用说明

## 目标

把 Codex 任务状态发到：

- 当前 Windows 桌面
- 你自己的手机 `ntfy`

并且让仓库里的其它脚本或进程可以直接复用。

## 工具路径

主目录：

```text
tools/host_pc/codex_task_notify/
```

主入口：

```text
tools/host_pc/codex_task_notify/main.py
```

PowerShell 包装：

```text
tools/host_pc/codex_task_notify/codex-task-notify.ps1
```

## 初始化配置

```powershell
python tools/host_pc/codex_task_notify/main.py init --server https://ntfy.sh --topic <你的topic> --title-prefix Codex --long-run-minutes 15 --desktop-toast on
```

默认配置文件位置：

```text
%USERPROFILE%\.codex-task-notify\config.json
```

测试时可以通过环境变量覆盖：

```powershell
$env:CODEX_TASK_NOTIFY_CONFIG = "D:\temp\codex-task-notify.json"
```

## 事件类型

当前默认优先级：

- `success = 3`
- `manual-attention = 4`
- `long-run-finished = 4`
- `failure = 5`

含义：

- `success`
  普通完成提醒
- `manual-attention`
  需要立刻看一下
- `long-run-finished`
  长时间任务结束
- `failure`
  失败或中断

## 直接发送

```powershell
python tools/host_pc/codex_task_notify/main.py event --type success --message "任务完成：已输出结果"
python tools/host_pc/codex_task_notify/main.py event --type manual-attention --message "需要你确认：是否继续"
```

## 包装其它进程

任何命令行进程都可以这样包：

```powershell
python tools/host_pc/codex_task_notify/main.py run -- python your_script.py
python tools/host_pc/codex_task_notify/main.py run -- powershell -File .\scripts\job.ps1
python tools/host_pc/codex_task_notify/main.py run -- codex exec "整理这个目录并输出总结"
```

行为：

- 子进程成功退出：发 `success`
- 子进程失败退出：发 `failure`
- 运行时长超过阈值并结束：额外发 `long-run-finished`
- 退出码原样返回给调用方

## PowerShell 快捷方式

```powershell
powershell -ExecutionPolicy Bypass -File tools/host_pc/codex_task_notify/codex-task-notify.ps1 test
```

## 当前聊天内如何用

当 Codex 在当前聊天里即将结束任务时，可显式调用：

```powershell
python tools/host_pc/codex_task_notify/main.py event --type success --message "任务完成：<摘要>"
```

当 Codex 需要你确认时，可显式调用：

```powershell
python tools/host_pc/codex_task_notify/main.py event --type manual-attention --message "需要你确认：<问题>"
```

## v1 边界

当前版本不会：

- 自动监听所有桌面交互状态
- 自动点击桌面 UI
- 向 QQ、微信、短信、邮箱发送
- 给多人分发消息
