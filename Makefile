ARCHS = arm64 arm64e
TARGET = iphone:clang:latest:14.0
INSTALL_TARGET_PROCESSES = Aweme

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = KDouyinUltra

KDouyinUltra_FILES = KDU.xm \
    KDUConfigManager.m \
    KDUFeatureRegistry.m \
    KDUCompatibility.m \
    KDUSettingsController.m \
    KDUFloatingLauncher.m

KDouyinUltra_CFLAGS = -fobjc-arc -Wno-deprecated-declarations
KDouyinUltra_FRAMEWORKS = UIKit Foundation
KDouyinUltra_INSTALL_PATH = /Library/MobileSubstrate/DynamicLibraries

include $(THEOS_MAKE_PATH)/tweak.mk