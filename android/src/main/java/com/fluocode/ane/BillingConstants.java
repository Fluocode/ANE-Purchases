package com.fluocode.ane;

final class BillingConstants {
    private BillingConstants() {}

    static final int BILLING_TYPE_PERMANENT = 0;
    static final int BILLING_TYPE_CONSUMABLE = 1;
    static final int BILLING_TYPE_AUTO_RENEWAL = 2;

    static final int FEATURE_OK = 0;
    static final int FEATURE_NOT_SUPPORTED = -2;
}

