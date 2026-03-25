# Android (libInAppBilling.jar)

This folder builds the Android native side of the AIR ANE.

## Output

- `android/libs/libInAppBilling.jar` (your extension classes: `com.fluocode.ane.*`)

Note: Google Play Billing is a Gradle dependency. When packaging the ANE, you must also include the BillingClient runtime dependency (and transitive deps) in the ANE Android platform libs, or package them via your ANE toolchain.

## Build (Android Studio / Gradle)

1. Install **Android Studio** (includes Android SDK + Gradle).
2. Open the `android/` folder as a project.
3. Run Gradle task `build` (or `makeJar`).

The `makeJar` task extracts `classes.jar` from the release AAR and renames it to `libInAppBilling.jar` in `android/libs/`.

