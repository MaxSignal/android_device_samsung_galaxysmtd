DEVICE_PACKAGE_OVERLAYS += device/samsung/galaxysmtd/overlay

# wpa_supplicant overlay: the bcmdhd one plus pmf=0 (listed before the
# bcmdhd config so this copy wins)
PRODUCT_COPY_FILES += \
    device/samsung/galaxysmtd/wifi/wpa_supplicant_overlay.conf:$(TARGET_COPY_OUT_VENDOR)/etc/wifi/wpa_supplicant_overlay.conf

# S5PC110 MFC video codecs (SEC OMX)
S1Q_MEDIA_CODECS := device/samsung/galaxysmtd/media/media_codecs.xml

$(call inherit-product, device/s1q/common/s1q.mk)
$(call inherit-product, vendor/samsung/galaxysmtd/galaxysmtd-vendor.mk)

PRODUCT_COPY_FILES += \
    device/samsung/galaxysmtd/rootdir/fstab.aries:$(TARGET_COPY_OUT_RAMDISK)/fstab.aries \
    device/samsung/galaxysmtd/rootdir/fstab.aries:$(TARGET_COPY_OUT_VENDOR)/etc/fstab.aries \
    device/samsung/galaxysmtd/rootdir/init.aries.rc:$(TARGET_COPY_OUT_VENDOR)/etc/init/hw/init.aries.rc \
    device/samsung/galaxysmtd/rootdir/init.aries.usb.rc:$(TARGET_COPY_OUT_VENDOR)/etc/init/hw/init.aries.usb.rc \
    device/samsung/galaxysmtd/rootdir/ueventd.aries.rc:$(TARGET_COPY_OUT_VENDOR)/ueventd.rc \
    device/samsung/galaxysmtd/rootdir/aries-mtd.sh:$(TARGET_COPY_OUT_VENDOR)/bin/aries-mtd.sh \
    device/samsung/galaxysmtd/rootdir/s1q-diag.sh:$(TARGET_COPY_OUT_VENDOR)/bin/s1q-diag.sh \
    device/samsung/galaxysmtd/rootdir/s1q-bdaddr.sh:$(TARGET_COPY_OUT_VENDOR)/bin/s1q-bdaddr.sh \
    device/samsung/galaxysmtd/recovery/init.recovery.aries.rc:$(TARGET_COPY_OUT_RECOVERY)/root/init.recovery.aries.rc \
    device/samsung/galaxysmtd/recovery/s1q-rdiag.sh:$(TARGET_COPY_OUT_RECOVERY)/root/s1q-rdiag.sh \
    $(foreach f,$(wildcard device/samsung/galaxysmtd/keylayout/*.kl),$(f):$(TARGET_COPY_OUT_SYSTEM)/usr/keylayout/$(notdir $(f))) \
    $(foreach f,$(wildcard device/samsung/galaxysmtd/keylayout/*.kcm),$(f):$(TARGET_COPY_OUT_SYSTEM)/usr/keychars/$(notdir $(f))) \
    device/samsung/galaxysmtd/keylayout/mxt224_ts_input.idc:$(TARGET_COPY_OUT_SYSTEM)/usr/idc/mxt224_ts_input.idc

PRODUCT_PROPERTY_OVERRIDES += \
    ro.sf.lcd_density=240 \
    ro.product.board=aries \
    ro.logd.kernel=true

PRODUCT_DEVICE_SVN_OVERRIDE := true

# off-mode charging animation
PRODUCT_PACKAGES += \
    charger_res_images

# power HAL: drives earlysuspend (/sys/power/state on/mem) from interactive state
PRODUCT_PACKAGES += \
    power.aries \
    android.hardware.power@1.0-impl \
    android.hardware.power@1.0-service

# GPU: PowerVR SGX540, DDK 1.8@2112805 (matches the in-kernel pvrsrvkm)
PRODUCT_PACKAGES += \
    libEGL_POWERVR_SGX540_120 \
    pvrsrvinit

PRODUCT_PROPERTY_OVERRIDES += \
    ro.hardware.egl=POWERVR_SGX540_120 \
    ro.zygote.disable_gl_preload=true \
    ro.bq.gpu_to_cpu_unsupported=1 \
    ro.egl.use_native_visual_id=true \
    ro.hwui.cpu_bitmap_upload=true

# Wi-Fi (BCM4329, bcmdhd)
$(call inherit-product, hardware/broadcom/wlan/bcmdhd/firmware/bcm4329/device-bcm.mk)
PRODUCT_PACKAGES += \
    android.hardware.wifi@1.0-service \
    wificond \
    wpa_supplicant \
    hostapd \
    libwpa_client \
    wpa_supplicant.conf
PRODUCT_COPY_FILES += \
    frameworks/native/data/etc/android.hardware.wifi.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.wifi.xml
PRODUCT_PROPERTY_OVERRIDES += \
    wifi.interface=wlan0

# Audio: legacy wm8994 HAL (picked up as audio.primary.${ro.hardware})
PRODUCT_PACKAGES += \
    audio.primary.aries \
    tinymix \
    tinyplay
PRODUCT_COPY_FILES += \
    device/samsung/galaxysmtd/audio/audio_policy_configuration.xml:$(TARGET_COPY_OUT_VENDOR)/etc/audio_policy_configuration.xml

# Sensors
PRODUCT_PACKAGES += \
    sensors.aries \
    android.hardware.sensors@1.0-impl \
    android.hardware.sensors@1.0-service
PRODUCT_COPY_FILES += \
    frameworks/native/data/etc/android.hardware.sensor.accelerometer.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.sensor.accelerometer.xml \
    frameworks/native/data/etc/android.hardware.sensor.compass.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.sensor.compass.xml \
    frameworks/native/data/etc/android.hardware.sensor.light.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.sensor.light.xml \
    frameworks/native/data/etc/android.hardware.sensor.proximity.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.sensor.proximity.xml

# Lights / vibrator (timed_output from aries-vibrator.c)
PRODUCT_PACKAGES += \
    lights.aries \
    android.hardware.light@2.0-impl \
    android.hardware.light@2.0-service \
    vibrator.default \
    android.hardware.vibrator@1.0-impl \
    android.hardware.vibrator@1.0-service

# Bluetooth (BCM4329, no LE)
PRODUCT_PACKAGES += \
    android.hardware.bluetooth@1.0-impl \
    android.hardware.bluetooth@1.0-service \
    libbt-vendor \
    audio.a2dp.default
PRODUCT_COPY_FILES += \
    device/samsung/galaxysmtd/bluetooth/bt_vendor.conf:$(TARGET_COPY_OUT_SYSTEM)/etc/bluetooth/bt_vendor.conf \
    frameworks/native/data/etc/android.hardware.bluetooth.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.bluetooth.xml
PRODUCT_PROPERTY_OVERRIDES += \
    ro.bt.bdaddr_path=/data/vendor/bluetooth/bdaddr

# Camera: HAL1 camera.aries through the legacy camera provider
PRODUCT_PACKAGES += \
    camera.aries \
    libs3cjpeg \
    android.hardware.camera.provider@2.4-impl \
    android.hardware.camera.provider@2.4-service \
    Camera2
PRODUCT_COPY_FILES += \
    device/samsung/galaxysmtd/camera/media_profiles_V1_0.xml:$(TARGET_COPY_OUT_VENDOR)/etc/media_profiles_V1_0.xml \
    frameworks/native/data/etc/android.hardware.camera.autofocus.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.camera.autofocus.xml \
    frameworks/native/data/etc/android.hardware.camera.front.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.camera.front.xml

# Cellular radio (XMM6160 through Samsung's libsec-ril): rild loads the blob
# via libsecril-shim. Most 2G/3G networks it supports are shut down, it is kept
# for whatever still works.
PRODUCT_PACKAGES += \
    s1q_mtd_dump \
    s1q_efs_migrate \
    rild \
    libsecril-shim \
    libsecril-compat
PRODUCT_COPY_FILES += \
    device/samsung/galaxysmtd/rootdir/s1q-modem.sh:$(TARGET_COPY_OUT_VENDOR)/bin/s1q-modem.sh \
    frameworks/native/data/etc/android.hardware.telephony.gsm.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.telephony.gsm.xml
PRODUCT_PROPERTY_OVERRIDES += \
    vendor.rild.libpath=/vendor/lib/libsecril-shim.so \
    rild.libpath=/vendor/lib/libsecril-shim.so \
    ro.telephony.default_network=0 \
    ro.ril.hsxpa=1 \
    ro.ril.gprsclass=10

# GPS: BCM4751 on UART1 through Broadcom gpsd + legacy gps.aries HAL
PRODUCT_PACKAGES += \
    libdmitry \
    libsecril-client \
    android.hardware.gnss@1.0-impl \
    android.hardware.gnss@1.0-service
PRODUCT_COPY_FILES += \
    device/samsung/galaxysmtd/gps/gps.xml:$(TARGET_COPY_OUT_VENDOR)/etc/gps.xml \
    device/samsung/galaxysmtd/gps/gps.conf:$(TARGET_COPY_OUT_VENDOR)/etc/gps.conf \
    frameworks/native/data/etc/android.hardware.location.gps.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.location.gps.xml

# hardware video codecs: SEC OMX on the MFC, loaded by the OMX service through
# libstagefrighthw
PRODUCT_PACKAGES += \
    libstagefrighthw \
    libSEC_OMX_Core \
    libOMX.SEC.AVC.Decoder \
    libOMX.SEC.M4V.Decoder \
    libOMX.SEC.AVC.Encoder \
    libOMX.SEC.M4V.Encoder
PRODUCT_COPY_FILES += \
    vendor/samsung/s5pc110-omx/sec_mm/sec_omx/sec_omx_core/secomxregistry:$(TARGET_COPY_OUT_VENDOR)/etc/secomxregistry
