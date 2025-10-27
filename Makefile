ARCHS = arm64 arm64e
TARGET = iphone:clang:16.5

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = FileSaverTweak
FileSaverTweak_FILES = Tweak.xm
FileSaverTweak_FRAMEWORKS = UIKit Foundation Photos MobileCoreServices UniformTypeIdentifiers

include $(THEOS_MAKE_PATH)/tweak.mk
