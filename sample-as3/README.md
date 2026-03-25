# 🧪 Sample AIR app (AS3) — Billing ANE test

This is a minimal ActionScript 3 AIR app to test the ANE:

- Extension id: `com.fluocode.extensions.billing`
- Class API: `com.fluocode.extensions.billing.Billing`

---

## ✅ What it tests

- `Billing.init(...)`
- `Billing.getPurchases(...)`
- `Billing.doPayment(...)`
- `Billing.iOSReceipt` (iOS only)
- `Billing.redeem()` (iOS only)
- Listener events (`BillingEvent.SERVICE_DISCONNECTED`, `BillingEvent.PARENT_PERMISSION_REQUIRED`)

---

## 📁 Project layout

- `src/` ActionScript source
- `application/TestBilling-app.xml` AIR app descriptor (includes Android manifest additions)
- `extensions/` put your `.ane` file(s) here

---

## ⚙️ Configure product ids

Edit in `src/Main.as`:

- `ANDROID_INAPP_IDS`
- `ANDROID_SUB_IDS`
- `IOS_NONCONSUMABLE_IDS`
- `IOS_CONSUMABLE_IDS`

---

## ▶️ Run it

Use your preferred AIR workflow (Animate, Flash Builder, IntelliJ, or ADT).

Minimum requirements:

1. Add the ANE to the build (extension id must match `com.fluocode.extensions.billing`).
2. Ensure the app descriptor points to the ANE id under `<extensions>`.
3. On Android, keep the required `manifestAdditions` (already included in `TestBilling-app.xml`).

