ARCHS = arm64 arm64e
TARGET = iphone:clang:16.5:16.5
THEOS_PACKAGE_SCHEME = rootless

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = VCAM

VCAM_FILES = \
    VCAM.xm \
    VCAMCore.xm \
    VCAMUI.xm \
    VCAMRecorder.xm \
    VCAMGlobals.m

VCAM_FRAMEWORKS = UIKit AVFoundation CoreGraphics CoreAudio AudioToolbox

# هذا السطر لمنع Theos من محاولة إنشاء deb
TWEAK_CFLAGS = -fobjc-arc

include $(THEOS_MAKE_PATH)/tweak.mk
