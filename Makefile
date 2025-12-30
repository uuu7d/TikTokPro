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
VCAM_FRAMEWORKS = AVFoundation UIKit CoreMedia CoreVideo
VCAM_CFLAGS = -fobjc-arc

#--------------------------------------
# منع إنشاء deb (نحتاج dylib فقط)
#--------------------------------------
FINALPACKAGE = 0

include $(THEOS_MAKE_PATH)/tweak.mk

#--------------------------------------
# إنشاء Fat dylib بعد البناء
#--------------------------------------
after-all::
	@echo "📦 Creating fat dylib..."
	lipo -create \
		.theos/obj/arm64/VCAM.dylib \
		.theos/obj/arm64e/VCAM.dylib \
		-output .theos/obj/VCAM-fat.dylib
	@echo "✅ Fat dylib created at .theos/obj/VCAM-fat.dylib"
