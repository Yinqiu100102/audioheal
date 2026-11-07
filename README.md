# AudioService Auto Heal

一个 Magisk 模块：开机后检测 MIUI 移植包的「音频服务初始化竞态」（`initStreamVolume failed`），
发现异常时自动恢复声音，且**尽量不丢失 Zygisk / Xposed 注入**。

> A Magisk module that detects the `initStreamVolume failed` race in MIUI ported ROMs
> and recovers audio automatically after boot.

## 背景 / Background

部分 MIUI 移植包（如 Redmi 8 上的 MIUI 14 移植）在开机时存在竞态：
`AudioService` 在 `initStreamVolume` 阶段失败，导致**整机无声**（媒体、通话、铃声全哑），
但系统本身完全正常启动，`dumpsys audio` 里能看到 `initStreamVolume failed` 记录。

重启一次通常能恢复——说明是时序问题而不是配置问题。本模块把这个「重启」自动化到开机流程里，
并且选择代价最小的恢复方式。

## 工作方式 / How it works

```
开机完成 (sys.boot_completed=1)
        │
        └─ 等待 30s（给 AudioService 充分时间完成初始化）
              │
              └─ dumpsys audio | grep "initStreamVolume failed"
                    │
                    ├─ 正常 → 写日志，退出（什么都不做）
                    │
                    └─ 失败 → killall zygote（软重启，保留 Zygisk/Xposed 注入）
                          │
                          ├─ 等待系统重新起来
                          ├─ 再次检测
                          │     ├─ 已恢复 → 记录成功
                          │     └─ 仍失败 → stop / start（完整框架重启，本次开机模块注入会失效）
                          └─ 最终仍失败 → 记录失败
```

- **优先 `killall zygote`**：这是软重启，zygote 重启后 Zygisk 与 Xposed 仍会正常加载，
  桌面/后台应用状态基本保留，代价远小于完整重启。
- **兜底 `stop` / `start`**：只有软重启无效时才用，会丢掉本开机周期的模块注入。

## 安装 / Install

1. 从 [Releases](../../releases) 下载 `audioheal-*.zip`（或自行 `./build.sh` 打包）。
2. Magisk → 模块 → 从本地安装。
3. 重启。

## 配置 / Configure

基本不需要配置。想改等待时间/重试次数，直接编辑模块目录下的 `service.sh` 里的常量：

| 位置 | 含义 | 默认 |
|---|---|---|
| `while ... i -lt 90` | 等待 `sys.boot_completed` 的最长时间（每次 2s） | 180s |
| `sleep 30` | 开机完成后额外等待，给 AudioService 收尾 | 30s |

## 日志 / Logs

```sh
su -c 'cat /data/adb/audioheal.log'
```

正常开机（无需修复）也会记一行，方便确认模块在工作：

```
2026-11-06 ... 开机音频正常，无需修复
2026-11-06 ... 检测到 AudioService 初始化失败，重启 zygote（保留 Xposed 挂钩）
2026-11-06 ... 修复成功，音频服务已恢复（Xposed 挂钩保留）
```

## 验证是否真的恢复了 / Verify

```sh
su -c 'dumpsys audio | grep -c "initStreamVolume failed"'   # 期望 0
```

再随便播放一段音频确认有声音。

## 兼容性 / Compatibility

- 在 Redmi 8（`olive`）/ MIUI 14 移植包 上验证；
- 判断依据只有一个字符串 `initStreamVolume failed`，凡是移植包里出现同样症状的机型理论上都能用；
- 不需要内核支持，纯 shell + Magisk，理论上 Android 8~14 都适用。

## 卸载 / Uninstall

Magisk 里移除模块并重启即可，模块不改动任何系统文件，只写了 `/data/adb/audioheal.log`。

## License

MIT
