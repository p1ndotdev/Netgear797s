#!/bin/sh
export TZ='ICT-7'

# 1) Configure swiapp brightness (70% = 179/255 in NVRAM), standby, FOTA & button thresholds:
#    - On AC / USB: Never dim (0), Never Standby (0) -> Always-On Desk Clock at 70% brightness!
#    - On Battery:  15-min (900s) screen timeout & 15-min Deep Standby if no Wi-Fi clients connected!
echo 'CACzs7Ozs7Oz' | base64 -d > /mnt/userrw/ntgnv/LCD_BL_BRIGHT_VALUE 2>/dev/null
/usr/bin/dx -c UI.Lcd.BrightnessMapValOnBatt 7 >/dev/null 2>&1
/usr/bin/dx -c UI.Lcd.BrightnessMapValOnUSB 7 >/dev/null 2>&1
/usr/bin/dx -c UI.Lcd.BrightnessMapValOnAC 7 >/dev/null 2>&1
/usr/bin/dx -c UI.Lcd.BacklightInactTmoAC 0 >/dev/null 2>&1
/usr/bin/dx -c UI.Lcd.BacklightInactTmoUSB 0 >/dev/null 2>&1
/usr/bin/dx -c UI.Lcd.BacklightInactTmoBatt 900 >/dev/null 2>&1
/usr/bin/dx -c UI.Button.PowerBtnHold 60 >/dev/null 2>&1
/usr/bin/dx -c UI.Lcd.BacklightOvrMode On >/dev/null 2>&1
/usr/bin/dx -c Power.StandbyOnAcIdleTimer 0 >/dev/null 2>&1
/usr/bin/dx -c Power.StandbyOnUsbIdleTimer 0 >/dev/null 2>&1
/usr/bin/dx -c Power.StandbyOnBattIdleTimer 900 >/dev/null 2>&1
/usr/bin/dx -c Fota.FotaAutoDownload 0 >/dev/null 2>&1
/usr/bin/dx -c Fota.FotaAutoSdm 0 >/dev/null 2>&1
/usr/bin/dx -c Fota.WUAutoCheck 0 >/dev/null 2>&1
/usr/bin/dx -c Router.DnspForce 0 >/dev/null 2>&1
/usr/bin/dx -c Router.DnspActive 0 >/dev/null 2>&1

echo 1 > /tmp/screen_on
echo 0 > /tmp/hold_state
read UP_RAW _ < /proc/uptime
echo "${UP_RAW%.*}" > /tmp/last_wake

set_screen() {
  if [ "$1" = "1" ]; then
    echo 1 > /tmp/screen_on
    read UP_RAW _ < /proc/uptime
    echo "${UP_RAW%.*}" > /tmp/last_wake
    echo off > /sys/power/autosleep 2>/dev/null
    /usr/bin/dx -c UI.Lcd.BacklightOvrMode On >/dev/null 2>&1
    echo 0 > /sys/class/graphics/fb0/blank 2>/dev/null
    echo 0 > /sys/class/backlight/st7735bl/bl_power 2>/dev/null
    echo 179 > /sys/class/backlight/st7735bl/brightness 2>/dev/null
  else
    echo 0 > /tmp/screen_on
    echo 4 > /sys/class/backlight/st7735bl/bl_power 2>/dev/null
    /usr/bin/dx -c UI.Lcd.BacklightOvrMode Off >/dev/null 2>&1
    usleep 100000
    echo 4 > /sys/class/backlight/st7735bl/bl_power 2>/dev/null
    /usr/bin/dx -c UI.Lcd.BacklightOvrMode Off >/dev/null 2>&1
    read USB_NOW < /sys/class/power_supply/usb/online 2>/dev/null || USB_NOW=0
    if [ "$USB_NOW" = "0" ]; then
      echo mem > /sys/power/autosleep 2>/dev/null
    fi
  fi
}

