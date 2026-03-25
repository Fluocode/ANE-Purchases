package com.fluocode.ane;

import android.app.Activity;

import com.adobe.fre.FREArray;
import com.android.billingclient.api.AcknowledgePurchaseParams;
import com.android.billingclient.api.AcknowledgePurchaseResponseListener;
import com.android.billingclient.api.BillingClient;
import com.android.billingclient.api.BillingClientStateListener;
import com.android.billingclient.api.BillingFlowParams;
import com.android.billingclient.api.BillingResult;
import com.android.billingclient.api.ConsumeParams;
import com.android.billingclient.api.ConsumeResponseListener;
import com.android.billingclient.api.PendingPurchasesParams;
import com.android.billingclient.api.ProductDetails;
import com.android.billingclient.api.Purchase;
import com.android.billingclient.api.PurchasesUpdatedListener;
import com.android.billingclient.api.QueryProductDetailsParams;
import com.android.billingclient.api.QueryProductDetailsResult;
import com.android.billingclient.api.QueryPurchasesParams;

import org.json.JSONArray;
import org.json.JSONObject;

import java.nio.charset.StandardCharsets;
import java.security.KeyFactory;
import java.security.PublicKey;
import java.security.Signature;
import java.security.spec.X509EncodedKeySpec;
import java.util.ArrayList;
import java.util.Base64;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

final class BillingManager {
    private final BillingContext ctx;
    private BillingClient billingClient;

    private final Map<String, ProductDetails> productDetailsById = new HashMap<>();
    private final Map<String, String> firstOfferTokenByProductId = new HashMap<>();
    private final List<String> inAppIds = new ArrayList<>();
    private final List<String> subIds = new ArrayList<>();

    private String publicKeyBase64 = "";

    BillingManager(BillingContext ctx) {
        this.ctx = ctx;
    }

    void init(int childDirected, int underAge, FREArray inApps, FREArray subs) {
        inAppIds.clear();
        subIds.clear();
        inAppIds.addAll(FreUtil.toStringList(inApps));
        subIds.addAll(FreUtil.toStringList(subs));

        createClientIfNeeded();
        startConnectionAndFetchProducts();
    }

    void dispose() {
        if (billingClient != null) {
            try {
                billingClient.endConnection();
            } catch (Throwable ignored) {
            }
        }
        billingClient = null;
        productDetailsById.clear();
        firstOfferTokenByProductId.clear();
    }

    void setPublicKey(String base64) {
        publicKeyBase64 = base64 == null ? "" : base64.trim();
    }

    boolean verifyPurchase(String signedData, String signature) {
        if (publicKeyBase64.isEmpty()) return false;
        try {
            PublicKey key = decodePublicKey(publicKeyBase64);
            byte[] sigBytes = Base64.getDecoder().decode(signature);
            byte[] dataBytes = signedData.getBytes(StandardCharsets.UTF_8);

            // Play Billing signatures have historically been verified with SHA1withRSA.
            // We also attempt SHA256withRSA as a fallback for broader compatibility.
            if (verifyWithAlgorithm("SHA1withRSA", key, dataBytes, sigBytes)) return true;
            return verifyWithAlgorithm("SHA256withRSA", key, dataBytes, sigBytes);
        } catch (Throwable t) {
            return false;
        }
    }

    int isFeatureSupported(String feature) {
        createClientIfNeeded();
        if (billingClient == null) return BillingConstants.FEATURE_NOT_SUPPORTED;

        // Feature names are passed from ActionScript (see FeatureType).
        String billingFeature;
        if ("subscriptions".equals(feature)) {
            billingFeature = BillingClient.FeatureType.SUBSCRIPTIONS;
        } else if ("subscriptionsUpdate".equals(feature)) {
            billingFeature = BillingClient.FeatureType.SUBSCRIPTIONS_UPDATE;
        } else if ("priceChangeConfirmation".equals(feature)) {
            // Recent Billing versions do not provide a stable equivalent for this legacy flow.
            return BillingConstants.FEATURE_NOT_SUPPORTED;
        } else {
            return BillingConstants.FEATURE_NOT_SUPPORTED;
        }

        BillingResult r = billingClient.isFeatureSupported(billingFeature);
        return r.getResponseCode() == BillingClient.BillingResponseCode.OK
                ? BillingConstants.FEATURE_OK
                : BillingConstants.FEATURE_NOT_SUPPORTED;
    }

