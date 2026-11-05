LOCAL_PATH:= $(call my-dir)

# Client of rild's Samsung OEM socket (call audio path / volume / clock sync)
include $(CLEAR_VARS)
LOCAL_MODULE := libsecril-client
LOCAL_VENDOR_MODULE := true
LOCAL_SRC_FILES := secril-client.cpp
LOCAL_SHARED_LIBRARIES := libutils libcutils liblog libbinder libhardware_legacy
LOCAL_C_INCLUDES := hardware/ril/include
LOCAL_CFLAGS := -Wno-unused-parameter -Wno-unused-variable -Wno-format
LOCAL_EXPORT_C_INCLUDE_DIRS := $(LOCAL_PATH)
include $(BUILD_SHARED_LIBRARY)
