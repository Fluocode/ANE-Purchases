#import "BillingController.h"

static inline void DispatchStatus(FREContext ctx, NSString* code, NSString* level)
{
	if (!ctx || !code) return;
	const char* c = [code UTF8String];
	const char* l = level ? [level UTF8String] : "";
	FREDispatchStatusEventAsync(ctx, (const uint8_t*)c, (const uint8_t*)l);
}

@interface BillingController ()
@property(nonatomic, strong) SKProductsRequest* productsRequest;
@property(nonatomic, strong) NSDictionary<NSString*, SKProduct*>* productsById;
@property(nonatomic, assign) BOOL parentalGateEnabled;
@property(nonatomic, assign) BOOL parentalGateAllowed;
@property(nonatomic, copy) NSString* lastAccountId;
@end

@implementation BillingController

- (instancetype)initWithContext:(FREContext)ctx
{
	self = [super init];
	if (self)
	{
		_freContext = ctx;
		_productsById = @{};
		_parentalGateEnabled = NO;
		_parentalGateAllowed = YES;
		[[SKPaymentQueue defaultQueue] addTransactionObserver:self];
	}
	return self;
}

- (void)dispose
{
	@try { [[SKPaymentQueue defaultQueue] removeTransactionObserver:self]; } @catch (__unused id e) {}
	[self.productsRequest cancel];
	self.productsRequest = nil;
	self.productsById = @{};
}

- (void)initWithProductIdsJson:(NSString*)productIdsJson parentalGate:(BOOL)parentalGate
{
	self.parentalGateEnabled = parentalGate;
	self.parentalGateAllowed = !parentalGate;

	NSData* data = [productIdsJson dataUsingEncoding:NSUTF8StringEncoding];
	id json = nil;
	if (data)
	{
		json = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
	}
	if (![json isKindOfClass:[NSArray class]])
	{
		DispatchStatus(self.freContext, @"onInitFail", @"Invalid product list");
		return;
	}

	NSArray* ids = (NSArray*)json;
	NSMutableSet* set = [NSMutableSet set];
	for (id v in ids)
	{
		if ([v isKindOfClass:[NSString class]] && [(NSString*)v length] > 0)
		{
			[set addObject:v];
		}
	}

	if (set.count == 0)
	{
		DispatchStatus(self.freContext, @"onInitFail", @"No product IDs");
		return;
	}

	[self.productsRequest cancel];
	self.productsRequest = [[SKProductsRequest alloc] initWithProductIdentifiers:set];
	self.productsRequest.delegate = self;
	[self.productsRequest start];
}

- (void)productsRequest:(SKProductsRequest *)request didReceiveResponse:(SKProductsResponse *)response
{
	NSMutableDictionary* map = [NSMutableDictionary dictionary];
	NSMutableArray* out = [NSMutableArray array];

	for (SKProduct* p in response.products)
	{
		if (!p.productIdentifier) continue;
		map[p.productIdentifier] = p;

		NSMutableDictionary* o = [NSMutableDictionary dictionary];
		o[@"currency"] = p.priceLocale.currencyCode ?: @"";
		o[@"description"] = p.localizedDescription ?: @"";
		o[@"price"] = [self formattedPriceForProduct:p] ?: @"";
		o[@"productId"] = p.productIdentifier ?: @"";
		o[@"title"] = p.localizedTitle ?: @"";
		o[@"subscriptionPeriod"] = p.subscriptionPeriod ? p.subscriptionPeriod.stringValue : @"";
		o[@"hashCode"] = [NSString stringWithFormat:@"%lu", (unsigned long)p.hash];
		o[@"originalJson"] = @"{}";
		o[@"freeTrialPeriod"] = @"";
		o[@"introductoryPrice"] = @"";
		o[@"introductoryPriceAmountMicros"] = @(0);
		o[@"introductoryPriceCycles"] = @"";
		o[@"introductoryPricePeriod"] = @"";
		o[@"paymentMode"] = @"";

		[out addObject:o];
	}

	self.productsById = map;

	NSData* jsonData = [NSJSONSerialization dataWithJSONObject:out options:0 error:nil];
	NSString* payload = jsonData ? [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding] : @"[]";
	DispatchStatus(self.freContext, @"onInitSuccess", payload);
}

