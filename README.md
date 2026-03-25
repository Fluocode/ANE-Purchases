# 🧾 ANE Purchases (In‑App Billing) — `com.fluocode.extensions.billing`

AIR Native Extension (ANE) that bridges ActionScript 3 to native **Android Google Play Billing** and **iOS StoreKit** to sell:

- ✅ **Non‑consumables** (one‑time unlocks)
- ✅ **Consumables** (coins, lives, etc.)
- ✅ **Subscriptions** (auto‑renewing)

---

## ✨ Quick start

1. Add the ANE to your AIR project.
2. Add the app‑descriptor XML additions (Android + iOS) from the section below.
3. Call `Billing.init(...)` once at app startup and wait for the init callback.
4. Use `Billing.doPayment(...)` / `Billing.getPurchases(...)` in your UI.

---

## 📦 ActionScript API (snippets)

### ✅ Import

```actionscript
import com.fluocode.extensions.billing.Billing;
import com.fluocode.extensions.billing.BillingEvent;
import com.fluocode.extensions.billing.BillingType;
import com.fluocode.extensions.billing.FeatureType;
import com.fluocode.extensions.billing.ProrationMode;
import com.fluocode.extensions.billing.Purchase;
import com.fluocode.extensions.billing.Product;
```

### 🧩 `Billing.init(...)`

Call once and wait for success before using any other function.

```actionscript
// Optional configuration flags (set BEFORE Billing.init):
//
// iOS: Parental gate (app-controlled). If true, the native side may block purchase flow
// until you call Billing.continueThePreventedPurchaseFlow(). Use this only if you have
// your own parental consent UI/logic.
Billing.PARENTAL_GATE = false;
//
// Android: These flags are forwarded during init for child-directed / under-age-of-consent
// declarations. Valid values are:
//
// Billing.CHILD_DIRECTED (see ChildDirected):
// - 0 = UNSPECIFIED
// - 1 = CHILD_DIRECTED
// - 2 = NOT_CHILD_DIRECTED
//
// Billing.UNDER_AGE_OF_CONSENT (see UnderAgeOfConsent):
// - 0 = UNSPECIFIED
// - 1 = UNDER_AGE_OF_CONSENT
// - 2 = NOT_UNDER_AGE_OF_CONSENT
Billing.CHILD_DIRECTED = 0;
Billing.UNDER_AGE_OF_CONSENT = 0;

var androidInAppIds:Array = ["coins_100", "premium_unlock"];
var androidSubIds:Array = ["pro_monthly"];

var iosNonConsumables:Array = ["premium_unlock"];
var iosConsumables:Array = ["coins_100"];

Billing.init(
  androidInAppIds,
  androidSubIds,
  iosNonConsumables,
  iosConsumables,
  function(status:int, msg:String):void {
    if (status == 1) {
      trace("Billing init OK");
      for each (var p:Product in Billing.products) {
        trace(p.productId + " => " + p.price);
      }
    } else {
      trace("Billing init FAILED: " + msg);
    }
  }
);
```

### 🧾 `Billing.getPurchases(...)`

Fetches purchases and returns them as `Vector.<Purchase>`.

```actionscript
Billing.getPurchases(function(purchases:Vector.<Purchase>):void {
  if (!purchases) {
    trace("getPurchases failed");
    return;
  }
  for each (var p:Purchase in purchases) {
    trace("owned: " + p.productId + " token=" + p.purchaseToken);
  }
});
```

### 💳 `Billing.doPayment(...)`

Starts a purchase flow for a product id.

```actionscript
Billing.doPayment(
  BillingType.CONSUMABLE, // or PERMANENT / AUTO_RENEWAL
  "coins_100",
  "user123", // optional obfuscated account id
  function(status:int, purchase:Purchase, msg:String, isConsumable:Boolean):void {
    if (status == 1) {
      trace("Purchase OK: " + purchase.productId);

      // You typically unlock content here.
      // For Android consumables you may consume after you grant the item.
    } else {
      trace("Purchase FAILED: " + msg);
    }
  }
);
```

### 🔄 `Billing.replaceSubscription(...)` (subscriptions upgrade/downgrade)

```actionscript
Billing.replaceSubscription(
  "pro_monthly",
  "pro_yearly",
  ProrationMode.IMMEDIATE_WITH_TIME_PRORATION,
  "user123",
  function(status:int, purchase:Purchase, msg:String, isConsumable:Boolean):void {
    trace("replaceSubscription status=" + status + " msg=" + msg);
  }
);
```

### 🍽️ `Billing.forceConsume(...)` (Android consumables)

```actionscript
Billing.forceConsume("PURCHASE_TOKEN_HERE", function(success:Boolean):void {
  trace("consume: " + success);
});
```

### 🧷 `Billing.acknowledgePurchase(...)` (Android)

