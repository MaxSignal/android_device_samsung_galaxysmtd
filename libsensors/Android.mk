LOCAL_PATH := $(call my-dir)

# BMA023 (SMB380 compatible) accelerometer, YAS529 magnetometer (calibrated
# in the kernel driver), GP2A light / proximity; all input-event based
include $(CLEAR_VARS)
LOCAL_MODULE := sensors.aries
LOCAL_MODULE_RELATIVE_PATH := hw
LOCAL_VENDOR_MODULE := true
LOCAL_CFLAGS := -DLOG_TAG=\"Sensors\" -Wno-unused-parameter -Wno-unused-variable \
    -Wno-unused-private-field -Wno-gnu-designator -Wno-sign-compare -Wno-unused-result
LOCAL_SRC_FILES := \
    sensors.cpp \
    SensorBase.cpp \
    LightSensor.cpp \
    ProximitySensor.cpp \
    Smb380Sensor.cpp \
    CompassSensor.cpp \
    OrientationSensor.cpp \
    InputEventReader.cpp
LOCAL_SHARED_LIBRARIES := liblog libcutils libdl libutils
LOCAL_HEADER_LIBRARIES := libhardware_headers
include $(BUILD_SHARED_LIBRARY)
