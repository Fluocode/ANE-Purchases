package com.fluocode.extensions.billing
{
	/**
	 * Response / status constants.
	 *
	 * <p>
	 * These values are aligned with the legacy BillingClient response codes used by older ANE APIs.
	 * Modern native implementations may map platform codes into this set.
	 * </p>
	 */
	public final class BillingResponse
	{
		public static const SERVICE_TIMEOUT:int = -3;
		public static const FEATURE_NOT_SUPPORTED:int = -2;
		public static const SERVICE_DISCONNECTED:int = -1;
		public static const OK:int = 0;
		public static const USER_CANCELED:int = 1;
		public static const SERVICE_UNAVAILABLE:int = 2;
		public static const BILLING_UNAVAILABLE:int = 3;
		public static const ITEM_UNAVAILABLE:int = 4;
		public static const DEVELOPER_ERROR:int = 5;
		public static const ERROR:int = 6;
		public static const ITEM_ALREADY_OWNED:int = 7;
		public static const ITEM_NOT_OWNED:int = 8;
	}
}

