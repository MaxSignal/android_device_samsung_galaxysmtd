# Samsung Galaxy S GT-I9000 (aries, S5PC110) - Android 10 Go
include device/s1q/common/BoardConfigS1q.mk

TARGET_BOARD_PLATFORM := s5pc110
TARGET_BOOTLOADER_BOARD_NAME := aries
TARGET_OTA_ASSERT_DEVICE := galaxysmtd,galaxys,GT-I9000

# zImage with embedded ramdisk is assembled by s1q packaging (tools/mkaries.sh)
# Real kernel is assembled outside the build; a placeholder lets boot/recovery roots get generated
TARGET_PREBUILT_KERNEL := device/s1q/common/placeholder-kernel
BOARD_KERNEL_PAGESIZE := 4096

TARGET_RECOVERY_FSTAB := device/samsung/galaxysmtd/rootdir/fstab.aries
BOARD_SEPOLICY_DIRS += device/samsung/galaxysmtd/sepolicy

# Bluetooth: BCM4329 on UART0 (H4), libbt-vendor
BOARD_HAVE_BLUETOOTH := true
BOARD_HAVE_BLUETOOTH_BCM := true
BOARD_CUSTOM_BT_CONFIG := device/samsung/galaxysmtd/bluetooth/libbt_vndcfg.txt
BOARD_BLUETOOTH_BDROID_BUILDCFG_INCLUDE_DIR := device/samsung/galaxysmtd/bluetooth
DEVICE_MANIFEST_FILE += device/samsung/galaxysmtd/manifest-power.xml
DEVICE_MANIFEST_FILE += device/s1q/common/manifest-graphics-inproc.xml

# Wi-Fi: BCM4329 on SDIO, bcmdhd (cfg80211) built into the kernel; firmware is
# loaded from firmware_path when wlan0 goes up
BOARD_WLAN_DEVICE                := bcmdhd
BOARD_WPA_SUPPLICANT_DRIVER      := NL80211
WPA_SUPPLICANT_VERSION           := VER_0_8_X
BOARD_WPA_SUPPLICANT_PRIVATE_LIB := lib_driver_cmd_bcmdhd
BOARD_HOSTAPD_DRIVER             := NL80211
BOARD_HOSTAPD_PRIVATE_LIB        := lib_driver_cmd_bcmdhd
WIFI_DRIVER_FW_PATH_PARAM        := "/sys/module/bcmdhd/parameters/firmware_path"
WIFI_DRIVER_FW_PATH_STA          := "/vendor/firmware/fw_bcmdhd.bin"
WIFI_DRIVER_FW_PATH_AP           := "/vendor/firmware/fw_bcmdhd_apsta.bin"
WIFI_DRIVER_FW_PATH_P2P          := "/vendor/firmware/fw_bcmdhd.bin"
DEVICE_MANIFEST_FILE += device/samsung/galaxysmtd/manifest-wifi.xml
DEVICE_MANIFEST_FILE += device/samsung/galaxysmtd/manifest-hw.xml

# hardware video codecs (vendor/samsung/s5pc110-omx)
BOARD_USES_SEC_OMX := true

# mount points for the efs (IMEI, modem NV data) and radio (modem.bin) yaffs2
# partitions: the root is the read-only system image
BOARD_ROOT_EXTRA_FOLDERS := efs radio
