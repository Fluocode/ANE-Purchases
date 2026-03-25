package com.fluocode.extensions.billing
{
	/**
	 * Represents a purchase record returned by the platform store.
	 *
	 * <p>
	 * Instances are created by {@link PurchaseDB#orgenizePurchaseInfo()} from a
	 * native payload. Some fields are platform-specific (e.g. signatures on Android).
	 * </p>
	 */
	public class Purchase
	{
		private var _accountId:String = "";
		private var _purchaseToken:String;
		private var _billingType:int = -1;
		private var _orderId:String;
		private var _originalOrderId:String;
		private var _purchaseState:int;
		private var _productId:String;
		private var _purchaseTime:Number;
		private var _autoRenewing:Boolean;
		private var _signature:String = "";
		private var _developerPayload:String = "";
		private var _isAcknowledged:Boolean;
		private var _rawData:String;
		
		/**
		 * Creates an empty purchase instance.
		 * Instances are populated internally from native payload objects.
		 */
		public function Purchase() {}
		
		internal function setAndroid(raw:Object):void
		{
			_billingType = raw && raw.billingType != null ? int(raw.billingType) : -1;
			_orderId = raw ? raw.orderId : null;
			_originalOrderId = raw ? raw.orderId : null;
			_productId = raw ? raw.productId : null;
			_purchaseState = raw && raw.purchaseState != null ? int(raw.purchaseState) : -1;
			_purchaseTime = raw && raw.purchaseTime != null ? Number(raw.purchaseTime) : 0;
			_purchaseToken = raw ? raw.purchaseToken : null;
			_autoRenewing = raw ? Boolean(raw.autoRenewing) : false;
			_signature = raw ? String(raw.signature || "") : "";
			_developerPayload = raw ? String(raw.developerPayload || "") : "";
			_isAcknowledged = raw ? Boolean(raw.isAcknowledged) : false;
			_rawData = raw ? String(raw.getOriginalJson || raw.originalJson || "") : "";
		}
		
		internal function setIos(raw:Object):void
		{
			var parts:Array = raw && raw.accountId != null ? String(raw.accountId).split("@@@") : ["-1", ""];
			_billingType = parts.length > 0 ? int(parts[0]) : -1;
			_orderId = raw ? raw.orderId : null;
			_originalOrderId = raw ? raw.originalOrderId : null;
			_accountId = parts.length > 1 ? String(parts[1]) : "";
			_productId = raw ? raw.productId : null;
			_purchaseState = raw && raw.purchaseState != null ? int(raw.purchaseState) : -1;
			_purchaseTime = raw && raw.purchaseTime != null ? Number(raw.purchaseTime) : 0;
			_purchaseToken = raw ? raw.purchaseToken : null;
			_rawData = raw ? JSON.stringify(raw) : "{}";
		}
		
		internal function setData(raw:Object):void
		{
			_orderId = raw ? raw.orderId : null;
			_originalOrderId = raw ? raw.originalOrderId : null;
			_productId = raw ? raw.productId : null;
			_purchaseState = raw && raw.purchaseState != null ? int(raw.purchaseState) : -1;
			_purchaseTime = raw && raw.purchaseTime != null ? Number(raw.purchaseTime) : 0;
			_purchaseToken = raw ? raw.purchaseToken : null;
			_autoRenewing = raw && raw.autoRenewing != null ? int(raw.autoRenewing) > 0 : false;
			_isAcknowledged = raw && raw.isAcknowledged != null ? int(raw.isAcknowledged) > 0 : false;
			_signature = raw ? String(raw.signature || "") : "";
			_rawData = raw ? String(raw.rawData || "") : "";
		}
		
		/**
		 * Raw payload JSON (best-effort) received from native side.
		 */
		public function get rawData():String { return _rawData; }
		
		/**
		 * Android developer payload if provided by native side (legacy).
		 * @private
		 */
		internal function get developerPayload():String { return _developerPayload; }
		
		/** Purchase token (Android) or transaction identifier (iOS mapping). */
		public function get purchaseToken():String { return _purchaseToken; }
		
		/** Billing type (see {@link BillingType}). */
		public function get billingType():int { return _billingType; }
		
		/** Order identifier (platform-dependent). */
		public function get orderId():String { return _orderId; }
		
		/** Original order identifier for subscription renewals where available. */
		public function get originalOrderId():String { return _originalOrderId; }
		
		/** Purchase state (platform-dependent integer). */
		public function get purchaseState():int { return _purchaseState; }
		
		/** Purchased product id. */
		public function get productId():String { return _productId; }
		
		/** Purchase time in milliseconds since epoch (best-effort). */
		public function get purchaseTime():Number { return _purchaseTime; }
		
		/** Whether the purchase is auto-renewing (subscriptions). */
		public function get autoRenewing():Boolean { return _autoRenewing; }
		
		/** Whether the purchase has been acknowledged (Android). */
		public function get isAcknowledged():Boolean { return _isAcknowledged; }
		
		/** Signature (Android) used for local verification. */
		public function get signature():String { return _signature; }
	}
}

