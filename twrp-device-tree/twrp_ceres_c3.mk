#
# Copyright (C) 2026 The Android Open Source Project
# Copyright (C) 2026 SebaUbuntu's TWRP device tree generator
#
# SPDX-License-Identifier: Apache-2.0
#

# Inherit from those products. Most specific first.
$(call inherit-product, $(SRC_TARGET_DIR)/product/core_64_bit.mk)
$(call inherit-product, $(SRC_TARGET_DIR)/product/base.mk)

# Inherit some common TWRP stuff.
$(call inherit-product, vendor/twrp/config/common.mk)

# Inherit from ceres_c3 device
$(call inherit-product, device/allwinner/ceres_c3/device.mk)

PRODUCT_DEVICE := ceres_c3
PRODUCT_NAME := twrp_ceres_c3
PRODUCT_BRAND := Allwinner
PRODUCT_MODEL := QUAD-CORE A133 c3
PRODUCT_MANUFACTURER := allwinner

PRODUCT_GMS_CLIENTID_BASE := android-allwinner

PRODUCT_BUILD_PROP_OVERRIDES += \
    PRIVATE_BUILD_DESC="ceres_c3-userdebug 10 QP1A.191105.004 723 test-keys"

BUILD_FINGERPRINT := Allwinner/ceres_c3/ceres_c3:10/QP1A.191105.004/723:userdebug/test-keys
