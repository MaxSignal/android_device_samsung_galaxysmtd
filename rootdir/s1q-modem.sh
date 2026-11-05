#!/system/bin/sh
# libsec-ril uploads the XMM6160 firmware from /dev/block/bml12: the radio
# partition's modem.bin when the phone has one, else the GT-I9000 copy in vendor
if [ -s /radio/modem.bin ]; then
    ln -sf /radio/modem.bin /dev/block/bml12
else
    ln -sf /vendor/firmware/modem.bin /dev/block/bml12
fi
