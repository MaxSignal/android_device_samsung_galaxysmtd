LOCAL_PATH := $(call my-dir)

# Legacy (AudioHardwareInterface) wm8994 HAL from aries-common, on tinyalsa.
# Voice-call routing goes through libsecril-client when it is present.
include $(CLEAR_VARS)
LOCAL_MODULE := audio.primary.aries
LOCAL_MODULE_RELATIVE_PATH := hw
LOCAL_VENDOR_MODULE := true
LOCAL_SRC_FILES := AudioHardware.cpp
LOCAL_CFLAGS := -Wno-missing-field-initializers -Wno-unused-parameter -Wno-unused-variable \
    -Wno-unused-private-field -Wno-macro-redefined -Wno-format -Wno-sign-compare \
    -Wno-unused-function -Wno-gnu-designator -Wno-reorder -Wno-implicit-fallthrough
LOCAL_STATIC_LIBRARIES := libmedia_helper
LOCAL_WHOLE_STATIC_LIBRARIES := libaudiohw_legacy
LOCAL_SHARED_LIBRARIES := liblog libutils libcutils libhardware_legacy libtinyalsa libaudioutils libdl
LOCAL_HEADER_LIBRARIES := libhardware_headers libaudio_system_headers libmedia_headers
LOCAL_C_INCLUDES := hardware/ril/include $(LOCAL_PATH)/../ril/libsecril-client $(call include-path-for, audio-effects) $(call include-path-for, audio-utils)
include $(BUILD_SHARED_LIBRARY)
