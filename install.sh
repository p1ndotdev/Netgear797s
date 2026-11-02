#!/bin/sh
# One-command installer for Netgear AirCard 797S (MDM9640) Liquid Glass Desk Clock + Smart Router Mod
set -e

mkdir -p /mnt/userrw/deskclock
cp -f deskclock/clock.html /mnt/userrw/deskclock/clock.html
cp -f deskclock/clock_daemon.sh /mnt/userrw/deskclock/clock_daemon.sh
chmod +x /mnt/userrw/deskclock/clock_daemon.sh

cp -f init.d/deskclock.sh /etc/init.d/deskclock.sh
chmod +x /etc/init.d/deskclock.sh

echo 'ICT-7' > /etc/TZ
rm -f /etc/rcS.d/S37gui.sh
ln -sf /etc/init.d/deskclock.sh /etc/rcS.d/S37deskclock
ln -sf /etc/init.d/deskclock.sh /etc/rc5.d/S99deskclock

# Set LAN subnet to 192.168.88.1 and brightness table to 70% (179/255 = 0xB3)
echo 'CACzs7Ozs7Oz' | base64 -d > /mnt/userrw/ntgnv/LCD_BL_BRIGHT_VALUE
/usr/bin/dx -c Router.GwIpAddr 192.168.88.1 >/dev/null 2>&1 || true
/usr/bin/dx -c Router.DhcpRangeLow 192.168.88.20 >/dev/null 2>&1 || true
/usr/bin/dx -c Router.DhcpRangeHigh 192.168.88.99 >/dev/null 2>&1 || true
/usr/bin/dx -c Router.UsbPcIp 192.168.88.4 >/dev/null 2>&1 || true

sync
/etc/init.d/deskclock.sh start
echo "Installed and started Netgear 797S Liquid Glass Desk Clock!"