```actionscript
Billing.acknowledgePurchase("PURCHASE_TOKEN_HERE", function(error:String):void {
  if (error == null) trace("acknowledge OK");
  else trace("acknowledge FAILED: " + error);
});
```

### 🧾 `Billing.iOSReceipt` (iOS only)

```actionscript
var receipt:String = Billing.iOSReceipt; // base64 string, null on Android
trace(receipt);
```

### 🎟️ `Billing.redeem()` (iOS code redemption sheet)

```actionscript
Billing.redeem();
```

### 🔐 `Billing.publicKey` + `Billing.verifyAndroidPurchaseLocally(...)`

Local verification is **Android only** and should be treated as a convenience check. For real security, validate purchases on your server.

```actionscript
Billing.publicKey = "YOUR_BASE64_RSA_PUBLIC_KEY_FROM_PLAY_CONSOLE";

Billing.getPurchases(function(purchases:Vector.<Purchase>):void {
  if (!purchases || purchases.length == 0) return;
  var ok:Boolean = Billing.verifyAndroidPurchaseLocally(purchases[0]);
  trace("local verify: " + ok);
});
```

### 🧪 `Billing.isFeatureSupported(...)`

```actionscript
var ok:int = Billing.isFeatureSupported(FeatureType.SUBSCRIPTIONS);
trace("subscriptions support code: " + ok);
```

### 💬 `Billing.priceChangeConfirmation(...)`

```actionscript
Billing.priceChangeConfirmation("pro_monthly", function(agreed:Boolean, msg:String):void {
  trace("priceChange agreed=" + agreed + " msg=" + msg);
});
```

### 🚧 `Billing.continueThePreventedPurchaseFlow()`

Used by some iOS parental-gate flows.

```actionscript
Billing.continueThePreventedPurchaseFlow();
```

### 🧹 `Billing.clearCache()`

Clears the local purchase cache stored in app storage.

```actionscript
Billing.clearCache();
```

### 🧨 `Billing.dispose()`

```actionscript
Billing.dispose();
```

### 📣 Events via `Billing.listener`

```actionscript
Billing.listener.addEventListener(BillingEvent.SERVICE_DISCONNECTED, function(e:BillingEvent):void {
  trace("Billing service disconnected");
});

Billing.listener.addEventListener(BillingEvent.PARENT_PERMISSION_REQUIRED, function(e:BillingEvent):void {
  trace("Parental permission required: " + e.msg);
});
```

---

## 🧩 AIR app‑descriptor XML additions (required)

You must add the following to your AIR application descriptor.

### 🤖 Android: `manifestAdditions`

Add Google Play Billing permission and BillingClient proxy activity.

```xml
<android>
  <manifestAdditions><![CDATA[
    <manifest>
      <uses-permission android:name="android.permission.INTERNET"/>
      <uses-permission android:name="com.android.vending.BILLING"/>

      <application>
        <activity
          android:name="com.android.billingclient.api.ProxyBillingActivity"
          android:configChanges="keyboard|keyboardHidden|screenLayout|screenSize|orientation"
          android:theme="@android:style/Theme.Translucent.NoTitleBar"/>
      </application>
    </manifest>
  ]]></manifestAdditions>
</android>
```

### 🍎 iOS: `InfoAdditions`

This ANE does not require special `Info.plist` keys for basic purchases. A typical setup is:

```xml
<iPhone>
  <InfoAdditions><![CDATA[
    <key>LSApplicationQueriesSchemes</key>
    <array/>
  ]]></InfoAdditions>
</iPhone>
```

Also ensure your App ID has the **In‑App Purchase** capability enabled in Apple Developer / App Store Connect.

---

## 🔑 Keys / configuration you may need

### 🤖 Android: Google Play public key (for local verification)

If you use `Billing.publicKey` + `Billing.verifyAndroidPurchaseLocally(...)`, get your app’s **Base64‑encoded RSA public key** from:

1. Google Play Console → your app
2. Monetize → Monetization setup (or Licensing / public key section)

Set it in ActionScript:

```actionscript
Billing.publicKey = "YOUR_BASE64_RSA_PUBLIC_KEY";
```

### 🍎 iOS: receipt validation (server-side recommended)

If you validate purchases server‑side, you’ll typically use:

- The base64 receipt from `Billing.iOSReceipt`
- App Store Server API / receipt validation endpoints (your backend)

Apple subscription “shared secret” (if your backend needs it) is managed in App Store Connect under your app’s in‑app purchase / subscriptions settings.

---

## ✅ Notes for production

- Always validate entitlements on a trusted backend for security‑critical products.
- Keep your product ids identical across platforms when possible to simplify logic.
- For subscriptions, design your UI based on server truth (active entitlement), not only local caches.

***
If You like what I make please donate:
[![Foo](https://www.paypalobjects.com/en_GB/i/btn/btn_donate_SM.gif)](https://www.paypal.com/cgi-bin/webscr?cmd=_s-xclick&hosted_button_id=4QBWVDKEVRL46)
*** 