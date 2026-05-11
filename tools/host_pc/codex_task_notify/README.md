# codex任务完成的桌面与手机提示

这个工具用于在 Windows 电脑上把 Codex 任务状态同时发到：

- 当前电脑桌面通知
- 你自己的手机 `ntfy`

支持两种模式：

- 聊天内显式触发
- 包装其它命令行进程自动触发

## 目录结构

- `main.py`
  主 CLI 入口
- `codex_task_notify/`
  核心 Python 包
- `codex-task-notify.ps1`
  PowerShell 快捷包装
- `tests/`
  本地回归测试

## 快速开始

先看手机端文档：

- [手机端配置说明](../../../docs/CODEX_TASK_NOTIFY_PHONE_SETUP.md)

再看电脑端文档：

- [桌面端与仓库复用说明](../../../docs/CODEX_TASK_NOTIFY_DESKTOP_SETUP.md)

## 常用命令

初始化配置：

```powershell
python tools/host_pc/codex_task_notify/main.py init --server https://ntfy.sh --topic <你的topic> --title-prefix Codex --long-run-minutes 15 --desktop-toast on
```

发一条测试通知：

```powershell
python tools/host_pc/codex_task_notify/main.py test
```

聊天中需要你确认时：

```powershell
python tools/host_pc/codex_task_notify/main.py event --type manual-attention --message "需要你确认：是否继续"
```

包装一个长任务：

```powershell
python tools/host_pc/codex_task_notify/main.py run -- python your_script.py
```

PowerShell 简写：

```powershell
powershell -ExecutionPolicy Bypass -File tools/host_pc/codex_task_notify/codex-task-notify.ps1 test
```
