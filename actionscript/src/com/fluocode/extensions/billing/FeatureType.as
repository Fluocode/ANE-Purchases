package com.fluocode.extensions.billing
{
	/**
	 * Feature names used with {@link Billing#isFeatureSupported()}.
	 */
	public final class FeatureType
	{
		/** Request price change confirmation flow when supported. */
		public static const PRICE_CHANGE_CONFIRMATION:String = "priceChangeConfirmation";
		/** Indicates subscription purchases are supported. */
		public static const SUBSCRIPTIONS:String = "subscriptions";
		/** Indicates subscription replacement/upgrade flow is supported (Android). */
		public static const SUBSCRIPTIONS_UPDATE:String = "subscriptionsUpdate";
	}
}