    void priceChangeConfirmation(String productId) {
        // Recent Billing versions do not provide a stable equivalent for this legacy flow.
        // To keep the AS3 API stable, report this as declined.
        ctx.dispatch("onPriceChangeDeclined", "Not supported");
    }

    void queryPurchases() {
        createClientIfNeeded();
        if (billingClient == null) {
            ctx.dispatch("onPurchaseQueryFailed", "");
            return;
        }

        ensureReady(new Runnable() {
            @Override
            public void run() {
                List<JSONObject> out = new ArrayList<>();

                queryPurchasesType(BillingClient.ProductType.INAPP, out, new Runnable() {
                    @Override
                    public void run() {
                        queryPurchasesType(BillingClient.ProductType.SUBS, out, new Runnable() {
                            @Override
                            public void run() {
                                JSONArray arr = new JSONArray();
                                for (JSONObject o : out) arr.put(o);
                                ctx.dispatch("onPurchaseQuerySuccess", arr.toString());
                            }
                        });
                    }
                });
            }
        });
    }

    void launchPurchaseFlow(int billingType, String productId, String accountId, boolean isReplace, String oldProductId, int prorationMode) {
        Activity activity = ctx.getActivitySafe();
        if (activity == null) {
            ctx.dispatch("onPurchaseFailed", "1|||No Activity");
            return;
        }

        ensureReady(new Runnable() {
            @Override
            public void run() {
                ProductDetails pd = productDetailsById.get(productId);
                if (pd == null) {
                    ctx.dispatch("onPurchaseFailed", "1|||This item not found on Google or Apple servers.");
                    return;
                }

                BillingFlowParams.ProductDetailsParams.Builder pdParams =
                        BillingFlowParams.ProductDetailsParams.newBuilder().setProductDetails(pd);

                String offerToken = firstOfferTokenByProductId.get(productId);
                if (offerToken != null && !offerToken.isEmpty()) {
                    pdParams.setOfferToken(offerToken);
                }

                BillingFlowParams.Builder flow = BillingFlowParams.newBuilder()
                        .setProductDetailsParamsList(java.util.Collections.singletonList(pdParams.build()));

                if (accountId != null && !accountId.isEmpty()) {
                    flow.setObfuscatedAccountId(accountId);
                }

                if (isReplace && oldProductId != null && !oldProductId.isEmpty()) {
                    // Find old purchase token
                    findPurchaseTokenForProduct(oldProductId, new PurchaseTokenCallback() {
                        @Override
                        public void onResult(String oldToken) {
                            if (oldToken == null || oldToken.isEmpty()) {
                                ctx.dispatch("onPurchaseFailed", "1|||Old subscription not owned.");
                                return;
                            }
                            BillingFlowParams.SubscriptionUpdateParams sup = BillingFlowParams.SubscriptionUpdateParams.newBuilder()
                                    .setOldPurchaseToken(oldToken)
                                    .build();
                            flow.setSubscriptionUpdateParams(sup);

                            BillingResult r = billingClient.launchBillingFlow(activity, flow.build());
                            if (r.getResponseCode() != BillingClient.BillingResponseCode.OK) {
                                ctx.dispatch("onPurchaseFailed", "1|||" + r.getDebugMessage());
                            }
                        }
                    });
                    return;
                }

                BillingResult r = billingClient.launchBillingFlow(activity, flow.build());
                if (r.getResponseCode() != BillingClient.BillingResponseCode.OK) {
                    ctx.dispatch("onPurchaseFailed", "1|||" + r.getDebugMessage());
                }
            }
        });
    }

    void consume(String purchaseToken) {
        ensureReady(new Runnable() {
            @Override
            public void run() {
                ConsumeParams params = ConsumeParams.newBuilder().setPurchaseToken(purchaseToken).build();
                billingClient.consumeAsync(params, new ConsumeResponseListener() {
                    @Override
                    public void onConsumeResponse(BillingResult billingResult, String token) {
                        if (billingResult.getResponseCode() == BillingClient.BillingResponseCode.OK) {
                            ctx.dispatch("onConsumeSuccess", "");
                        } else {
                            ctx.dispatch("onConsumeFailed", billingResult.getDebugMessage());
                        }
                    }
                });
            }
        });
    }

