package com.fluocode.extensions.billing
{
	/**
	 * Billing type constants used by {@link Billing#doPayment()}.
	 */
	public final class BillingType
	{
		/** Non-consumable / permanently owned product. */
		public static const PERMANENT:int = 0;
		/** Consumable product. */
		public static const CONSUMABLE:int = 1;
		/** Auto-renewing subscription. */
		public static const AUTO_RENEWAL:int = 2;
	}
}

