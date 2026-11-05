LOCAL_PATH := $(call my-dir)

# s5pc110 hardware JPEG encoder (/dev/s3c-jpg)
include $(CLEAR_VARS)
LOCAL_MODULE := libs3cjpeg
LOCAL_VENDOR_MODULE := true
LOCAL_SRC_FILES := libs3cjpeg/JpegEncoder.cpp
LOCAL_C_INCLUDES := $(LOCAL_PATH)/libs3cjpeg $(LOCAL_PATH)/include
LOCAL_SHARED_LIBRARIES := liblog libdl libutils
LOCAL_CFLAGS := -Wno-unused-parameter -Wno-unused-variable -Wno-sign-compare -Wno-format -Wno-c++11-narrowing
include $(BUILD_SHARED_LIBRARY)

# CE147 (rear, 5 MP ISP) / S5KA3DFX (front) V4L2 FIMC camera, HAL1
include $(CLEAR_VARS)
LOCAL_MODULE := camera.aries
LOCAL_MODULE_RELATIVE_PATH := hw
LOCAL_VENDOR_MODULE := true
LOCAL_SRC_FILES := SecCamera.cpp SecCameraHWInterface.cpp SecCameraUtils.cpp
LOCAL_C_INCLUDES := $(LOCAL_PATH)/include $(LOCAL_PATH)/libs3cjpeg \
    frameworks/native/include/media/hardware system/media/camera/include
LOCAL_CFLAGS := -DFFC_PRESENT -Wno-missing-field-initializers -Wno-unused-parameter \
    -Wno-unused-variable -Wno-sign-compare -Wno-format -Wno-unused-private-field \
    -Wno-unused-function -Wno-overloaded-virtual -Wno-reorder -Wno-c++11-narrowing \
    -Wno-implicit-fallthrough -Wno-gnu-designator -Wno-writable-strings
LOCAL_SHARED_LIBRARIES := libutils libcutils libbinder liblog libcamera_client libhardware libs3cjpeg libui
LOCAL_HEADER_LIBRARIES := libhardware_headers libnativewindow_headers libnativebase_headers
include $(BUILD_SHARED_LIBRARY)
