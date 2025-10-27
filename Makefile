ARCHS = arm64 arm64e
TARGET = iphone:clang:16.0:latest

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = FileSaverTweak
FileSaverTweak_FILES = Tweak.xm
FileSaverTweak_FRAMEWORKS = UIKit Foundation Photos AVFoundation MobileCoreServices UniformTypeIdentifiers

SDKVERSION = 16.0

include $(THEOS_MAKE_PATH)/tweak.mk
