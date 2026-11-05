#!/bin/bash
#
# Copyright (C) 2026 The LineageOS Project
#
# SPDX-License-Identifier: Apache-2.0
#
# Builds the two release files for the Galaxy S (GT-I9000):
#   <name>-kernel.tar.md5  kernel with the recovery and first-stage ramdisks
#                          embedded (the KERNEL partition, Odin "PDA"); also
#                          zImage for Heimdall
#   <name>.zip             recovery installer: repartitions the moviNAND after
#                          the internal SD and writes the system image
#
# Run from the top of the tree after
#   source build/envsetup.sh && lunch lineage_galaxysmtd-userdebug
#   m systemimage recoveryimage updater s1q_blkpg simg2img signapk
#
set -e

[ -n "$ANDROID_BUILD_TOP" ] && [ -n "$OUT" ] || { echo "run lunch first"; exit 1; }
cd "$ANDROID_BUILD_TOP"

DEVICE=galaxysmtd
REL=device/samsung/$DEVICE/releasetools
KSRC=kernel/samsung/aries
KOBJ=$OUT/obj/KERNEL_OBJ
INITRAMFS=$OUT/obj/KERNEL_INITRAMFS
DIST=${DIST:-$OUT/release}
NAME=${NAME:-lineage-17.1-$(date +%Y%m%d)-UNOFFICIAL-$DEVICE}
CROSS=$ANDROID_BUILD_TOP/prebuilts/gcc/linux-x86/arm/arm-linux-androideabi-4.9/bin/arm-linux-androideabi-
ZIMAGE_MAX=7864320      # KERNEL partition: 30 x 256K

mkdir -p "$DIST"

# 1. initramfs: recovery root, with the normal first-stage ramdisk under
#    /first_stage_ramdisk (init picks it unless the bootloader asked for recovery)
rm -rf "$INITRAMFS"
mkdir -p "$INITRAMFS/first_stage_ramdisk"
cp -a "$OUT/recovery/root/." "$INITRAMFS/"
cp -a "$OUT/ramdisk/." "$INITRAMFS/first_stage_ramdisk/"

# 2. kernel
mkdir -p "$KOBJ"
make -C $KSRC O="$KOBJ" ARCH=arm CROSS_COMPILE="$CROSS" s1q_galaxys_defconfig
sed -i "/^CONFIG_INITRAMFS_\|^# CONFIG_INITRAMFS_/d" "$KOBJ/.config"
cat >> "$KOBJ/.config" <<EOC
CONFIG_INITRAMFS_SOURCE="$INITRAMFS"
CONFIG_INITRAMFS_ROOT_UID=0
CONFIG_INITRAMFS_ROOT_GID=0
CONFIG_INITRAMFS_COMPRESSION_NONE=y
EOC
make -C $KSRC O="$KOBJ" ARCH=arm CROSS_COMPILE="$CROSS" oldnoconfig
rm -f "$KOBJ"/usr/initramfs_data.cpio* "$KOBJ"/usr/.initramfs_data.cpio*
make -C $KSRC O="$KOBJ" ARCH=arm CROSS_COMPILE="$CROSS" -j"$(nproc)" zImage
ZIMAGE=$KOBJ/arch/arm/boot/zImage
[ "$(stat -c %s "$ZIMAGE")" -le $ZIMAGE_MAX ] || { echo "zImage too large for the KERNEL partition"; exit 1; }
cp "$ZIMAGE" "$DIST/zImage"
(cd "$DIST" && tar -H ustar -cf "$NAME-kernel.tar" zImage && \
    md5sum -t "$NAME-kernel.tar" >> "$NAME-kernel.tar" && mv "$NAME-kernel.tar" "$NAME-kernel.tar.md5")

# 3. installer zip
W=$DIST/zip
rm -rf "$W"
mkdir -p "$W/META-INF/com/google/android"
cp "$OUT/system/bin/updater" "$W/META-INF/com/google/android/update-binary"
cp $REL/updater-script "$W/META-INF/com/google/android/updater-script"
cp $REL/repart.sh "$W/"
cp "$OUT/system/bin/s1q_blkpg" "$W/"
cp $KSRC/usr/utilities/busybox "$W/"
simg2img "$OUT/system.img" "$W/system.img"
rm -f "$DIST/$NAME-unsigned.zip"
(cd "$W" && zip -q -1 -r "$DIST/$NAME-unsigned.zip" META-INF repart.sh s1q_blkpg busybox system.img)
rm -rf "$W"
java -Djava.library.path="$ANDROID_HOST_OUT/lib64" -jar "$ANDROID_HOST_OUT/framework/signapk.jar" -w \
    build/target/product/security/testkey.x509.pem build/target/product/security/testkey.pk8 \
    "$DIST/$NAME-unsigned.zip" "$DIST/$NAME.zip"
rm -f "$DIST/$NAME-unsigned.zip"
(cd "$DIST" && md5sum "$NAME.zip" > "$NAME.zip.md5sum")

ls -l "$DIST"
