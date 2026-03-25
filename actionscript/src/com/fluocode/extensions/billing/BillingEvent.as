package com.fluocode.extensions.billing
{
	import flash.events.Event;
	
	/**
	 * Event dispatched by {@link Billing#listener}.
	 *
	 * <p>
	 * Most billing responses are delivered via callbacks passed to
	 * {@link Billing#init()}, {@link Billing#getPurchases()}, and
	 * {@link Billing#doPayment()}. This event is used for asynchronous
	 * notifications not tied to a specific callback (e.g. service disconnected,
	 * promo purchase flows, parental gate).
	 * </p>
	 */
	public class BillingEvent extends Event
	{
		internal static const INIT_SUCCESS:String = "onInitSuccess";
		internal static const INIT_FAIL:String = "onInitFail";
		internal static const PURCHASE_QUERY_SUCCESS:String = "onPurchaseQuerySuccess";
		internal static const PURCHASE_QUERY_FAILED:String = "onPurchaseQueryFailed";
		internal static const PURCHASE_SUCCESS:String = "onPurchaseSuccess";
		internal static const PURCHASE_FAILED:String = "onPurchaseFailed";
		internal static const RARE_ERROR:String = "onRareErrorOccured";
		internal static const PURCHASE_SUCCESS_PARTIALLY:String = "onPurchaseSuccessPartially";
		internal static const CONSUME_SUCCESS:String = "onConsumeSuccess";
		internal static const CONSUME_FAILED:String = "onConsumeFailed";
		internal static const PRICE_CHANGE_AGREED:String = "onPriceChangeAgreed";
		internal static const PRICE_CHANGE_DECLINED:String = "onPriceChangeDeclined";
		internal static const ACKNOWLEDGE_SUCCESS:String = "onAcknowledgeSuccess";
		internal static const ACKNOWLEDGE_FAILURE:String = "onAcknowledgeFailure";
		
		/** Billing service connection was lost. */
		public static const SERVICE_DISCONNECTED:String = "onServiceDisconnected";
		
		/** Promo purchase completed successfully (platform-dependent). */
		public static const PROMO_PURCHASE_SUCCESS:String = "onPromoPurchaseSuccess";
		
		/** Promo purchase failed (platform-dependent). */
		public static const PROMO_PURCHASE_FAILED:String = "onPromoPurchaseFailed";
		
		/** A parental permission step is required (iOS parental gate). */
		public static const PARENT_PERMISSION_REQUIRED:String = "onParentPermissionRequired";
		
		private var _msg:String;
		private var _status:int;
		private var _purchase:Purchase;
		
		/**
		 * Creates a new billing event.
		 *
		 * @param type Event type (one of the <code>public static const</code> values).
		 * @param msg Optional message.
		 * @param status Optional numeric status.
		 * @param purchase Optional purchase payload.
		 */
		public function BillingEvent(type:String, msg:String = null, status:int = -1, purchase:Purchase = null)
		{
			_msg = msg;
			_status = status;
			_purchase = purchase;
			super(type, false, false);
		}
		
		/** Optional message associated with this event. */
		public function get msg():String { return _msg; }
		
		/** Optional numeric status associated with this event. */
		public function get status():int { return _status; }
		
		/** Optional purchase payload associated with this event. */
		public function get purchase():Purchase { return _purchase; }
	}
}

