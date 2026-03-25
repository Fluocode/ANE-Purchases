package com.fluocode.extensions.billing
{
	import flash.events.EventDispatcher;
	import flash.events.StatusEvent;
	import flash.external.ExtensionContext;
	import flash.filesystem.File;
	import flash.system.Capabilities;
	import flash.utils.setTimeout;
	
	/**
	 * AIR Native Extension bridge for in-app purchases.
	 *
	 * <p>
	 * This class provides a stable ActionScript API that forwards calls to the native
	 * implementations (Android and iOS) through {@link flash.external.ExtensionContext}.
	 * </p>
	 *
	 * <p>
	 * Native side communicates back using {@link flash.events.StatusEvent} with
	 * specific <code>code</code> values (e.g. <code>"onInitSuccess"</code>,
	 * <code>"onPurchaseSuccess"</code>). See {@link BillingEvent} for the event codes
	 * exposed via {@link #listener}.
	 * </p>
	 */
	public class Billing
	{
		private static var _ex:Billing;
		
		/** Extension id used in <code>ExtensionContext.createExtensionContext</code>. */
		public static const EXTENSION_ID:String = "com.fluocode.extensions.billing";
		
		/** ActionScript API version of this ANE wrapper. */
		public static const VERSION:String = "1.0.0";
		
		/** Message used when a user attempts to buy an already-owned item. */
		public static const ALREADY_OWNED_ITEM:String = "This item is already purchased, you should let user use this item.";
		
		/** Message used when the product id is not available in the fetched catalog. */
		public static const NOT_FOUND_ITEM:String = "This item not found on Google or Apple servers.";
		
		/**
		 * Child-directed flag for Android (see {@link ChildDirected}).
		 * Must be set before calling {@link #init()}.
		 */
		public static var CHILD_DIRECTED:int = 0;
		
		/**
		 * Under-age-of-consent flag for Android (see {@link UnderAgeOfConsent}).
		 * Must be set before calling {@link #init()}.
		 */
		public static var UNDER_AGE_OF_CONSENT:int = 0;
		
		/**
		 * If enabled on iOS, the native side may block purchases until you call
		 * {@link #continueThePreventedPurchaseFlow()}.
		 */
		public static var PARENTAL_GATE:Boolean = false;
		
		private var _context:ExtensionContext;
		private var _listener:EventDispatcher = new EventDispatcher();
		private var _db:PurchaseDB;
		private var _confirmed_products:Vector.<Product>;
		
		private var _callback_init:Function;
		private var _callback_getPurchases:Function;
		private var _callback_doPayment:Function;
		private var _callback_forceConsume:Function;
		private var _callback_priceChange:Function;
		private var _callback_acknowledgePurchase:Function;
		
		private var _isInitialized:Boolean;
		
		/**
		 * Constructor is used internally by {@link #init()}.
		 *
		 * @param androidInAppIDs One-time product ids (Android).
		 * @param androidSubsIDs Subscription product ids (Android).
		 * @param allIosIDs Product ids (iOS).
		 * @param onResult Callback called as <code>function(status:int, msg:String):void</code>.
		 */
		public function Billing(androidInAppIDs:Array, androidSubsIDs:Array, allIosIDs:Array, onResult:Function)
		{
			super();
			
			_callback_init = onResult;
			
			_context = ExtensionContext.createExtensionContext(EXTENSION_ID, null);
			_context.addEventListener(StatusEvent.STATUS, onStatus);
			
			removeOlderDbFilesIfExist();
			_db = new PurchaseDB(EXTENSION_ID, EXTENSION_ID + "/purchaseData.json");
			
			var isAndroid:Boolean = Capabilities.manufacturer && Capabilities.manufacturer.toLowerCase().indexOf("android") > -1;
			setTimeout(function():void
			{
				if (!isAndroid)
				{
					_context.call("command", "init", JSON.stringify(allIosIDs || []), PARENTAL_GATE);
				}
				else
				{
					_context.call("command", "init", CHILD_DIRECTED, UNDER_AGE_OF_CONSENT, androidInAppIDs || [], androidSubsIDs || []);
				}
			}, 50);
		}
		
		/**
		 * Initializes the ANE and fetches product metadata from the store.
		 *
		 * @param androidInAppIDs One-time product ids (Android).
		 * @param androidSubsIDs Subscription product ids (Android).
		 * @param iosNonConsumables iOS product ids for non-consumables.
		 * @param iosConsumables iOS product ids for consumables.
		 * @param onResult Callback invoked once native init completes.
		 *        Signature: <code>function(status:int, msg:String):void</code>.
		 */
		public static function init(androidInAppIDs:Array, androidSubsIDs:Array, iosNonConsumables:Array, iosConsumables:Array, onResult:Function):void
		{
			if (!androidInAppIDs) androidInAppIDs = [];
			if (!androidSubsIDs) androidSubsIDs = [];
			if (!iosNonConsumables) iosNonConsumables = [];
			if (!iosConsumables) iosConsumables = [];
			
			var mergedIos:Array = iosNonConsumables.concat(iosConsumables);
			_ex = new Billing(androidInAppIDs, androidSubsIDs, mergedIos, onResult);
		}
		
		/**
		 * Queries the user's purchases and returns them via callback.
		 *
		 * @param callback Callback invoked with a <code>Vector.&lt;Purchase&gt;</code> or <code>null</code> on failure.
		 *        Signature: <code>function(purchases:Vector.&lt;Purchase&gt;):void</code>.
		 */
		public static function getPurchases(callback:Function):void
		{
			requireInit();
			requireProducts();
			
			if (_ex._callback_getPurchases != null) return;
			_ex._callback_getPurchases = callback;
			_ex._db.clearCache();
			_ex._context.call("command", "getPurchases");
		}
		
		/**
		 * Replaces an active subscription with another subscription.
		 *
		 * <p>On Android this uses the subscriptions update flow. On iOS, subscription changes are
		 * managed by the App Store and the implementation typically triggers a purchase of the new product.</p>
		 *
		 * @param oldProductId Current subscription product id.
		 * @param newProductId New subscription product id.
		 * @param prorationMode Android proration mode (see {@link ProrationMode}).
		 * @param accountId Optional obfuscated account id.
		 * @param callback Callback invoked as <code>function(status:int, purchase:Purchase, msg:String, isConsumable:Boolean):void</code>.
		 */
		public static function replaceSubscription(oldProductId:String, newProductId:String, prorationMode:int, accountId:String, callback:Function):void
		{
			if (callback == null) throw new Error("The result callback function cannot be null");
			requireInit();
			requireProducts();
			
			if (!accountId) accountId = "";
			if (_ex._callback_doPayment != null) return;
			_ex._callback_doPayment = callback;
			_ex._context.call("command", "replaceSubscription", oldProductId, newProductId, prorationMode, accountId);
		}
		
		/**
		 * Starts a purchase flow.
		 *
		 * @param type Billing type, see {@link BillingType}.
		 * @param id Product id to purchase.
		 * @param accountId Optional obfuscated account id.
		 * @param callback Callback invoked as <code>function(status:int, purchase:Purchase, msg:String, isConsumable:Boolean):void</code>.
		 */
		public static function doPayment(type:int, id:String, accountId:String, callback:Function):void
		{
			if (callback == null) throw new Error("The result callback function cannot be null");
			requireInit();
			requireProducts();
			
			if (_ex.isDuplicatedPurchase(id))
			{
				callback(0, null, ALREADY_OWNED_ITEM, false);
				return;
			}
			
			if (!accountId) accountId = "";
			
			var isAndroid:Boolean = Capabilities.manufacturer && Capabilities.manufacturer.toLowerCase().indexOf("android") > -1;
			if (!isAndroid)
			{
				// Keep the legacy pattern "type@@@accountId" so native code can parse the billing type on iOS.
				accountId = type + "@@@" + accountId;
			}
			
			if (_ex._callback_doPayment != null) return;
			_ex._callback_doPayment = callback;
			
			var doNow:Function = function(purchases:Vector.<Purchase>):void
			{
				if (purchases)
				{
					if (_ex.isDuplicatedPurchase(id))
					{
						if (_ex._callback_doPayment != null)
						{
							_ex._callback_doPayment(0, null, ALREADY_OWNED_ITEM, false);
							_ex._callback_doPayment = null;
						}
						return;
					}
					if (_ex.canGoForThePayment(id))
					{
						_ex._context.call("command", "doPayment", type, id, accountId);
					}
					else if (_ex._callback_doPayment != null)
					{
						_ex._callback_doPayment(0, null, NOT_FOUND_ITEM, false);
						_ex._callback_doPayment = null;
					}
				}
				else if (_ex._callback_doPayment != null)
				{
					_ex._callback_doPayment(0, null, "Error connecting to server!", false);
					_ex._callback_doPayment = null;
				}
			};
			
			if (_ex._db.file.exists)
			{
				if (_ex.canGoForThePayment(id))
				{
					_ex._context.call("command", "doPayment", type, id, accountId);
				}
				else
				{
					_ex._callback_doPayment(0, null, NOT_FOUND_ITEM, false);
					_ex._callback_doPayment = null;
				}
			}
			else
			{
				getPurchases(doNow);
			}
		}
		
		/**
		 * Clears the local purchase cache created by {@link PurchaseDB}.
		 */
		public static function clearCache():void
		{
			requireInit();
			_ex._db.clearCache();
		}
		
		/**
		 * Continues a previously prevented purchase flow (used by parental gate logic on some iOS setups).
		 */
		public static function continueThePreventedPurchaseFlow():void
		{
			requireInit();
			_ex._context.call("command", "continueThePreventedPurchaseFlow");
		}
		
		/**
		 * Consumes a purchase token (Android consumables).
		 *
		 * @param purchaseToken Purchase token to consume.
		 * @param callback Callback invoked with a Boolean success flag.
		 *        Signature: <code>function(success:Boolean):void</code>.
		 */
		public static function forceConsume(purchaseToken:String, callback:Function):void
		{
			requireInit();
			requireProducts();
			_ex._callback_forceConsume = callback;
			_ex._context.call("command", "consume", purchaseToken, "EMPTY");
		}
		
		/**
		 * Acknowledges a purchase (Android non-consumables/subscriptions).
		 *
		 * @param purchaseToken Purchase token to acknowledge.
		 * @param callback Callback invoked with <code>null</code> on success, or an error message on failure.
		 *        Signature: <code>function(error:String):void</code>.
		 */
		public static function acknowledgePurchase(purchaseToken:String, callback:Function):void
		{
			requireInit();
			_ex._callback_acknowledgePurchase = callback;
			_ex._context.call("command", "acknowledgePurchase", purchaseToken, "EMPTY");
		}
		
		/**
		 * Returns the iOS App Store receipt as a base64 string (iOS only).
		 *
		 * @return Receipt base64 string, or <code>null</code> on Android.
		 */
		public static function get iOSReceipt():String
		{
			requireInit();
			var isAndroid:Boolean = Capabilities.manufacturer && Capabilities.manufacturer.toLowerCase().indexOf("android") > -1;
			if (isAndroid) return null;
			return _ex._context.call("command", "getReceipt") as String;
		}
		
		/**
		 * Presents code redemption UI where supported (iOS).
		 */
		public static function redeem():void
		{
			requireInit();
			_ex._context.call("command", "redeem");
		}
		
		/**
		 * Verifies an Android purchase locally using the provided public key.
		 *
		 * @param p Purchase to verify. Requires {@link #publicKey} to be set on the native side.
		 * @return <code>true</code> if the signature verification succeeds.
		 */
		public static function verifyAndroidPurchaseLocally(p:Purchase):Boolean
		{
			requireInit();
			if (!p) return false;
			return Boolean(_ex._context.call("command", "verify", p.rawData, p.signature));
		}
		
		/**
		 * Requests a price change confirmation flow where supported.
		 *
		 * @param productId Subscription product id.
		 * @param callback Callback invoked as <code>function(agreed:Boolean, msg:String):void</code>.
		 */
		public static function priceChangeConfirmation(productId:String, callback:Function):void
		{
			requireInit();
			_ex._callback_priceChange = callback;
			_ex._context.call("command", "priceChangeConfirmation", productId);
		}
		
		/**
		 * Checks whether a billing feature is supported.
		 *
		 * @param feature Feature name (see {@link FeatureType}).
		 * @return A value compatible with {@link BillingResponse} constants
		 *         (<code>0</code> for OK, <code>-2</code> for not supported).
		 */
		public static function isFeatureSupported(feature:String):int
		{
			requireInit();
			var v:* = _ex._context.call("command", "isFeatureSupported", feature);
			return v is int ? int(v) : int(v);
		}
		
		/**
		 * Indicates whether initialization succeeded.
		 */
		public static function get isInitialized():Boolean
		{
			return _ex ? _ex._isInitialized : false;
		}
		
		/**
		 * Product metadata returned by the store during initialization.
		 *
		 * @throws Error If the ANE is not initialized.
		 */
		public static function get products():Vector.<Product>
		{
			requireInit();
			return _ex._confirmed_products;
		}
		
		/**
		 * Event dispatcher for asynchronous events that are not tied to a direct callback.
		 *
		 * <p>Dispatches {@link BillingEvent} types, such as
		 * {@link BillingEvent#SERVICE_DISCONNECTED} and promo purchase events.</p>
		 */
		public static function get listener():EventDispatcher
		{
			requireInit();
			return _ex._listener;
		}
		
		/**
		 * Sets the Android public key used for local signature verification.
		 *
		 * @param v Base64-encoded RSA public key.
		 */
		public static function set publicKey(v:String):void
		{
			requireInit();
			_ex._context.call("command", "setPublicKey", v);
		}
		
		/**
		 * Disposes the extension context and releases native resources.
		 *
		 * After calling this, you must call {@link #init()} again to use the ANE.
		 */
		public static function dispose():void
		{
			if (!_ex) return;
			try { _ex._context.removeEventListener(StatusEvent.STATUS, _ex.onStatus); } catch (_:*) {}
			try { _ex._context.call("command", "dispose"); } catch (_:*) {}
			try { _ex._context.dispose(); } catch (_:*) {}
			_ex._context = null;
			_ex._isInitialized = false;
			_ex = null;
		}
		
		private static function requireInit():void
		{
			if (!_ex) throw new Error("ANE is not initialized yet");
		}
		
		private static function requireProducts():void
		{
			if (!_ex._confirmed_products) throw new Error("No product match found on server!");
		}
		
		/**
		 * Handles native StatusEvents and routes them to the appropriate callback/event.
		 *
		 * @param e Native status event dispatched by the platform implementation.
		 */
		private function onStatus(e:StatusEvent):void
		{
			var arr:Array;
			var parts:Array;
			var purchaseArr:Vector.<Purchase>;
			var p:Purchase;
			
			switch (e.code)
			{
				case "onInitSuccess":
					_isInitialized = true;
					if (_callback_init != null)
					{
						arr = JSON.parse(e.level) as Array;
						_confirmed_products = new Vector.<Product>();
						for (var i:int = 0; i < arr.length; i++)
						{
							_confirmed_products.push(new Product(arr[i]));
						}
						_callback_init(1, "onInitSuccess");
						_callback_init = null;
					}
					break;
				
				case "onInitFail":
					if (_callback_init != null)
					{
						_callback_init(0, e.level);
						_callback_init = null;
					}
					break;
				
				case "onServiceDisconnected":
					_listener.dispatchEvent(new BillingEvent(BillingEvent.SERVICE_DISCONNECTED));
					break;
				
				case "onPurchaseQuerySuccess":
					purchaseArr = PurchaseDB.orgenizePurchaseInfo(JSON.parse(e.level) as Array);
					_db.savePurchases(purchaseArr);
					if (_callback_getPurchases != null)
					{
						_callback_getPurchases(_db.getPurchases());
						_callback_getPurchases = null;
					}
					break;
				
				case "onPurchaseQueryFailed":
					if (_callback_getPurchases != null)
					{
						_callback_getPurchases(null);
						_callback_getPurchases = null;
					}
					break;
				
				case "onPurchaseSuccess":
					_db.clearCache();
					parts = String(e.level).split("|||");
					purchaseArr = PurchaseDB.orgenizePurchaseInfo([JSON.parse(parts[1])]);
					p = purchaseArr.length > 0 ? purchaseArr[0] : null;
					if (parts[0].length > 0)
					{
						if (p && p.billingType != BillingType.CONSUMABLE)
						{
							_db.savePurchase(p);
						}
						if (_callback_doPayment != null)
						{
							_callback_doPayment(1, p, "Purchase was successful!", p && p.billingType == BillingType.CONSUMABLE);
							_callback_doPayment = null;
						}
					}
					else
					{
						_listener.dispatchEvent(new BillingEvent(BillingEvent.PROMO_PURCHASE_SUCCESS, "Purchase was successful!", 1, p));
					}
					break;
				
				case "onPurchaseFailed":
				case "onRareErrorOccured":
					parts = String(e.level).split("|||");
					if (parts[0].length > 0)
					{
						if (_callback_doPayment != null)
						{
							_callback_doPayment(0, null, parts[1], false);
							_callback_doPayment = null;
						}
					}
					else
					{
						_listener.dispatchEvent(new BillingEvent(BillingEvent.PROMO_PURCHASE_FAILED, parts[1]));
					}
					break;
				
				case "onPurchaseSuccessPartially":
					_db.clearCache();
					parts = String(e.level).split("|||");
					purchaseArr = PurchaseDB.orgenizePurchaseInfo([JSON.parse(parts[1])]);
					p = purchaseArr.length > 0 ? purchaseArr[0] : null;
					if (_callback_doPayment != null)
					{
						_callback_doPayment(1, p, "Purchase was successful but item was not consumed!", false);
						_callback_doPayment = null;
					}
					break;
				
				case "onConsumeSuccess":
					_db.clearCache();
					if (_callback_forceConsume != null)
					{
						_callback_forceConsume(true);
						_callback_forceConsume = null;
					}
					break;
				
				case "onConsumeFailed":
					if (_callback_forceConsume != null)
					{
						_callback_forceConsume(false);
						_callback_forceConsume = null;
					}
					break;
				
				case "onParentPermissionRequired":
					_listener.dispatchEvent(new BillingEvent(BillingEvent.PARENT_PERMISSION_REQUIRED, e.level));
					break;
				
				case "onPriceChangeAgreed":
					if (_callback_priceChange != null)
					{
						_callback_priceChange(true, e.level);
						_callback_priceChange = null;
					}
					break;
				
				case "onPriceChangeDeclined":
					if (_callback_priceChange != null)
					{
						_callback_priceChange(false, e.level);
						_callback_priceChange = null;
					}
					break;
				
				case "onAcknowledgeSuccess":
					if (_callback_acknowledgePurchase != null)
					{
						_callback_acknowledgePurchase(null);
						_callback_acknowledgePurchase = null;
					}
					break;
				
				case "onAcknowledgeFailure":
					if (_callback_acknowledgePurchase != null)
					{
						_callback_acknowledgePurchase(e.level);
						_callback_acknowledgePurchase = null;
					}
					break;
			}
		}
		
		/**
		 * Removes legacy cache file names used by older implementations (best-effort).
		 */
		private function removeOlderDbFilesIfExist():void
		{
			// Cleanup old names (best-effort).
			var candidates:Array = [
				EXTENSION_ID + "/purchasData.db",
				EXTENSION_ID + "/purchasData1.db",
				EXTENSION_ID + "/purchasData2.db",
				EXTENSION_ID + "/purchasData3.db",
				EXTENSION_ID + "/purchasData4.db",
				EXTENSION_ID + "/purchasData5.db",
				EXTENSION_ID + "/purchasData6.db",
				EXTENSION_ID + "/purchasData9.db"
			];
			
			for (var i:int = 0; i < candidates.length; i++)
			{
				try
				{
					var f:File = File.applicationStorageDirectory.resolvePath(candidates[i]);
					if (f.exists) f.deleteFile();
				}
				catch (_:*) {}
			}
		}
		
		/**
		 * Checks whether a product id exists in the fetched product catalog.
		 * Android test ids are always allowed.
		 */
		private function canGoForThePayment(productId:String):Boolean
		{
			var isAndroid:Boolean = Capabilities.manufacturer && Capabilities.manufacturer.toLowerCase().indexOf("android") > -1;
			if (isAndroid)
			{
				if (productId == "android.test.purchased" ||
					productId == "android.test.canceled" ||
					productId == "android.test.refunded" ||
					productId == "android.test.item_unavailable")
				{
					return true;
				}
			}
			
			for (var i:int = 0; i < _confirmed_products.length; i++)
			{
				if (_confirmed_products[i].productId == productId) return true;
			}
			return false;
		}
		
		/**
		 * Checks whether the given product id already exists in the local cache.
		 */
		private function isDuplicatedPurchase(productId:String):Boolean
		{
			if (!_db.file.exists) return false;
			var list:Vector.<Purchase> = _db.getPurchases();
			for (var i:int = 0; i < list.length; i++)
			{
				if (list[i].productId == productId) return true;
			}
			return false;
		}
	}
}

