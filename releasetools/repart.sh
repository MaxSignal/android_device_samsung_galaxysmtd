#!/tmp/busybox sh
# Galaxy S moviNAND layout for Android 10 Go.
# Keeps mmcblk0p1 (internal sdcard) untouched; re-carves everything after it:
#   p3 = system (SYS_MB), p4 = cache (64MB), p2 = data (rest)
# usage: repart.sh check|apply|format
BB=/tmp/busybox
DISK=/dev/block/mmcblk0
SYS_MB=${SYS_MB:-1100}
CACHE_MB=64
log() { echo "repart: $*"; echo "ui_print repart: $*" > /proc/self/fd/$OUTFD 2>/dev/null; echo "ui_print" > /proc/self/fd/$OUTFD 2>/dev/null; }

le32() { # print 4 little-endian bytes as printf escapes
    v=$1; printf '\\%03o\\%03o\\%03o\\%03o' $((v & 255)) $(((v >> 8) & 255)) $(((v >> 16) & 255)) $(((v >> 24) & 255))
}
mbr_entry() { # index(1-4) type(hex) start size
    off=$((446 + ($1 - 1) * 16))
    $BB printf "\\000\\376\\377\\377\\$(printf %03o $((0x$2)))\\376\\377\\377$(le32 $3)$(le32 $4)" | \
        $BB dd of=$DISK bs=1 seek=$off count=16 conv=notrunc 2>/dev/null
}

layout_ok() {
    [ -b ${DISK}p2 ] && [ -b ${DISK}p3 ] && [ -b ${DISK}p4 ] || return 1
    s3=$(cat /sys/block/mmcblk0/mmcblk0p3/size)
    [ $s3 -ge $((SYS_MB*2048 - 2048)) ]
}

case "$1" in
check)
    layout_ok && { log "layout already ok"; exit 0; }; exit 1 ;;
apply)
    layout_ok && { log "layout already ok"; exit 0; }
    # p1 may hold the update zip; everything after it gets re-carved
    for m in $($BB awk '/mmcblk0p[2-9]/ {print $2}' /proc/mounts); do $BB umount $m || $BB umount -l $m; done
    total=$(cat /sys/block/mmcblk0/size)
    p1start=$(cat /sys/block/mmcblk0/mmcblk0p1/start)
    p1size=$(cat /sys/block/mmcblk0/mmcblk0p1/size)
    start=$(( (p1start + p1size + 2047) / 2048 * 2048 ))
    free=$(( total - start ))
    need=$(( (SYS_MB + CACHE_MB + 512) * 2048 ))
    log "disk $((total/2048))MB, p1 kept ($((p1size/2048))MB), $((free/2048))MB after it"
    [ $free -ge $need ] || { log "not enough space after p1 (need $((need/2048))MB)"; exit 2; }
    sys=$((SYS_MB*2048)); cache=$((CACHE_MB*2048))
    data=$(( free - sys - cache ))
    p2s=$start; p3s=$((p2s + data)); p4s=$((p3s + sys))
    # write MBR entries 2..4 directly (entry 1 = p1 stays as is)
    $BB dd if=$DISK of=/tmp/mbr.bak bs=512 count=1 2>/dev/null
    mbr_entry 2 83 $p2s $data
    mbr_entry 3 83 $p3s $sys
    mbr_entry 4 83 $p4s $cache
    sync
    # BLKRRPART fails while p1 is mounted; update p2..p4 one by one instead
    if [ -x /tmp/s1q_blkpg ]; then
        for i in 4 3 2; do /tmp/s1q_blkpg $DISK del $i 2>/dev/null; done
        /tmp/s1q_blkpg $DISK add 2 $p2s $data && /tmp/s1q_blkpg $DISK add 3 $p3s $sys && \
            /tmp/s1q_blkpg $DISK add 4 $p4s $cache || log "BLKPG failed"
    else
        $BB blockdev --rereadpt $DISK 2>/dev/null
    fi
    sleep 2
    for i in 1 2 3 4 5 6 7 8 9 10; do [ -b ${DISK}p4 ] && break; sleep 1; done
    layout_ok || { log "repartition failed, see /tmp/fdisk.log"; exit 3; }
    log "data $((data/2048))MB, system ${SYS_MB}MB, cache ${CACHE_MB}MB"
    echo NEWLAYOUT > /tmp/repart.new
    exit 0 ;;
format)
    # data/cache are wiped when the layout was (re)created or on request
    if [ -f /tmp/repart.new ] || [ "$2" = force ]; then
        log "formatting data and cache"
        /system/bin/mke2fs -t ext4 -F -q ${DISK}p2 || $BB mke2fs -F ${DISK}p2
        /system/bin/mke2fs -t ext4 -F -q ${DISK}p4 || $BB mke2fs -F ${DISK}p4
    fi
    exit 0 ;;
esac
exit 1
