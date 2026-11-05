#!/system/bin/sh
# Bring-up diagnostics: snapshot logs to /data/s1qlog every minute and, when a
# microSD card is inserted, copy them to <microSD>/s1qlog (readable on a PC).
# Off-mode charging: every 15s to <microSD>/s1qlog-charger.
# "charger": off-mode charging has no /data, keep the snapshot in tmpfs
if [ "$1" = charger ]; then D=/dev/s1qlog; S=s1qlog-charger; else D=/data/s1qlog; S=s1qlog; fi
M=/dev/s1qsd
mkdir -p $D $M
n=0
# kernel log of the previous boot (panic / hang before a reboot), kept for the
# last 8 boots: a boot that reboots again before its copy must not lose it
if [ "$1" != charger ]; then
    k=$(cat $D/.boot 2>/dev/null); k=$(( ${k:-0} + 1 )); echo $k > $D/.boot
    cat /proc/last_kmsg > $D/last_kmsg-$k.txt 2>&1
    rm -f $D/last_kmsg-$(( k - 8 )).txt $D/last_kmsg.txt
    # straight to the microSD as well, before anything that could take long
    if [ -b /dev/block/mmcblk1p1 ] && mount -t vfat -o rw,noatime /dev/block/mmcblk1p1 $M; then
        mkdir -p $M/$S
        cp $D/last_kmsg-$k.txt $M/$S/
        sync
        umount $M
    fi
fi
# dumpsys output goes to a file first: piping it into head closes the pipe
# early and the service (or the HAL it forwards the fd to) dies of SIGPIPE
# (every probe has a timeout: a hung service must not stop the log copies)
ds() { timeout 20 dumpsys "$1" > $D/.ds 2>&1; head -n $2 $D/.ds; rm -f $D/.ds; }
hwinfo() {
    echo "== net"; timeout 10 ip addr 2>&1; ls /sys/class/net 2>&1
    echo "== wifi"; cat /sys/module/bcmdhd/parameters/firmware_path 2>&1
    ds wifi 60
    echo "== rfkill"; for r in /sys/class/rfkill/*; do echo "$r $(cat $r/type) $(cat $r/state)"; done
    echo "== bluetooth"; ls -l /data/vendor/bluetooth 2>&1; ds bluetooth_manager 40
    echo "== sound"; cat /proc/asound/cards 2>&1; timeout 10 tinymix > $D/.ds 2>&1; head -n 20 $D/.ds
    ds media.audio_flinger 60
    echo "== sensors"; ds sensorservice 80
    echo "== input"; for i in /sys/class/input/input*; do echo "$i $(cat $i/name)"; done
    echo "== lights"; cat /sys/class/backlight/s5p_bl/brightness 2>&1
    echo "== vibrator"; ls -l /sys/class/timed_output/vibrator/ 2>&1
    echo "== camera"; ls -l /dev/video* 2>&1; ds media.camera 40
    echo "== hals"; timeout 30 lshal > $D/.ds 2>&1; head -n 60 $D/.ds; rm -f $D/.ds
    echo "== radio"; ls -l /efs /radio /dev/block/bml12 /dev/onedram 2>&1; getprop | grep -E "gsm\.|ril\." 2>&1
}
while true; do
    {
        uptime
        echo "boot_completed=$(getprop sys.boot_completed)"
        echo "usb.config=$(getprop sys.usb.config) usb.state=$(getprop sys.usb.state)"
        for f in enable state functions idVendor idProduct; do
            echo "android0/$f=$(cat /sys/class/android_usb/android0/$f 2>&1)"
        done
        ls -l /dev/android_adb
        echo "fb0 virtual_size=$(cat /sys/class/graphics/fb0/virtual_size 2>&1) bpp=$(cat /sys/class/graphics/fb0/bits_per_pixel 2>&1)"
    } > $D/status.txt 2>&1
    dmesg > $D/dmesg.txt 2>&1
    ps -A -o PID,PPID,S,%CPU,RSS,TIME,NAME > $D/ps.txt 2>&1
    getprop > $D/getprop.txt 2>&1
    cat /proc/meminfo > $D/meminfo.txt 2>&1
    logcat -b crash -d > $D/crash.txt 2>&1
    if [ -b /dev/block/mmcblk1p1 ] && mount -t vfat -o rw,noatime /dev/block/mmcblk1p1 $M; then
        mkdir -p $M/$S
        cp $D/* $M/$S/ 2>/dev/null
        sync
        umount $M
    fi
    # hardware state once boot completed, then every ~2 minutes (after the copy:
    # it talks to services that may hang), written to the next copy
    if [ "$1" != charger ] && [ "$(getprop sys.boot_completed)" = 1 ] && [ $((n % 2)) -eq 0 ]; then
        hwinfo > $D/hw.txt.new 2>&1; mv $D/hw.txt.new $D/hw.txt
        ls -lt /data/anr /data/tombstones > $D/anr.txt 2>&1
        a=$(ls -t /data/anr/anr_* 2>/dev/null | head -1)
        [ -n "$a" ] && head -n 600 $a >> $D/anr.txt
        # kernel logs of earlier boots that BootReceiver saved (last_kmsg.txt
        # only holds the previous one)
        cp /data/system/dropbox/SYSTEM_LAST_KMSG* $D/ 2>/dev/null
    fi
    n=$((n + 1))
    # every 10s during the first 3 minutes of uptime (boot problems), then every minute
    up=$(cut -d. -f1 /proc/uptime)
    if [ "$1" = charger ] || [ "$up" -lt 180 ]; then sleep 10; else sleep 60; fi
done
