#!/system/bin/sh
# 等开机完成
i=0
while [ "$(getprop sys.boot_completed)" != "1" ] && [ $i -lt 90 ]; do
  sleep 2
  i=$((i+1))
done
sleep 30
LOG=/data/adb/audioheal.log
# 检测 AudioService 是否卡在 initStreamVolume 失败重试
if dumpsys audio 2>/dev/null | grep -q "initStreamVolume failed"; then
  echo "$(date) 检测到 AudioService 初始化失败，重启 zygote（保留 Xposed 挂钩）" >> $LOG
  killall zygote 2>/dev/null
  sleep 10
  # 若 init 没有自动拉起 zygote，手动补一次
  if [ -z "$(pidof zygote)" ]; then
    echo "$(date) zygote 未自动重启，手动 start" >> $LOG
    start zygote
  fi
  # 等框架起来（最多 150s）
  i=0
  while [ $i -lt 30 ]; do
    if [ -n "$(pidof system_server)" ] && [ "$(getprop sys.boot_completed)" = "1" ]; then
      break
    fi
    sleep 5
    i=$((i+1))
  done
  sleep 20
  if dumpsys audio 2>/dev/null | grep -q "initStreamVolume failed"; then
    echo "$(date) zygote 重启后仍然失败，回退 stop;start（本次模块注入会失效）" >> $LOG
    stop
    sleep 5
    start
    sleep 40
  fi
  if dumpsys audio 2>/dev/null | grep -q "initStreamVolume failed"; then
    echo "$(date) 修复失败" >> $LOG
  else
    echo "$(date) 修复成功，音频服务已恢复（Xposed 挂钩保留）" >> $LOG
  fi
else
  echo "$(date) 开机音频正常，无需修复" >> $LOG
fi
