package com.fluocode.ane;

import android.app.Activity;
import android.os.Handler;
import android.os.Looper;

import com.adobe.fre.FREContext;
import com.adobe.fre.FREFunction;

import java.util.HashMap;
import java.util.Map;

public class BillingContext extends FREContext {
    final Handler mainHandler = new Handler(Looper.getMainLooper());
    BillingManager billingManager;

    @Override
    public Map<String, FREFunction> getFunctions() {
        Map<String, FREFunction> map = new HashMap<>();
        map.put("command", new CommandFunction(this));
        return map;
    }

    Activity getActivitySafe() {
        try {
            return getActivity();
        } catch (Throwable t) {
            return null;
        }
    }

    void dispatch(final String code, final String level) {
        try {
            dispatchStatusEventAsync(code, level == null ? "" : level);
        } catch (Throwable ignored) {
        }
    }

    @Override
    public void dispose() {
        if (billingManager != null) {
            billingManager.dispose();
            billingManager = null;
        }
    }
}

