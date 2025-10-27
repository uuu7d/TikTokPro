ARCHS = arm64
TARGET = iphone:clang:latest:16.5
INSTALL_TARGET_PROCESSES = TikTok

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = FileSaverTweak
FileSaverTweak_FILES = Tweak.xm
FileSaverTweak_FRAMEWORKS = UIKit AVFoundation Photos

include $(THEOS_MAKE_PATH)/tweak.mk
