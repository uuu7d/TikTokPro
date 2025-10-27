ARCHS = arm64 arm64e
TARGET = iphone:clang:16.0:latest

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = FileSaverTweak
FileSaverTweak_FILES = Tweak.xm
FileSaverTweak_FRAMEWORKS = UIKit Foundation Photos MobileCoreServices UniformTypeIdentifiers

# التأكد من أن الـ SDK 16.0 مستخدم فقط
SDKVERSION = 16.0

include $(THEOS_MAKE_PATH)/tweak.mk
