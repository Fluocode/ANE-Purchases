package com.fluocode.extensions.billing
{
	/**
	 * Proration mode constants for Android subscription replacement.
	 *
	 * @see Billing#replaceSubscription()
	 */
	public final class ProrationMode
	{
		public static const UNKNOWN_SUBSCRIPTION_UPGRADE_DOWNGRADE_POLICY:int = 0;
		public static const IMMEDIATE_WITH_TIME_PRORATION:int = 1;
		public static const IMMEDIATE_AND_CHARGE_PRORATED_PRICE:int = 2;
		public static const IMMEDIATE_WITHOUT_PRORATION:int = 3;
		public static const DEFERRED:int = 4;
	}
}

