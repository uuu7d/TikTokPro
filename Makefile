ARCHS = arm64 arm64e
TARGET = iphone:clang:18.0:18.0
THEOS_PACKAGE_SCHEME = rootless

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = VCAM
VCAM_FILES = VCAM.xm VCAMCore.xm VCAMUI.xm VCAMRecorder.xm

include $(THEOS_MAKE_PATH)/tweak.mk
