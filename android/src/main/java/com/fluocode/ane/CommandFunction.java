package com.fluocode.ane;

import com.adobe.fre.FREArray;
import com.adobe.fre.FREContext;
import com.adobe.fre.FREFunction;
import com.adobe.fre.FREObject;

public class CommandFunction implements FREFunction {
    private final BillingContext ctx;

    public CommandFunction(BillingContext ctx) {
        this.ctx = ctx;
    }

    @Override
    public FREObject call(FREContext freContext, FREObject[] args) {
        String sub = FreUtil.getString(args, 0, "");
        try {
            ensureManager();

            switch (sub) {
                case "init": {
                    int childDirected = FreUtil.getInt(args, 1, 0);
                    int underAge = FreUtil.getInt(args, 2, 0);
                    FREArray inApps = FreUtil.getArray(args, 3);
                    FREArray subs = FreUtil.getArray(args, 4);
                    ctx.billingManager.init(childDirected, underAge, inApps, subs);
                    return null;
                }
                case "getPurchases": {
                    ctx.billingManager.queryPurchases();
                    return null;
                }
                case "doPayment": {
                    int type = FreUtil.getInt(args, 1, 0);
                    String productId = FreUtil.getString(args, 2, "");
                    String accountId = FreUtil.getString(args, 3, "");
                    ctx.billingManager.launchPurchaseFlow(type, productId, accountId, false, null, 0);
                    return null;
                }
                case "replaceSubscription": {
                    String oldProductId = FreUtil.getString(args, 1, "");
                    String newProductId = FreUtil.getString(args, 2, "");
                    int prorationMode = FreUtil.getInt(args, 3, 0);
                    String accountId = FreUtil.getString(args, 4, "");
                    ctx.billingManager.launchPurchaseFlow(BillingConstants.BILLING_TYPE_AUTO_RENEWAL, newProductId, accountId, true, oldProductId, prorationMode);
                    return null;
                }
                case "consume": {
                    String purchaseToken = FreUtil.getString(args, 1, "");
                    ctx.billingManager.consume(purchaseToken);
                    return null;
                }
                case "acknowledgePurchase": {
                    String purchaseToken = FreUtil.getString(args, 1, "");
                    ctx.billingManager.acknowledge(purchaseToken);
                    return null;
                }
                case "setPublicKey": {
                    String key = FreUtil.getString(args, 1, "");
                    ctx.billingManager.setPublicKey(key);
                    return null;
                }
                case "verify": {
                    String signedData = FreUtil.getString(args, 1, "");
                    String signature = FreUtil.getString(args, 2, "");
                    boolean ok = ctx.billingManager.verifyPurchase(signedData, signature);
                    return FREObject.newObject(ok);
                }
                case "isFeatureSupported": {
                    String feature = FreUtil.getString(args, 1, "");
                    int res = ctx.billingManager.isFeatureSupported(feature);
                    return FREObject.newObject(res);
                }
                case "priceChangeConfirmation": {
                    String productId = FreUtil.getString(args, 1, "");
                    ctx.billingManager.priceChangeConfirmation(productId);
                    return null;
                }
                case "continueThePreventedPurchaseFlow":
                case "redeem":
                case "dispose": {
                    ctx.dispose();
                    return null;
                }
                case "getReceipt": {
                    // iOS only
                    return null;
                }
                default:
                    return null;
            }
        } catch (Throwable t) {
            ctx.dispatch("onRareErrorOccured", "1|||" + (t.getMessage() == null ? "Unknown error" : t.getMessage()));
            return null;
        }
    }

    private void ensureManager() {
        if (ctx.billingManager == null) {
            ctx.billingManager = new BillingManager(ctx);
        }
    }
}