# 2) Event-driven hardware power button reader (/dev/input/event0)
(
  while true; do
    EV=$(dd if=/dev/input/event0 bs=16 count=2 2>/dev/null | hexdump -v -e '2/4 "%u " 2/2 "%u " 1/4 "%d\n"')
    set -- $EV
    CODE_VAL=$3
    if [ "$CODE_VAL" = "1161" ]; then
      echo 1 > /tmp/btn_down
      (
        usleep 700000
        read BD < /tmp/btn_down 2>/dev/null || BD=0
        if [ "$BD" = "1" ]; then
          echo 1 > /tmp/hold_state
          set_screen 1
          usleep 1800000
          read BD < /tmp/btn_down 2>/dev/null || BD=0
          if [ "$BD" = "1" ]; then
            echo 2 > /tmp/hold_state
            sync
            sleep 1
            /sbin/reboot
          fi
        fi
      ) &
    elif [ "$CODE_VAL" = "1160" ]; then
      echo 0 > /tmp/btn_down
      read HS < /tmp/hold_state 2>/dev/null || HS=0
      echo 0 > /tmp/hold_state
      if [ "$HS" = "0" ]; then
        read USB < /sys/class/power_supply/usb/online 2>/dev/null || USB=0
        if [ "$USB" = "1" ]; then
          set_screen 1
        else
          read CUR < /tmp/screen_on 2>/dev/null || CUR=1
          if [ "$CUR" = "1" ]; then
            set_screen 0
          else
            set_screen 1
          fi
        fi
      fi
    fi
  done
) &

PREV_TOTAL=0
PREV_IDLE=0
PREV_USB=1
PREV_WWAN=-1
BATT_TICK=0
CAP=60

