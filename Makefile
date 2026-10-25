ARCHS = arm64 arm64e
TARGET = iphone:clang:latest:14.0
INSTALL_TARGET_PROCESSES = Aweme

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = KDouyinUltra
KDouyinUltra_FILES = KDU.xm \
    Sources/Core/KDUConfigManager.m \
    Sources/Core/KDUFeatureRegistry.m \
    Sources/Core/KDUCompatibility.m \
    Sources/Settings/KDUSettingsController.m \
    Sources/Settings/KDUFloatingLauncher.m \
    Sources/Modules/KDUModulePlaceholders.m
KDouyinUltra_CFLAGS = -fobjc-arc -Wno-deprecated-declarations
KDouyinUltra_CCFLAGS = -std=c++17
KDouyinUltra_FRAMEWORKS = UIKit Foundation
KDouyinUltra_PRIVATE_FRAMEWORKS =
KDouyinUltra_INSTALL_PATH = /Library/MobileSubstrate/DynamicLibraries

include $(THEOS_MAKE_PATH)/tweak.mk

# Shared-source raw dylib build for IPA injection:
# make clean && make KDU_BUILD_IPA=1
ifeq ($(KDU_BUILD_IPA),1)
PACKAGE_NAME :=
include $(THEOS_MAKE_PATH)/aggregate.mk
endif
