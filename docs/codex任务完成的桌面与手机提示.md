# codex任务完成的桌面与手机提示

这份文档是总入口。

请先阅读：

- [桌面端与仓库复用说明](./CODEX_TASK_NOTIFY_DESKTOP_SETUP.md)
- [手机端配置说明](./CODEX_TASK_NOTIFY_PHONE_SETUP.md)

## 这个功能解决什么问题

在使用 Codex 或其它长时间任务时，不需要反复打开应用查看是否完成。

通过仓库内的通知工具，可以把任务状态发到：

- 当前 Windows 桌面
- 你自己的 Android 手机 `ntfy`

## 工具位置

```text
tools/host_pc/codex_task_notify/
```

## 支持的两种使用方式

1. 聊天内显式触发

```powershell
python tools/host_pc/codex_task_notify/main.py event --type success --message "任务完成：<摘要>"
python tools/host_pc/codex_task_notify/main.py event --type manual-attention --message "需要你确认：<问题>"
```

2. 包装其它命令行进程

```powershell
python tools/host_pc/codex_task_notify/main.py run -- python your_script.py
python tools/host_pc/codex_task_notify/main.py run -- powershell -File .\scripts\job.ps1
python tools/host_pc/codex_task_notify/main.py run -- codex exec "整理这个目录并输出总结"
```

## 当前默认提醒强度

- `success = 3`
- `manual-attention = 4`
- `long-run-finished = 4`
- `failure = 5`

## 初始化与测试

初始化：

```powershell
python tools/host_pc/codex_task_notify/main.py init --server https://ntfy.sh --topic <你的topic> --title-prefix Codex --long-run-minutes 15 --desktop-toast on
```

测试：

```powershell
python tools/host_pc/codex_task_notify/main.py test
```

## 手机端注意事项

如果手机不打开 `ntfy` 就收不到，重点检查：

- `Instant delivery`
- 自启动
- 后台运行权限
- 电池不限制
- 锁屏/横幅/弹窗通知权限

详细步骤见：

- [手机端配置说明](./CODEX_TASK_NOTIFY_PHONE_SETUP.md)
