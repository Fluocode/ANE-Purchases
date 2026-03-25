#pragma once

#import <Foundation/Foundation.h>
#import <StoreKit/StoreKit.h>
#include "FlashRuntimeExtensions.h"

@interface BillingController : NSObject<SKProductsRequestDelegate, SKPaymentTransactionObserver>

@property(nonatomic, assign) FREContext freContext;

- (instancetype)initWithContext:(FREContext)ctx;
- (void)dispose;

- (void)initWithProductIdsJson:(NSString*)productIdsJson parentalGate:(BOOL)parentalGate;
- (void)getPurchases;
- (void)doPaymentWithType:(int)billingType productId:(NSString*)productId accountId:(NSString*)accountId;
- (void)replaceSubscriptionOld:(NSString*)oldProductId newId:(NSString*)newProductId prorationMode:(int)prorationMode accountId:(NSString*)accountId;
- (void)consume:(NSString*)purchaseToken;
- (void)acknowledge:(NSString*)purchaseToken;
- (NSString*)getReceiptBase64;
- (int)isFeatureSupported:(NSString*)feature;
- (void)priceChangeConfirmation:(NSString*)productId;
- (void)redeem;
- (void)continueThePreventedPurchaseFlow;

@end

