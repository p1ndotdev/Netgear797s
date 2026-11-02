#!/bin/sh
case "$1" in
  start)
    kill -9 $(pidof restartGui) 2>/dev/null
    killall -9 restartGui Gui clock_daemon.sh dd hexdump 2>/dev/null
    export TZ='ICT-7'
    (
      sleep 1
      ifconfig bridge0 192.168.88.1 netmask 255.255.255.0 2>/dev/null
      if [ -f /mnt/userrw/swietc/dnsmasq.conf ]; then
        sed -i 's/192\.168\.1\./192.168.88./g' /mnt/userrw/swietc/dnsmasq.conf 2>/dev/null
        grep -v '^address=/#/' /mnt/userrw/swietc/dnsmasq.conf | grep -v '^dhcp-option=bridge0,3' | grep -v '^dhcp-option=bridge0,6' | grep -v '^dhcp-host=00:a0:c6:00:00:00' | grep -v '^dhcp-option=tag:usbpc' > /tmp/dnsmasq.conf
        echo 'dhcp-host=00:a0:c6:00:00:00,set:usbpc,192.168.88.4' >> /tmp/dnsmasq.conf
        echo 'dhcp-option=tag:usbpc,3' >> /tmp/dnsmasq.conf
        echo 'dhcp-option=tag:usbpc,6' >> /tmp/dnsmasq.conf
        cp /tmp/dnsmasq.conf /mnt/userrw/swietc/dnsmasq.conf && rm -f /tmp/dnsmasq.conf
        killall -9 dnsmasq 2>/dev/null
        dnsmasq -i bridge0 -z --conf-file=/mnt/userrw/swietc/dnsmasq.conf --dhcp-hostsfile=/etc/dhcp_hosts --dhcp-option=tag:!usbpc,6,192.168.88.1 >/dev/null 2>&1 &
      fi
      kill -9 $(pidof restartGui) 2>/dev/null
      killall -9 restartGui Gui clock_daemon.sh dd hexdump 2>/dev/null
      echo 0 > /sys/module/ntgr_st7789s/parameters/noupdate 2>/dev/null
      TZ='ICT-7' Gui file:///mnt/userrw/deskclock/clock.html >/dev/null 2>&1 &
      sleep 1
      /mnt/userrw/deskclock/clock_daemon.sh >/dev/null 2>&1 &
    ) &
    ;;
  stop)
    killall -9 clock_daemon.sh dd hexdump Gui 2>/dev/null
    /usr/sbin/restartGui >/dev/null 2>&1 &
    ;;
  restart)
    $0 stop
    sleep 1
    $0 start
    ;;
esac
exit 0
