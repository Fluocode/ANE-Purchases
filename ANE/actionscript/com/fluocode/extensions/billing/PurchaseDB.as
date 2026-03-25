package com.fluocode.extensions.billing
{
	import flash.events.EventDispatcher;
	import flash.filesystem.File;
	import flash.filesystem.FileMode;
	import flash.filesystem.FileStream;
	import flash.system.Capabilities;
	
	/**
	 * Lightweight purchase cache used by {@link Billing}.
	 *
	 * <p>
	 * This implementation stores purchases as JSON in the app storage directory.
	 * It exists to support simple duplicate-purchase checks and quick access
	 * without re-querying the store on every call.
	 * </p>
	 *
	 * <p>
	 * Note: this is a cache, not an entitlement system. Always validate purchases
	 * server-side for security-critical logic.
	 * </p>
	 */
	public class PurchaseDB extends EventDispatcher
	{
		private var _file:File;
		private var _cache:Vector.<Purchase>;
		
		/**
		 * Creates a new cache file under <code>File.applicationStorageDirectory</code>.
		 *
		 * @param baseDir Directory name under app storage.
		 * @param relativePath File path under app storage.
		 */
		public function PurchaseDB(baseDir:String, relativePath:String)
		{
			super();
			File.applicationStorageDirectory.resolvePath(baseDir).createDirectory();
			_file = File.applicationStorageDirectory.resolvePath(relativePath);
		}
		
		/**
		 * Converts an Array of native purchase objects to a typed vector.
		 *
		 * @param list Native payload list (Array of Objects).
		 * @return Vector of {@link Purchase} instances (empty if list is null).
		 */
		public static function orgenizePurchaseInfo(list:Array):Vector.<Purchase>
		{
			var result:Vector.<Purchase> = new Vector.<Purchase>();
			if (!list) return result;
			
			var isAndroid:Boolean = Capabilities.manufacturer && Capabilities.manufacturer.toLowerCase().indexOf("android") > -1;
			var n:int = list.length;
			for (var i:int = 0; i < n; i++)
			{
				var p:Purchase = new Purchase();
				if (isAndroid) p.setAndroid(list[i]);
				else p.setIos(list[i]);
				result.push(p);
			}
			return result;
		}
		
		/**
		 * Returns cached purchases. If no cache exists, returns an empty vector.
		 */
		public function getPurchases():Vector.<Purchase>
		{
			if (_cache) return _cache;
			_cache = new Vector.<Purchase>();
			
			if (!_file.exists) return _cache;
			
			var fs:FileStream = new FileStream();
			try
			{
				fs.open(_file, FileMode.READ);
				var raw:String = fs.readUTFBytes(fs.bytesAvailable);
				var arr:Array = raw && raw.length > 0 ? (JSON.parse(raw) as Array) : [];
				for (var i:int = 0; i < arr.length; i++)
				{
					var p:Purchase = new Purchase();
					p.setData(arr[i]);
					_cache.push(p);
				}
			}
			catch (e:Error)
			{
				_cache = new Vector.<Purchase>();
			}
			finally
			{
				try { fs.close(); } catch (_:*) {}
			}
			
			return _cache;
		}
		
		/**
		 * Saves multiple purchases into the cache.
		 *
		 * @param purchases Purchases to save.
		 */
		public function savePurchases(purchases:Vector.<Purchase>):void
		{
			if (!purchases) return;
			for (var i:int = 0; i < purchases.length; i++)
			{
				savePurchase(purchases[i]);
			}
		}
		
		/**
		 * Saves a single purchase into the cache.
		 *
		 * <p>Merge key is <code>orderId</code> when available; otherwise <code>purchaseToken</code>.</p>
		 *
		 * @param p Purchase to save.
		 */
		public function savePurchase(p:Purchase):void
		{
			if (!p) return;
			
			var list:Array = [];
			var existing:Vector.<Purchase> = getPurchases();
			
			// Merge/replace by orderId (preferred) or purchaseToken.
			var replaced:Boolean = false;
			for (var i:int = 0; i < existing.length; i++)
			{
				var cur:Purchase = existing[i];
				if ((p.orderId && p.orderId.length > 0 && cur.orderId == p.orderId) ||
					(!p.orderId || p.orderId.length == 0) && cur.purchaseToken == p.purchaseToken)
				{
					existing[i] = p;
					replaced = true;
					break;
				}
			}
			if (!replaced) existing.push(p);
			
			for (i = 0; i < existing.length; i++)
			{
				cur = existing[i];
				list.push({
					orderId: cur.orderId,
					originalOrderId: cur.originalOrderId,
					productId: cur.productId,
					purchaseState: cur.purchaseState,
					purchaseTime: cur.purchaseTime,
					purchaseToken: cur.purchaseToken,
					autoRenewing: cur.autoRenewing ? 1 : 0,
					isAcknowledged: cur.isAcknowledged ? 1 : 0,
					signature: cur.signature,
					rawData: cur.rawData
				});
			}
			
			var fs:FileStream = new FileStream();
			try
			{
				_file.parent.createDirectory();
				fs.open(_file, FileMode.WRITE);
				fs.writeUTFBytes(JSON.stringify(list));
			}
			catch (e:Error)
			{
			}
			finally
			{
				try { fs.close(); } catch (_:*) {}
			}
		}
		
		/**
		 * Clears the in-memory and on-disk cache.
		 */
		public function clearCache():void
		{
			_cache = null;
			if (_file.exists)
			{
				try { _file.deleteFile(); } catch (_:*) {}
			}
		}
		
		/**
		 * The cache file location.
		 */
		public function get file():File { return _file; }
	}
}

