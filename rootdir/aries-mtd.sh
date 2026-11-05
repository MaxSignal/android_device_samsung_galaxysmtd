#!/system/bin/sh
# Resolve OneNAND MTD partitions (named by the bootloader ATAG) to stable paths
mkdir -p /dev/block/by-name
while read dev size erase name; do
    case "$dev" in mtd*:) ;; *) continue ;; esac
    n=${dev%:}; n=${n#mtd}; name=${name//\"/}
    ln -sf /dev/block/mtdblock$n /dev/block/by-name/$name
    ln -sf /dev/mtd$n /dev/block/by-name/$name-char
done < /proc/mtd
setprop vendor.aries.mtd_ready 1
