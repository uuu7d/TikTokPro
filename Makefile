#--------------------------------------
# إعدادات أساسية
#--------------------------------------
ARCHS = arm64 arm64e
TARGET = iphone:clang:16.5:16.5
THEOS_PACKAGE_SCHEME = rootless

include $(THEOS)/makefiles/common.mk

#--------------------------------------
# تعريف Tweak والملفات
#--------------------------------------
TWEAK_NAME = VCAM
VCAM_FILES = VCAM.xm VCAMCore.xm VCAMUI.xm VCAMRecorder.xm VCAMGlobals.m
VCAM_FRAMEWORKS = CoreAudio AVFoundation UIKit

#--------------------------------------
# إعدادات بناء dylib بدل .deb
#--------------------------------------
FINALPACKAGE = 0          # منع إنشاء .deb
TWEAK_CFLAGS += -fobjc-arc
TWEAK_LDFLAGS += -shared   # إنتاج dylib مشترك

#--------------------------------------
# إنشاء ملف fat dylib بعد البناء
#--------------------------------------
after-all::
	echo "📦 Creating fat dylib..."
    lipo -create \
		.theos/obj/arm64/VCAM.dylib \
		.theos/obj/arm64e/VCAM.dylib \
		-output .theos/obj/VCAM-fat.dylib
	echo "✅ Fat dylib created at .theos/obj/VCAM-fat.dylib"

#--------------------------------------
# استدعاء tweak.mk
#--------------------------------------
include $(THEOS_MAKE_PATH)/tweak.mk