    void acknowledge(String purchaseToken) {
        ensureReady(new Runnable() {
            @Override
            public void run() {
                AcknowledgePurchaseParams params = AcknowledgePurchaseParams.newBuilder()
                        .setPurchaseToken(purchaseToken)
                        .build();
                billingClient.acknowledgePurchase(params, new AcknowledgePurchaseResponseListener() {
                    @Override
                    public void onAcknowledgePurchaseResponse(BillingResult billingResult) {
                        if (billingResult.getResponseCode() == BillingClient.BillingResponseCode.OK) {
                            ctx.dispatch("onAcknowledgeSuccess", "");
                        } else {
                            ctx.dispatch("onAcknowledgeFailure", billingResult.getDebugMessage());
                        }
                    }
                });
            }
        });
    }

    // ---------------- internals ----------------

    private void createClientIfNeeded() {
        if (billingClient != null) return;

        PurchasesUpdatedListener purchasesUpdatedListener = new PurchasesUpdatedListener() {
            @Override
            public void onPurchasesUpdated(BillingResult billingResult, List<Purchase> purchases) {
                int code = billingResult.getResponseCode();
                if (code == BillingClient.BillingResponseCode.OK && purchases != null && !purchases.isEmpty()) {
                    // Send first purchase only (matches old AS3 flow)
                    JSONObject p = toPurchaseJson(purchases.get(0));
                    ctx.dispatch("onPurchaseSuccess", "1|||" + p.toString());
                } else if (code == BillingClient.BillingResponseCode.USER_CANCELED) {
                    ctx.dispatch("onPurchaseFailed", "1|||User canceled");
                } else {
                    ctx.dispatch("onPurchaseFailed", "1|||" + billingResult.getDebugMessage());
                }
            }
        };

        billingClient = BillingClient.newBuilder(ctx.getActivitySafe() != null ? ctx.getActivitySafe() : null)
                .setListener(purchasesUpdatedListener)
                .enablePendingPurchases(
                        PendingPurchasesParams.newBuilder()
                                .enableOneTimeProducts()
                                .build()
                )
                .build();
    }

    private void startConnectionAndFetchProducts() {
        if (billingClient == null) {
            ctx.dispatch("onInitFail", "BillingClient is null");
            return;
        }

        billingClient.startConnection(new BillingClientStateListener() {
            @Override
            public void onBillingSetupFinished(BillingResult billingResult) {
                if (billingResult.getResponseCode() != BillingClient.BillingResponseCode.OK) {
                    ctx.dispatch("onInitFail", billingResult.getDebugMessage());
                    return;
                }
                fetchProductsAndDispatchInit();
            }

            @Override
            public void onBillingServiceDisconnected() {
                ctx.dispatch("onServiceDisconnected", "");
            }
        });
    }

    private void ensureReady(Runnable run) {
        if (billingClient == null) {
            ctx.dispatch("onInitFail", "Billing not initialized");
            return;
        }
        // If not ready, try to reconnect once
        if (!billingClient.isReady()) {
            billingClient.startConnection(new BillingClientStateListener() {
                @Override
                public void onBillingSetupFinished(BillingResult billingResult) {
                    if (billingResult.getResponseCode() == BillingClient.BillingResponseCode.OK) {
                        run.run();
                    } else {
                        ctx.dispatch("onRareErrorOccured", "1|||" + billingResult.getDebugMessage());
                    }
                }

                @Override
                public void onBillingServiceDisconnected() {
                    ctx.dispatch("onServiceDisconnected", "");
                }
            });
            return;
        }
        run.run();
    }

