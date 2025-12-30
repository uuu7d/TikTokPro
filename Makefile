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
	@echo "📦 Creating fat dylib..."
	lipo -create \
		$(THEOS)/obj/arm64/$(TWEAK_NAME).dylib \
		$(THEOS)/obj/arm64e/$(TWEAK_NAME).dylib \
		-output $(THEOS)/obj/$(TWEAK_NAME)-fat.dylib
	@echo "✅ Fat dylib created at: $(THEOS)/obj/$(TWEAK_NAME)-fat.dylib"

#--------------------------------------
# استدعاء tweak.mk
#--------------------------------------
include $(THEOS_MAKE_PATH)/tweak.mk
