package com.fluocode.ane;

import com.adobe.fre.FREContext;
import com.adobe.fre.FREExtension;

public class Billing implements FREExtension {
    private static FREContext context;

    @Override
    public FREContext createContext(String extData) {
        context = new BillingContext();
        return context;
    }

    @Override
    public void dispose() {
        if (context != null) {
            context.dispose();
            context = null;
        }
    }

    @Override
    public void initialize() {
        // no-op
    }
}

