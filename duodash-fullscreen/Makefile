ARCHS = arm64 arm64e
TARGET = iphone:clang:latest:15.0
THEOS_PACKAGE_SCHEME = rootless

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = DuoDashFullscreenAdapter
DuoDashFullscreenAdapter_FILES = DuoDashFullscreen.xm
DuoDashFullscreenAdapter_CFLAGS = -fobjc-arc
DuoDashFullscreenAdapter_FRAMEWORKS = UIKit Foundation
DuoDashFullscreenAdapter_LIBRARIES = substrate

include $(THEOS_MAKE_PATH)/tweak.mk
