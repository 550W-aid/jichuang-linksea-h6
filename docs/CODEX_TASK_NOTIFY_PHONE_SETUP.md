# codex任务完成的桌面与手机提示：手机端配置说明

## 适用对象

本说明用于 Android 手机上的 `ntfy` 接收配置。

## 1. 安装与订阅

1. 从 `Google Play` 安装 `ntfy`
2. 打开 app
3. 添加订阅
4. 输入你电脑初始化时使用的 topic

例如：

```text
codex-4eeb4c7c-ba9b-4382-96a9-b1c75880c0f7
```

## 2. 电脑端初始化

手机订阅前后都可以先在电脑执行：

```powershell
python tools/host_pc/codex_task_notify/main.py init --server https://ntfy.sh --topic <你的topic> --title-prefix Codex --long-run-minutes 15 --desktop-toast on
```

然后发测试：

```powershell
python tools/host_pc/codex_task_notify/main.py test
```

## 3. 如果手机不打开 ntfy 就收不到

这是 Android 厂商后台限制问题，尤其是 `vivo` 常见。

建议这样配：

1. 打开 `ntfy`
2. 找到并开启 `Instant delivery`
3. 去手机系统里给 `ntfy` 开后台运行权限
4. 关闭对 `ntfy` 的省电限制
5. 把 `ntfy` 从系统清理后台的白名单外移除或加入保护名单

## 4. vivo 推荐设置

按实际系统版本名称可能略有差异，但重点是：

- 允许通知
- 允许锁屏通知
- 允许横幅 / 弹窗
- 允许自启动
- 允许后台运行
- 电池策略改成不限制

## 5. 震动太强怎么办

`ntfy` 的不同优先级对应不同通知渠道。

建议按手机系统里的通知渠道调整：

- `High`
  保留弹窗，减弱振动或关闭振动
- `Urgent`
  保留更强提醒，只给失败事件使用

当前工具默认：

- `success = 3`
- `manual-attention = 4`
- `long-run-finished = 4`
- `failure = 5`

## 6. 如何判断是否配置成功

电脑执行：

```powershell
python tools/host_pc/codex_task_notify/main.py test
```

如果手机能收到测试通知，说明链路已通。

## 7. 当前版本说明

当前版本只做：

- 发到你自己的 `ntfy`
- 桌面端本地通知

当前版本不做：

- QQ
- 微信
- 短信
- 邮件
- 自动点击手机或桌面
