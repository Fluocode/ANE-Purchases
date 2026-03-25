package com.fluocode.extensions.billing
{
	/**
	 * Product metadata returned by the store during {@link Billing#init()}.
	 *
	 * <p>
	 * The native side provides a plain Object which is mapped into this class.
	 * Not all fields are available on every platform.
	 * </p>
	 */
	public class Product
	{
		private var _currency:String;
		private var _description:String;
		private var _price:String;
		private var _productId:String;
		private var _title:String;
		private var _hashCode:String;
		private var _originalJson:String;
		private var _freeTrialPeriod:String;
		private var _introductoryPrice:String;
		private var _introductoryPriceAmountMicros:Number;
		private var _introductoryPriceCycles:String;
		private var _introductoryPricePeriod:String;
		private var _subscriptionPeriod:String;
		private var _paymentMode:String;
		
		/**
		 * @private
		 * Constructed internally by {@link Billing} from a native payload object.
		 */
		public function Product(raw:Object)
		{
			_currency = raw ? raw.currency : null;
			_description = raw ? raw.description : null;
			_price = raw ? raw.price : null;
			_productId = raw ? raw.productId : null;
			_title = raw ? raw.title : null;
			_subscriptionPeriod = raw ? raw.subscriptionPeriod : null;
			_hashCode = raw ? raw.hashCode : null;
			_originalJson = raw ? raw.originalJson : null;
			_freeTrialPeriod = raw ? raw.freeTrialPeriod : null;
			_introductoryPrice = raw ? raw.introductoryPrice : null;
			_introductoryPriceAmountMicros = raw && raw.introductoryPriceAmountMicros != null ? Number(raw.introductoryPriceAmountMicros) : 0;
			_introductoryPriceCycles = raw ? raw.introductoryPriceCycles : null;
			_introductoryPricePeriod = raw ? raw.introductoryPricePeriod : null;
			_paymentMode = raw ? raw.paymentMode : null;
		}
		
		/** Payment mode string (platform-dependent). */
		public function get paymentMode():String { return _paymentMode; }
		/** Subscription billing period (e.g. "P1M") when available. */
		public function get subscriptionPeriod():String { return _subscriptionPeriod; }
		/** Introductory price period when available. */
		public function get introductoryPricePeriod():String { return _introductoryPricePeriod; }
		/** Introductory price cycles when available. */
		public function get introductoryPriceCycles():String { return _introductoryPriceCycles; }
		/** Introductory price micros when available (Android). */
		public function get introductoryPriceAmountMicros():Number { return _introductoryPriceAmountMicros; }
		/** Introductory price formatted string when available. */
		public function get introductoryPrice():String { return _introductoryPrice; }
		/** Free trial period string when available. */
		public function get freeTrialPeriod():String { return _freeTrialPeriod; }
		/** Native payload JSON (best-effort). */
		public function get originalJson():String { return _originalJson; }
		/** A stable hash identifier from native side (best-effort). */
		public function get hashCode():String { return _hashCode; }
		/** Currency code (e.g. "USD"). */
		public function get currency():String { return _currency; }
		/** Localized description. */
		public function get description():String { return _description; }
		/** Localized formatted price string. */
		public function get price():String { return _price; }
		/** Store product id. */
		public function get productId():String { return _productId; }
		/** Localized title. */
		public function get title():String { return _title; }
	}
}