- (void)request:(SKRequest *)request didFailWithError:(NSError *)error
{
	DispatchStatus(self.freContext, @"onInitFail", error.localizedDescription ?: @"Request failed");
}

- (void)getPurchases
{
	// StoreKit 1 does not offer an explicit "query purchases" equivalent.
	// We use restoreCompletedTransactions to enumerate entitlements for non-consumables/subscriptions.
	[[SKPaymentQueue defaultQueue] restoreCompletedTransactions];
}

- (void)doPaymentWithType:(int)billingType productId:(NSString*)productId accountId:(NSString*)accountId
{
	self.lastAccountId = accountId ?: @"";

	if (self.parentalGateEnabled && !self.parentalGateAllowed)
	{
		DispatchStatus(self.freContext, @"onParentPermissionRequired", @"Parental gate enabled");
		return;
	}

	SKProduct* p = self.productsById[productId];
	if (!p)
	{
		DispatchStatus(self.freContext, @"onPurchaseFailed", @"1|||This item not found on Google or Apple servers.");
		return;
	}
	if (![SKPaymentQueue canMakePayments])
	{
		DispatchStatus(self.freContext, @"onPurchaseFailed", @"1|||Payments are not allowed on this device.");
		return;
	}

	SKMutablePayment* payment = [SKMutablePayment paymentWithProduct:p];
	// `applicationUsername` is deprecated but still works as an obfuscated identifier.
	if (accountId.length > 0) payment.applicationUsername = accountId;
	[[SKPaymentQueue defaultQueue] addPayment:payment];
}

- (void)replaceSubscriptionOld:(NSString*)oldProductId newId:(NSString*)newProductId prorationMode:(int)prorationMode accountId:(NSString*)accountId
{
	// iOS subscription upgrades/downgrades are managed by App Store; the app just purchases the new product.
	[self doPaymentWithType:2 productId:newProductId accountId:accountId];
}

- (void)consume:(NSString*)purchaseToken
{
	// iOS has no explicit consume for IAP; report success to keep API stable.
	DispatchStatus(self.freContext, @"onConsumeSuccess", @"");
}

- (void)acknowledge:(NSString*)purchaseToken
{
	// iOS has no acknowledge; report success to keep API stable.
	DispatchStatus(self.freContext, @"onAcknowledgeSuccess", @"");
}

- (NSString*)getReceiptBase64
{
	NSURL* url = [[NSBundle mainBundle] appStoreReceiptURL];
	NSData* data = url ? [NSData dataWithContentsOfURL:url] : nil;
	if (!data || data.length == 0) return @"";
	return [data base64EncodedStringWithOptions:0];
}

- (int)isFeatureSupported:(NSString*)feature
{
	if ([feature isEqualToString:@"priceChangeConfirmation"])
	{
		if (@available(iOS 13.4, *))
		{
			return 0;
		}
		return -2;
	}

	if ([feature isEqualToString:@"subscriptions"] || [feature isEqualToString:@"subscriptionsUpdate"])
	{
		return 0;
	}

	return -2;
}

- (void)priceChangeConfirmation:(NSString*)productId
{
	if (@available(iOS 13.4, *))
	{
		[SKPaymentQueue.defaultQueue showPriceConsentIfNeeded];
		DispatchStatus(self.freContext, @"onPriceChangeAgreed", @"");
		return;
	}
	DispatchStatus(self.freContext, @"onPriceChangeDeclined", @"Not supported");
}

- (void)redeem
{
	if (@available(iOS 14.0, *))
	{
		[SKPaymentQueue.defaultQueue presentCodeRedemptionSheet];
	}
}

