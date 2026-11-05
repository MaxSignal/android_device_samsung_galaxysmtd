#!/system/bin/sh
# The I9000 keeps its Bluetooth address in the modem NV data, read through the
# RIL. Without the RIL, derive a stable address from the serial number once.
F=/data/vendor/bluetooth/bdaddr
[ -s $F ] && exit 0
h=$(echo "$(getprop ro.serialno)" | md5sum)
echo "00:12:47:${h:0:2}:${h:2:2}:${h:4:2}" > $F
chmod 0640 $F
