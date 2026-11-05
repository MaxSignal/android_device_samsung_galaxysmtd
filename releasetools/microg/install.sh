#!/sbin/sh
# Run by the updater with busybox sh: mount | finish
# The system partition holds the root file system, /system is its system/ directory.
BB=/tmp/busybox
ROOT=/tmp/mg_root
SYS=/tmp/mg_system
case "$1" in
mount)
    for m in /system /mnt/system /system_root; do $BB umount $m 2>/dev/null; done
    $BB mkdir -p $ROOT $SYS
    $BB mount -t ext4 -o rw /dev/block/mmcblk0p3 $ROOT || exit 1
    [ -d $ROOT/system/priv-app ] || { echo "no system/ on the system partition"; $BB umount $ROOT; exit 1; }
    $BB mount -o bind $ROOT/system $SYS || { $BB umount $ROOT; exit 1; }
    # left at the top of the partition by earlier versions of this package
    $BB rm -rf $ROOT/priv-app/GmsCore $ROOT/priv-app/Phonesky
    $BB rmdir $ROOT/priv-app 2>/dev/null
    exit 0
    ;;
finish)
    # make the next boot apply the default permission grants again
    D=/data
    $BB mountpoint -q /data || { D=/tmp/mg_data; $BB mkdir -p $D; $BB mount -t ext4 /dev/block/mmcblk0p2 $D; }
    F=$D/system/users/0/runtime-permissions.xml
    if [ -f $F ]; then
        $BB sed 's/ fingerprint="[^"]*"/ fingerprint=""/' $F > /tmp/rp.xml && $BB cat /tmp/rp.xml > $F
    fi
    [ $D = /tmp/mg_data ] && $BB umount $D
    ok=0
    [ -f $SYS/priv-app/GmsCore/GmsCore.apk ] && [ -f $SYS/priv-app/Phonesky/Phonesky.apk ] && \
        [ -f $SYS/etc/permissions/privapp-permissions-microg.xml ] && ok=1
    $BB sync
    $BB umount $SYS
    $BB umount $ROOT
    [ $ok = 1 ] || { echo "microG files not found in /system"; exit 1; }
    exit 0
    ;;
esac
exit 1