- (void)continueThePreventedPurchaseFlow
{
	self.parentalGateAllowed = YES;
}

// ---------------- SKPaymentTransactionObserver ----------------

- (void)paymentQueue:(SKPaymentQueue *)queue updatedTransactions:(NSArray<SKPaymentTransaction *> *)transactions
{
	for (SKPaymentTransaction* t in transactions)
	{
		switch (t.transactionState)
		{
			case SKPaymentTransactionStatePurchased:
			{
				NSString* lvl = [NSString stringWithFormat:@"1|||%@", [self purchaseJsonForTransaction:t]];
				DispatchStatus(self.freContext, @"onPurchaseSuccess", lvl);
				[queue finishTransaction:t];
				break;
			}
			case SKPaymentTransactionStateFailed:
			{
				NSString* msg = t.error.localizedDescription ?: @"Purchase failed";
				NSString* lvl = [NSString stringWithFormat:@"1|||%@", msg];
				DispatchStatus(self.freContext, @"onPurchaseFailed", lvl);
				[queue finishTransaction:t];
				break;
			}
			case SKPaymentTransactionStateRestored:
			{
				// treat restored as a purchase query result item; finalize in restoreCompletedTransactionsFinished
				break;
			}
			default:
				break;
		}
	}
}

- (void)paymentQueueRestoreCompletedTransactionsFinished:(SKPaymentQueue *)queue
{
	NSMutableArray* out = [NSMutableArray array];
	for (SKPaymentTransaction* t in queue.transactions)
	{
		if (t.transactionState == SKPaymentTransactionStatePurchased || t.transactionState == SKPaymentTransactionStateRestored)
		{
			NSString* json = [self purchaseJsonForTransaction:t];
			NSData* d = [json dataUsingEncoding:NSUTF8StringEncoding];
			if (!d) continue;
			id obj = [NSJSONSerialization JSONObjectWithData:d options:0 error:nil];
			if (obj) [out addObject:obj];
		}
	}
	NSData* jd = [NSJSONSerialization dataWithJSONObject:out options:0 error:nil];
	NSString* payload = jd ? [[NSString alloc] initWithData:jd encoding:NSUTF8StringEncoding] : @"[]";
	DispatchStatus(self.freContext, @"onPurchaseQuerySuccess", payload);
}

- (void)paymentQueue:(SKPaymentQueue *)queue restoreCompletedTransactionsFailedWithError:(NSError *)error
{
	DispatchStatus(self.freContext, @"onPurchaseQueryFailed", error.localizedDescription ?: @"Restore failed");
}

// ---------------- helpers ----------------

- (NSString*)formattedPriceForProduct:(SKProduct*)p
{
	NSNumberFormatter* f = [[NSNumberFormatter alloc] init];
	f.numberStyle = NSNumberFormatterCurrencyStyle;
	f.locale = p.priceLocale;
	return [f stringFromNumber:p.price];
}

- (NSString*)purchaseJsonForTransaction:(SKPaymentTransaction*)t
{
	// accountId on iOS is expected to be "billingType@@@accountId" so AS3 can parse it.
	NSString* accountId = self.lastAccountId ?: @"";
	NSString* productId = t.payment.productIdentifier ?: @"";

	NSDictionary* o = @{
		@"accountId": accountId,
		@"orderId": t.transactionIdentifier ?: @"",
		@"originalOrderId": t.originalTransaction.transactionIdentifier ?: (t.transactionIdentifier ?: @""),
		@"productId": productId,
		@"purchaseState": @(0),
		@"purchaseTime": @((long long)(t.transactionDate.timeIntervalSince1970 * 1000.0)),
		@"purchaseToken": t.transactionIdentifier ?: @""
	};
	NSData* d = [NSJSONSerialization dataWithJSONObject:o options:0 error:nil];
	return d ? [[NSString alloc] initWithData:d encoding:NSUTF8StringEncoding] : @"{}";
}

@end

