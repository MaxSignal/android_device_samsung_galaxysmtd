#!/system/bin/sh
# Recovery: copy last_kmsg and the previous boot's /data/s1qlog to <microSD>/s1qlog-recovery
O=/tmp/s1qdiag
mkdir -p $O/data /tmp/s1qsd /tmp/s1qdata
cat /proc/last_kmsg > $O/last_kmsg.txt 2>&1
dmesg > $O/recovery_dmesg.txt 2>&1
cat /proc/partitions /proc/mtd > $O/partitions.txt 2>&1
# only when the diagnostics were enabled in Android (persist.vendor.s1q.diag=1)
mount -t ext4 -o ro /dev/block/mmcblk0p2 /tmp/s1qdata || exit 0
if [ ! -d /tmp/s1qdata/s1qlog ]; then
    umount /tmp/s1qdata
    exit 0
fi
cp -r /tmp/s1qdata/s1qlog/. $O/data/ 2>/dev/null
cp -r /tmp/s1qdata/tombstones $O/ 2>/dev/null
umount /tmp/s1qdata
for i in 1 2 3 4 5 6 7 8 9 10; do [ -b /dev/block/mmcblk1p1 ] && break; sleep 1; done
if mount -t vfat -o rw /dev/block/mmcblk1p1 /tmp/s1qsd; then
    rm -rf /tmp/s1qsd/s1qlog-recovery
    mkdir -p /tmp/s1qsd/s1qlog-recovery
    cp -r $O/. /tmp/s1qsd/s1qlog-recovery/
    sync
    umount /tmp/s1qsd
fi
