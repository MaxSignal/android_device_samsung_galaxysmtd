#!/bin/bash
#
# Copyright (C) 2026 The LineageOS Project
#
# SPDX-License-Identifier: Apache-2.0
#
# Builds an optional recovery zip that installs microG Services and the
# microG Companion as privileged system apps, with the signature spoofing and
# runtime permissions granted on the next boot.
#
#   build_microg.sh <com.google.android.gms-*.apk> <com.android.vending-*.apk>
#
# The APKs are the GmsCore releases from https://github.com/microg/GmsCore.
# Run from the top of the tree after lunch and
#   m updater signapk
#
set -e

[ -n "$ANDROID_BUILD_TOP" ] && [ -n "$OUT" ] || { echo "run lunch first"; exit 1; }
[ $# -eq 2 ] || { echo "usage: $0 <GmsCore apk> <Companion apk>"; exit 1; }
GMS=$(readlink -f "$1")
VENDING=$(readlink -f "$2")
cd "$ANDROID_BUILD_TOP"

DEVICE=galaxysmtd
MG=device/samsung/$DEVICE/releasetools/microg
DIST=${DIST:-$OUT/release}
NAME=${NAME:-microg-$(basename "$GMS" .apk | sed 's/^com.google.android.gms-//')-$DEVICE}

mkdir -p "$DIST"
W=$DIST/microg
rm -rf "$W"
mkdir -p "$W/META-INF/com/google/android" "$W/system/priv-app/GmsCore/lib/arm" \
    "$W/system/priv-app/Phonesky" "$W/system/etc/permissions" \
    "$W/system/etc/default-permissions" "$W/system/etc/sysconfig"
cp "$OUT/system/bin/updater" "$W/META-INF/com/google/android/update-binary"
cp $MG/updater-script "$W/META-INF/com/google/android/updater-script"
cp $MG/install.sh "$W/"
cp kernel/samsung/aries/usr/utilities/busybox "$W/"
cp "$GMS" "$W/system/priv-app/GmsCore/GmsCore.apk"
cp "$VENDING" "$W/system/priv-app/Phonesky/Phonesky.apk"
# extractNativeLibs=true: system apps need the libraries next to the apk
unzip -q -j -o "$GMS" 'lib/armeabi-v7a/*' -d "$W/system/priv-app/GmsCore/lib/arm"
cp $MG/privapp-permissions-microg.xml "$W/system/etc/permissions/"
cp $MG/microg-permissions.xml "$W/system/etc/default-permissions/"
cp $MG/microg-sysconfig.xml "$W/system/etc/sysconfig/microg.xml"

rm -f "$DIST/$NAME-unsigned.zip"
(cd "$W" && zip -q -1 -r "$DIST/$NAME-unsigned.zip" META-INF install.sh busybox system)
rm -rf "$W"
java -Djava.library.path="$ANDROID_HOST_OUT/lib64" -jar "$ANDROID_HOST_OUT/framework/signapk.jar" -w \
    build/target/product/security/testkey.x509.pem build/target/product/security/testkey.pk8 \
    "$DIST/$NAME-unsigned.zip" "$DIST/$NAME.zip"
rm -f "$DIST/$NAME-unsigned.zip"
(cd "$DIST" && md5sum "$NAME.zip" > "$NAME.zip.md5sum")

ls -l "$DIST/$NAME.zip"
