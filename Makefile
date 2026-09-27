ARCHS = arm64 arm64e
TARGET = iphone:clang:latest:15.0
THEOS_PACKAGE_SCHEME = rootless

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = CarPlayDSP
CarPlayDSP_FILES = Tweak.xm DSP/Biquad.cpp
CarPlayDSP_CFLAGS = -fobjc-arc
CarPlayDSP_CCFLAGS = -std=c++17
CarPlayDSP_FRAMEWORKS = AVFAudio AudioToolbox Foundation
CarPlayDSP_LIBRARIES = substrate

include $(THEOS_MAKE_PATH)/tweak.mk

after-install::
	install.exec "killall mediaserverd 2>/dev/null || true"
