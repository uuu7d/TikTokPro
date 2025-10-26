ARCHS = arm64 arm64e
TARGET = iphone:clang:latest:16.0

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = SandboxTool

SandboxTool_FILES = Tweak.xm
SandboxTool_FRAMEWORKS = UIKit
SandboxTool_PRIVATE_FRAMEWORKS = AppSupport
SandboxTool_CFLAGS = -fobjc-arc

include $(THEOS_MAKE_PATH)/tweak.mk
