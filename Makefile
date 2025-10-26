ARCHS = arm64
TARGET = iphone:clang:16.0:16.0

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = FileSaverTweak
FileSaverTweak_FILES = Tweak.xm
FileSaverTweak_FRAMEWORKS = UIKit Foundation Photos MobileCoreServices UniformTypeIdentifiers

include $(THEOS_MAKE_PATH)/tweak.mk