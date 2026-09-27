include $(THEOS)/makefiles/common.mk

BUNDLE_NAME = CarPlayDSPPrefs
CarPlayDSPPrefs_FILES = CPDRootListController.m
CarPlayDSPPrefs_FRAMEWORKS = UIKit
CarPlayDSPPrefs_INSTALL_PATH = /Library/PreferenceBundles
CarPlayDSPPrefs_CFLAGS = -fobjc-arc
CarPlayDSPPrefs_LDFLAGS = -undefined dynamic_lookup
CarPlayDSPPrefs_RESOURCE_DIRS = Resources

include $(THEOS_MAKE_PATH)/bundle.mk

internal-stage::
	mkdir -p $(THEOS_STAGING_DIR)/Library/PreferenceLoader/Preferences
	cp layout/Library/PreferenceLoader/Preferences/CarPlayDSP.plist $(THEOS_STAGING_DIR)/Library/PreferenceLoader/Preferences/CarPlayDSP.plist
