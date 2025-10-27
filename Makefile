ARCHS = arm64 arm64e
FINALPACKAGE = 1
export ADDITIONAL_CFLAGS = -Wno-deprecated-declarations
TARGET = iphone:clang:16.5:latest
THEOS_DEVICE_IP = 127.0.0.1

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = FileSaverTweak

FileSaverTweak_FILES = Tweak.xm
FileSaverTweak_FRAMEWORKS = UIKit AVFoundation Photos
FileSaverTweak_PRIVATE_FRAMEWORKS = AppSupport
FileSaverTweak_CFLAGS = -fobjc-arc
FileSaverTweak_PRIVATE_FRAMEWORKS = CydiaSubstrate
FileSaverTweak_LDFLAGS += -framework AVFoundation -framework Photos -framework UIKit
FileSaverTweak_FILES = Tweak.xm MBProgressHUD.m
FileSaverTweak_FRAMEWORKS = UIKit Foundation Photos AVFoundation AVKit
include $(THEOS_MAKE_PATH)/tweak.mk

after-install::
	install.exec "killall -9 SpringBoard"