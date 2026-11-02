# Netgear AirCard 797S — Liquid Glass Desk Clock & Smart 4G Router Mod

Custom embedded Linux (`Qualcomm MDM9640` / `armv7l`) firmware customization for the **Netgear AirCard 797S** mobile hotspot, turning its `160x128` ST7735 LCD into a monochrome **Liquid Glass Desk Clock & System Performance Monitor** while preserving full Wi-Fi hotspot & 4G USB tethering capabilities.

---

## ✨ Key Features

1. **Monochrome Liquid Glass UI (`180°` Flipped Orientation)**
   - Pure black (`#000000`) background with ambient monochrome glow orbs and frosted translucent glass cards (`deskclock/clock.html`).
   - Rotated `180°` so the USB power cable exits cleanly from the top/back when standing on a desk.
   - Displays **Time (`HH:MM` + `SS`)**, **Day & Date**, **True Fuel-Gauge Battery % (`CHG`/`BAT`)**, and live **CPU %**, **RAM %**, and **SoC Temperature (`°C`)** with progress bars.

2. **Zero-Fork Ultra-Low CPU Daemon (`deskclock/clock_daemon.sh`)**
   - Uses pure POSIX shell builtins (`read < /proc/stat`, `/proc/meminfo`, `/proc/uptime`) with **0 subprocess forks** per 2-second tick.
   - Idles at **`2% – 6%` CPU** at the lowest **`300 MHz`** clock step (`~0.5%` total SoC capacity).
   - Dirty-checked DOM updates in WebKit (`Gui`) so `HH:MM` only repaints once per minute.

3. **Hardware Power Button (`/dev/input/event0`) & Smart Power Policy**
   - **Flicker-Free 70% Brightness (`179/255`):** Hardware NVRAM table (`/mnt/userrw/ntgnv/LCD_BL_BRIGHT_VALUE`) patched to `0xB3` (`179`) across all brightness states (`1..7`), eliminating the 100% brightness flash when plugging/unplugging USB or toggling the screen.
   - **On Charger / PC USB (`USB = 1`):** Screen stays **Always-On** at 70% brightness; Deep Standby (`autosleep`) is disabled.
   - **On Battery (`USB = 0`):**
     - **Single Press:** Immediately toggles the LCD backlight **OFF ↔ ON** (and pauses stat polling while off).
     - **15-Minute Auto Screen-Off & Deep Standby:** Automatically turns off the screen after 15 minutes (`900s`) and enters kernel Deep Standby (`mem`) if no Wi-Fi clients are active; wakes up immediately on power button press or charger plug-in.
   - **Long Press (`>= 2.5s`):** Displays a `HOLD TO REBOOT` progress modal and triggers a clean `/sbin/reboot` (**Factory Reset via LCD long-press is completely disabled**).

4. **SIM NITZ Time Synchronization**
   - Automatically synchronizes UTC/local time (`ICT-7`, Vietnam `GMT+7`) from cellular tower **NITZ** (`dx General.CurrentTime`) as soon as a SIM registers on a base station.
   - Displays `--:-- WAITING FOR SIM...` cleanly if booted after a full battery drain before cellular sync completes.

5. **Smart Conflict-Free USB Networking (`192.168.88.1/24`)**
   - Moves the Netgear LAN subnet from `192.168.1.1` to **`192.168.88.1`** (USB RNDIS PC IP: `192.168.88.4`) to avoid colliding with home Wi-Fi routers (`192.168.1.1`).
   - Strips Netgear's captive DNS hijack (`address=/#/`).
   - **4G-Aware DHCP Gateway (`tag:usbpc`):**
     - When **4G WWAN is offline**, `dnsmasq` omits Default Gateway & DNS (DHCP options `3` and `6`) for the USB RNDIS interface so the host PC never loses its Wi-Fi Internet connection.
     - When **4G WWAN is online (`rmnet_data0`)**, `dnsmasq` automatically advertises Gateway & DNS `192.168.88.1` so the PC can seamlessly use 4G Internet over USB.
   - Wi-Fi clients (`SSID: Wai Fai`) always receive full DHCP Gateway & DNS (`192.168.88.20–99`).

---

## 📁 Repository Structure

```text
├── deskclock/
│   ├── clock.html          # 160x128 Liquid Glass UI (rotated 180°)
│   └── clock_daemon.sh     # Event0 button handler, NITZ sync, power & smart DHCP daemon
├── init.d/
│   └── deskclock.sh        # SysV init script (/etc/rcS.d/S37deskclock & /etc/rc5.d/S99deskclock)
└── install.sh              # One-command installer script for Netgear AC797S root shell
```


## 🔧 Installation & Service Control

Copy this repository to `/tmp` on the device and run:

```sh
sh install.sh
```

To temporarily switch back to the stock Netgear LCD UI (e.g. to view Wi-Fi settings on screen):

```sh
/etc/init.d/deskclock.sh stop
```

To return to the Liquid Glass Desk Clock:

```sh
/etc/init.d/deskclock.sh start
```
