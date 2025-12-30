ARCHS = arm64 arm64e
TARGET = iphone:clang:16.5:16.5
THEOS_PACKAGE_SCHEME = rootless

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = VCAM
VCAM_FILES = VCAM.xm VCAMCore.xm VCAMUI.xm VCAMRecorder.xm
VCAM_FRAMEWORKS = UIKit AVFoundation AudioToolbox

# تنظيف الملفات المؤقتة قبل البناء
clean::
    rm -rf $(THEOS_OBJ_DIR)

include $(THEOS_MAKE_PATH)/tweak.mk
