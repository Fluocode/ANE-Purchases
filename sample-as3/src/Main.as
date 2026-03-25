package
{
	import com.fluocode.extensions.billing.Billing;
	import com.fluocode.extensions.billing.BillingEvent;
	import com.fluocode.extensions.billing.BillingType;
	import com.fluocode.extensions.billing.Purchase;
	
	import flash.display.Sprite;
	import flash.events.MouseEvent;
	import flash.system.Capabilities;
	import flash.text.TextField;
	import flash.text.TextFieldAutoSize;
	import flash.text.TextFormat;
	
	/**
	 * Minimal UI test harness for the Billing ANE.
	 */
	public class Main extends Sprite
	{
		// ---------------- configure your store ids here ----------------
		private static const ANDROID_INAPP_IDS:Array = ["android.test.purchased"];
		private static const ANDROID_SUB_IDS:Array = [];
		
		private static const IOS_NONCONSUMABLE_IDS:Array = [];
		private static const IOS_CONSUMABLE_IDS:Array = [];
		
		// Change this to one of your real product ids for production testing.
		private static const TEST_PRODUCT_ID:String = "android.test.purchased";
		// ---------------------------------------------------------------
		
		private var logTf:TextField;
		
		public function Main()
		{
			super();
			
			buildUi();
			hookEvents();
			
			log("Platform: " + Capabilities.manufacturer + " | " + Capabilities.os);
			log("Initializing billing...");
			
			Billing.PARENTAL_GATE = false;
			Billing.CHILD_DIRECTED = 0;
			Billing.UNDER_AGE_OF_CONSENT = 0;
			
			Billing.init(
				ANDROID_INAPP_IDS,
				ANDROID_SUB_IDS,
				IOS_NONCONSUMABLE_IDS,
				IOS_CONSUMABLE_IDS,
				function(status:int, msg:String):void
				{
					log("init => status=" + status + " msg=" + msg);
					if (status == 1)
					{
						log("Products: " + (Billing.products ? Billing.products.length : 0));
					}
				}
			);
		}
		
		private function hookEvents():void
		{
			Billing.listener.addEventListener(BillingEvent.SERVICE_DISCONNECTED, function(e:BillingEvent):void {
				log("EVENT: SERVICE_DISCONNECTED");
			});
			
			Billing.listener.addEventListener(BillingEvent.PARENT_PERMISSION_REQUIRED, function(e:BillingEvent):void {
				log("EVENT: PARENT_PERMISSION_REQUIRED msg=" + e.msg);
			});
		}
		
		private function buildUi():void
		{
			graphics.beginFill(0x111827);
			graphics.drawRect(0, 0, 720, 1280);
			graphics.endFill();
			
			var title:TextField = makeLabel("Billing ANE Test", 24, 0xFFFFFF);
			title.x = 20;
			title.y = 20;
			addChild(title);
			
			var btnGetPurchases:Sprite = makeButton("Get Purchases", 20, 70);
			btnGetPurchases.name = "btnGetPurchases";
			addChild(btnGetPurchases);
			
			var btnBuy:Sprite = makeButton("Buy (Test Product)", 20, 130);
			btnBuy.name = "btnBuy";
			addChild(btnBuy);
			
			var btnReceipt:Sprite = makeButton("iOS Receipt", 20, 190);
			btnReceipt.name = "btnReceipt";
			addChild(btnReceipt);
			
			var btnRedeem:Sprite = makeButton("Redeem (iOS)", 20, 250);
			btnRedeem.name = "btnRedeem";
			addChild(btnRedeem);
			
			logTf = new TextField();
			logTf.defaultTextFormat = new TextFormat("_typewriter", 14, 0xE5E7EB);
			logTf.multiline = true;
			logTf.wordWrap = true;
			logTf.width = 680;
			logTf.height = 900;
			logTf.x = 20;
			logTf.y = 330;
			logTf.text = "";
			addChild(logTf);
		}
		
		private function makeButton(label:String, xPos:Number, yPos:Number):Sprite
		{
			var s:Sprite = new Sprite();
			s.buttonMode = true;
			s.mouseChildren = false;
			
			s.graphics.beginFill(0x2563EB);
			s.graphics.drawRoundRect(0, 0, 320, 44, 10, 10);
			s.graphics.endFill();
			
			var tf:TextField = makeLabel(label, 16, 0xFFFFFF);
			tf.x = 14;
			tf.y = 10;
			s.addChild(tf);
			
			s.x = xPos;
			s.y = yPos;
			
			s.addEventListener(MouseEvent.CLICK, onButtonClick);
			return s;
		}
		
		private function makeLabel(text:String, size:int, color:uint):TextField
		{
			var tf:TextField = new TextField();
			tf.defaultTextFormat = new TextFormat("_sans", size, color, true);
			tf.autoSize = TextFieldAutoSize.LEFT;
			tf.selectable = false;
			tf.mouseEnabled = false;
			tf.text = text;
			return tf;
		}
		
		private function onButtonClick(e:MouseEvent):void
		{
			switch (Sprite(e.currentTarget).name)
			{
				case "btnGetPurchases":
					log("Calling getPurchases...");
					Billing.getPurchases(function(purchases:Vector.<Purchase>):void {
						if (!purchases)
						{
							log("getPurchases => FAILED");
							return;
						}
						log("getPurchases => " + purchases.length + " purchase(s)");
						for each (var p:Purchase in purchases)
						{
							log(" - " + p.productId + " token=" + p.purchaseToken);
						}
					});
					break;
				
				case "btnBuy":
					log("Calling doPayment for: " + TEST_PRODUCT_ID);
					Billing.doPayment(BillingType.PERMANENT, TEST_PRODUCT_ID, "", function(status:int, purchase:Purchase, msg:String, isConsumable:Boolean):void {
						log("doPayment => status=" + status + " msg=" + msg + " consumable=" + isConsumable);
						if (purchase) log("purchase => productId=" + purchase.productId + " token=" + purchase.purchaseToken);
					});
					break;
				
				case "btnReceipt":
					log("iOSReceipt => " + Billing.iOSReceipt);
					break;
				
				case "btnRedeem":
					log("Calling redeem...");
					Billing.redeem();
					break;
			}
		}
		
		private function log(msg:String):void
		{
			if (!logTf) return;
			logTf.appendText(msg + "\n");
			logTf.scrollV = logTf.maxScrollV;
		}
	}
}

