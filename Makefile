ARCHS = arm64 arm64e
TARGET = iphone:clang:latest:14.0
INSTALL_TARGET_PROCESSES = SpringBoard

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = SaveGram
SaveGram_FILES = Tweak.xm
SaveGram_FRAMEWORKS = UIKit AVFoundation Photos
SaveGram_PRIVATE_FRAMEWORKS = CydiaSubstrate
include $(THEOS_MAKE_PATH)/tweak.mk
