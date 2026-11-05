LOCAL_PATH := $(call my-dir)

# BCM4751 gpsd (non-PIE blob, allowed for /vendor by the s1q linker) shim
include $(CLEAR_VARS)
LOCAL_MODULE := libdmitry
LOCAL_VENDOR_MODULE := true
LOCAL_SRC_FILES := libdmitry.c
LOCAL_SHARED_LIBRARIES := libssl
include $(BUILD_SHARED_LIBRARY)
