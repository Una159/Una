ARCHS = arm64 arm64e
TARGET = iphone:clang:latest:15.0
THEOS_PACKAGE_SCHEME = rootless
INSTALL_TARGET_PROCESSES = SpringBoard

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = NaiWa
NaiWa_FILES = Tweak.xm NWConfig.m NWHookRegistry.m
NaiWa_CFLAGS = -fobjc-arc -Wall
NaiWa_FRAMEWORKS = UIKit Foundation

include $(THEOS_MAKE_PATH)/tweak.mk