# 3) Main zero-fork status & power policy loop (pure shell builtins!)
while true; do
  read USB < /sys/class/power_supply/usb/online 2>/dev/null || USB=0
  read SCR < /tmp/screen_on 2>/dev/null || SCR=1
  read UP_RAW _ < /proc/uptime
  UP_SEC=${UP_RAW%.*}
  read LAST_WAKE < /tmp/last_wake 2>/dev/null || LAST_WAKE=0

  if [ "$USB" = "1" ]; then
    if [ "$PREV_USB" = "0" ] || [ "$SCR" = "0" ]; then
      echo off > /sys/power/autosleep 2>/dev/null
      set_screen 1
      SCR=1
    else
      echo 0 > /sys/class/graphics/fb0/blank 2>/dev/null
      echo 0 > /sys/class/backlight/st7735bl/bl_power 2>/dev/null
      echo 179 > /sys/class/backlight/st7735bl/brightness 2>/dev/null
    fi
    echo "$UP_SEC" > /tmp/last_wake
  else
    if [ "$PREV_USB" = "1" ]; then
      echo "$UP_SEC" > /tmp/last_wake
      LAST_WAKE=$UP_SEC
    fi
    if [ "$SCR" = "1" ]; then
      if [ $((UP_SEC - LAST_WAKE)) -ge 900 ]; then
        set_screen 0
        SCR=0
      else
        echo 0 > /sys/class/graphics/fb0/blank 2>/dev/null
        echo 0 > /sys/class/backlight/st7735bl/bl_power 2>/dev/null
        echo 179 > /sys/class/backlight/st7735bl/brightness 2>/dev/null
      fi
    else
      echo 4 > /sys/class/backlight/st7735bl/bl_power 2>/dev/null
    fi
  fi
  PREV_USB=$USB

  # Every 10s:
  # 1) Sync time strictly from SIM NITZ (dx General.CurrentTime)
  # 2) Query true battery percentage
  # 3) Smart USB DHCP Gateway toggle based on 4G WWAN state (and re-apply if swiapp overwrote dnsmasq.conf)
  # 4) Watchdog: if Gui ever crashes, auto-respawn it
  if [ $((BATT_TICK % 5)) -eq 0 ]; then
    YEAR=$(date -u +%Y)
    if [ "$YEAR" -lt 2024 ]; then
      CT=$(/usr/bin/dx General.CurrentTime 2>/dev/null | tr -d ' \r\n')
      case "$CT" in
        ''|*[!0-9]*) ;;
        *)
          if [ "$CT" -gt 1400000000 ]; then
            UNIX_TS=$((CT + 315964800))
            date -u -s "@${UNIX_TS}" >/dev/null 2>&1
          fi
          ;;
      esac
    fi

    NEW_CAP=$(/usr/bin/dx Battery.BatPercent 2>/dev/null | tr -d ' \r\n')
    case "$NEW_CAP" in
      ''|*[!0-9]*) ;;
      *) CAP=$NEW_CAP ;;
    esac

    WWAN_UP=0
    while read IFACE DEST GW _; do
      if [ "$DEST" = "00000000" ] && [ "$IFACE" != "bridge0" ]; then
        WWAN_UP=1
        break
      fi
    done < /proc/net/route

    NEED_DNS=0
    if [ "$WWAN_UP" != "$PREV_WWAN" ]; then
      NEED_DNS=1
    elif grep -q '^address=/#/' /mnt/userrw/swietc/dnsmasq.conf 2>/dev/null; then
      NEED_DNS=1
    fi

    if [ "$NEED_DNS" = "1" ]; then
      PREV_WWAN=$WWAN_UP
      sed -i 's/192\.168\.1\./192.168.88./g' /mnt/userrw/swietc/dnsmasq.conf 2>/dev/null
      grep -v '^address=/#/' /mnt/userrw/swietc/dnsmasq.conf | grep -v '^dhcp-option=bridge0,3' | grep -v '^dhcp-option=bridge0,6' | grep -v '^dhcp-host=00:a0:c6:00:00:00' | grep -v '^dhcp-option=tag:usbpc' > /tmp/dnsmasq.conf
      echo 'dhcp-host=00:a0:c6:00:00:00,set:usbpc,192.168.88.4' >> /tmp/dnsmasq.conf
      if [ "$WWAN_UP" = "1" ]; then
        cp /tmp/dnsmasq.conf /mnt/userrw/swietc/dnsmasq.conf && rm -f /tmp/dnsmasq.conf
        killall -9 dnsmasq 2>/dev/null
        dnsmasq -i bridge0 -z --conf-file=/mnt/userrw/swietc/dnsmasq.conf --dhcp-hostsfile=/etc/dhcp_hosts --dhcp-option-force=6,192.168.88.1 >/dev/null 2>&1 &
      else
        echo 'dhcp-option=tag:usbpc,3' >> /tmp/dnsmasq.conf
        echo 'dhcp-option=tag:usbpc,6' >> /tmp/dnsmasq.conf
        cp /tmp/dnsmasq.conf /mnt/userrw/swietc/dnsmasq.conf && rm -f /tmp/dnsmasq.conf
        killall -9 dnsmasq 2>/dev/null
        dnsmasq -i bridge0 -z --conf-file=/mnt/userrw/swietc/dnsmasq.conf --dhcp-hostsfile=/etc/dhcp_hosts --dhcp-option=tag:!usbpc,6,192.168.88.1 >/dev/null 2>&1 &
      fi
    fi

    if ! pidof Gui >/dev/null 2>&1; then
      TZ='ICT-7' Gui file:///mnt/userrw/deskclock/clock.html >/dev/null 2>&1 &
    fi
  fi
  BATT_TICK=$((BATT_TICK + 1))

  read HVAL < /tmp/hold_state 2>/dev/null || HVAL=0

  if [ "$SCR" = "1" ]; then
    read _ U1 U2 U3 IDLE U5 U6 U7 _ < /proc/stat
    TOTAL=$((U1 + U2 + U3 + IDLE + U5 + U6 + U7))
    DIFF_TOTAL=$((TOTAL - PREV_TOTAL))
    DIFF_IDLE=$((IDLE - PREV_IDLE))
    if [ $DIFF_TOTAL -gt 0 ]; then
      CPU=$((100 * (DIFF_TOTAL - DIFF_IDLE) / DIFF_TOTAL))
    else
      CPU=0
    fi
    PREV_TOTAL=$TOTAL
    PREV_IDLE=$IDLE

    while read K V _; do
      case "$K" in
        MemTotal:) MT=$V ;;
        MemFree:)  MF=$V ;;
        Buffers:)  MB=$V ;;
        Cached:)   MC=$V; break ;;
      esac
    done < /proc/meminfo
    RAM=$(( (MT - MF - MB - MC) * 100 / MT ))

    if [ "$USB" = "1" ]; then
      BATT="CHG ${CAP}%"
    else
      BATT="BAT ${CAP}%"
    fi
    read TEMP < /sys/class/thermal/thermal_zone0/temp 2>/dev/null || TEMP=36

    echo "{\"scr\":1,\"usb\":${USB},\"hold\":${HVAL},\"batt\":\"${BATT}\",\"cpu\":${CPU},\"ram\":${RAM},\"temp\":${TEMP}}" > /tmp/sysstat.json
  else
    echo "{\"scr\":0,\"usb\":${USB},\"hold\":${HVAL}}" > /tmp/sysstat.json
  fi

  sleep 2
done
