LOCAL_PATH:= $(call my-dir)

# LCD backlight (s5p_bl) + BLN notification LED on the touchkeys
include $(CLEAR_VARS)
LOCAL_MODULE := lights.aries
LOCAL_MODULE_RELATIVE_PATH := hw
LOCAL_VENDOR_MODULE := true
LOCAL_SRC_FILES := lights.c
LOCAL_SHARED_LIBRARIES := liblog
LOCAL_HEADER_LIBRARIES := libhardware_headers
LOCAL_CFLAGS := -Wno-unused-parameter
include $(BUILD_SHARED_LIBRARY)