    private void fetchProductsAndDispatchInit() {
        List<QueryProductDetailsParams.Product> products = new ArrayList<>();
        for (String id : inAppIds) {
            products.add(QueryProductDetailsParams.Product.newBuilder()
                    .setProductId(id)
                    .setProductType(BillingClient.ProductType.INAPP)
                    .build());
        }
        for (String id : subIds) {
            products.add(QueryProductDetailsParams.Product.newBuilder()
                    .setProductId(id)
                    .setProductType(BillingClient.ProductType.SUBS)
                    .build());
        }

        QueryProductDetailsParams params = QueryProductDetailsParams.newBuilder()
                .setProductList(products)
                .build();

        billingClient.queryProductDetailsAsync(params, (billingResult, queryResult) -> {
            if (billingResult.getResponseCode() != BillingClient.BillingResponseCode.OK) {
                ctx.dispatch("onInitFail", billingResult.getDebugMessage());
                return;
            }

            productDetailsById.clear();
            firstOfferTokenByProductId.clear();

            JSONArray out = new JSONArray();
            List<ProductDetails> productDetailsList = extractProductDetailsList(queryResult);
            for (ProductDetails pd : productDetailsList) {
                productDetailsById.put(pd.getProductId(), pd);
                JSONObject o = toProductJson(pd);
                out.put(o);
            }

            ctx.dispatch("onInitSuccess", out.toString());
        });
    }

    private static List<ProductDetails> extractProductDetailsList(QueryProductDetailsResult result) {
        try {
            if (result != null && result.getProductDetailsList() != null) return result.getProductDetailsList();
        } catch (Throwable ignored) {
        }
        return java.util.Collections.emptyList();
    }

    private JSONObject toProductJson(ProductDetails pd) {
        JSONObject o = new JSONObject();
        try {
            o.put("currency", currencyFrom(pd));
            o.put("description", pd.getDescription());
            o.put("price", priceFrom(pd));
            o.put("productId", pd.getProductId());
            o.put("title", pd.getTitle());
            o.put("subscriptionPeriod", subscriptionPeriodFrom(pd));
            o.put("hashCode", String.valueOf(pd.hashCode()));
            o.put("originalJson", safeOriginalJson(pd));

            o.put("freeTrialPeriod", "");
            o.put("introductoryPrice", "");
            o.put("introductoryPriceAmountMicros", 0);
            o.put("introductoryPriceCycles", "");
            o.put("introductoryPricePeriod", "");
            o.put("paymentMode", "");

            String offerToken = firstOfferToken(pd);
            if (offerToken != null) firstOfferTokenByProductId.put(pd.getProductId(), offerToken);
        } catch (Throwable ignored) {
        }
        return o;
    }

    private JSONObject toPurchaseJson(Purchase p) {
        JSONObject o = new JSONObject();
        try {
            // Best-effort mapping to the fields AS3 expects
            int billingType = subIds.contains(anyProductId(p)) ? BillingConstants.BILLING_TYPE_AUTO_RENEWAL : BillingConstants.BILLING_TYPE_PERMANENT;
            o.put("billingType", billingType);
            o.put("orderId", p.getOrderId() == null ? "" : p.getOrderId());
            o.put("productId", anyProductId(p));
            o.put("purchaseState", p.getPurchaseState());
            o.put("purchaseTime", p.getPurchaseTime());
            o.put("purchaseToken", p.getPurchaseToken());
            o.put("autoRenewing", p.isAutoRenewing());
            o.put("signature", p.getSignature() == null ? "" : p.getSignature());
            o.put("developerPayload", "");
            o.put("isAcknowledged", p.isAcknowledged());
            o.put("getOriginalJson", p.getOriginalJson());
        } catch (Throwable ignored) {
        }
        return o;
    }

    private void queryPurchasesType(String type, List<JSONObject> out, Runnable done) {
        billingClient.queryPurchasesAsync(
                QueryPurchasesParams.newBuilder().setProductType(type).build(),
                (billingResult, purchasesList) -> {
                    if (billingResult.getResponseCode() == BillingClient.BillingResponseCode.OK && purchasesList != null) {
                        for (Purchase p : purchasesList) out.add(toPurchaseJson(p));
                    }
                    done.run();
                }
        );
    }

    private interface PurchaseTokenCallback {
        void onResult(String token);
    }

    private void findPurchaseTokenForProduct(String productId, PurchaseTokenCallback cb) {
        billingClient.queryPurchasesAsync(
                QueryPurchasesParams.newBuilder().setProductType(BillingClient.ProductType.SUBS).build(),
                (billingResult, purchases) -> {
                    if (billingResult.getResponseCode() == BillingClient.BillingResponseCode.OK && purchases != null) {
                        for (Purchase p : purchases) {
                            if (p.getProducts() != null && p.getProducts().contains(productId)) {
                                cb.onResult(p.getPurchaseToken());
                                return;
                            }
                        }
                    }
                    cb.onResult("");
                }
        );
    }

