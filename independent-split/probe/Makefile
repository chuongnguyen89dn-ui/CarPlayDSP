ARCHS = arm64 arm64e
TARGET = iphone:clang:latest:15.0
THEOS_PACKAGE_SCHEME = rootless
include $(THEOS)/makefiles/common.mk
TWEAK_NAME = CPSSceneProbe
CPSSceneProbe_FILES = Tweak.xm
CPSSceneProbe_CFLAGS = -fobjc-arc
CPSSceneProbe_FRAMEWORKS = UIKit Foundation
include $(THEOS_MAKE_PATH)/tweak.mk
