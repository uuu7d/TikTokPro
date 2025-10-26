# تحديد الحد الأدنى لإصدار iOS
THEOS_DEVICE_IPHONEOS_DEPLOYMENT_TARGET = 16.0

# المعماريات المستهدفة
ARCHS = arm64

# اسم التويك
TWEAK_NAME = SandboxTool

# ملفات التويك
SandboxTool_FILES = Tweak.xm

# الـ Frameworks المطلوبة
SandboxTool_FRAMEWORKS = UIKit Foundation AppSupport AVFoundation Photos

# تضمين Makefiles الخاصة بـ Theos
include $(THEOS)/makefiles/common.mk
include $(THEOS_MAKE_PATH)/tweak.mk