    private static String anyProductId(Purchase p) {
        try {
            if (p.getProducts() != null && !p.getProducts().isEmpty()) return p.getProducts().get(0);
        } catch (Throwable ignored) {
        }
        return "";
    }

    private static String firstOfferToken(ProductDetails pd) {
        try {
            if (pd.getSubscriptionOfferDetails() != null && !pd.getSubscriptionOfferDetails().isEmpty()) {
                ProductDetails.SubscriptionOfferDetails od = pd.getSubscriptionOfferDetails().get(0);
                return od.getOfferToken();
            }
        } catch (Throwable ignored) {
        }
        return null;
    }

    private static String currencyFrom(ProductDetails pd) {
        try {
            ProductDetails.OneTimePurchaseOfferDetails ot = pd.getOneTimePurchaseOfferDetails();
            if (ot != null) return ot.getPriceCurrencyCode();
            if (pd.getSubscriptionOfferDetails() != null && !pd.getSubscriptionOfferDetails().isEmpty()) {
                ProductDetails.SubscriptionOfferDetails od = pd.getSubscriptionOfferDetails().get(0);
                if (od.getPricingPhases() != null && od.getPricingPhases().getPricingPhaseList() != null
                        && !od.getPricingPhases().getPricingPhaseList().isEmpty()) {
                    return od.getPricingPhases().getPricingPhaseList().get(0).getPriceCurrencyCode();
                }
            }
        } catch (Throwable ignored) {
        }
        return "";
    }

    private static String priceFrom(ProductDetails pd) {
        try {
            ProductDetails.OneTimePurchaseOfferDetails ot = pd.getOneTimePurchaseOfferDetails();
            if (ot != null) return ot.getFormattedPrice();
            if (pd.getSubscriptionOfferDetails() != null && !pd.getSubscriptionOfferDetails().isEmpty()) {
                ProductDetails.SubscriptionOfferDetails od = pd.getSubscriptionOfferDetails().get(0);
                if (od.getPricingPhases() != null && od.getPricingPhases().getPricingPhaseList() != null
                        && !od.getPricingPhases().getPricingPhaseList().isEmpty()) {
                    return od.getPricingPhases().getPricingPhaseList().get(0).getFormattedPrice();
                }
            }
        } catch (Throwable ignored) {
        }
        return "";
    }

    private static String subscriptionPeriodFrom(ProductDetails pd) {
        try {
            if (pd.getSubscriptionOfferDetails() != null && !pd.getSubscriptionOfferDetails().isEmpty()) {
                ProductDetails.SubscriptionOfferDetails od = pd.getSubscriptionOfferDetails().get(0);
                if (od.getPricingPhases() != null && od.getPricingPhases().getPricingPhaseList() != null
                        && !od.getPricingPhases().getPricingPhaseList().isEmpty()) {
                    return od.getPricingPhases().getPricingPhaseList().get(0).getBillingPeriod();
                }
            }
        } catch (Throwable ignored) {
        }
        return "";
    }

    private static String safeOriginalJson(ProductDetails pd) {
        // ProductDetails does not expose originalJson like old SkuDetails.
        // Provide a stable, useful JSON payload instead.
        try {
            JSONObject o = new JSONObject();
            o.put("productId", pd.getProductId());
            o.put("productType", pd.getProductType());
            o.put("title", pd.getTitle());
            o.put("description", pd.getDescription());
            o.put("name", pd.getName());
            return o.toString();
        } catch (Throwable t) {
            return "{}";
        }
    }

    private static PublicKey decodePublicKey(String base64Key) throws Exception {
        byte[] decoded = Base64.getDecoder().decode(base64Key);
        X509EncodedKeySpec spec = new X509EncodedKeySpec(decoded);
        return KeyFactory.getInstance("RSA").generatePublic(spec);
    }

    private static boolean verifyWithAlgorithm(String algo, PublicKey key, byte[] data, byte[] sigBytes) throws Exception {
        Signature sig = Signature.getInstance(algo);
        sig.initVerify(key);
        sig.update(data);
        return sig.verify(sigBytes);
    }
}

