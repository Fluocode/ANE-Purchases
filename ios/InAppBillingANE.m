#import <Foundation/Foundation.h>
#import "FlashRuntimeExtensions.h"
#import "FreUtils.h"
#import "BillingController.h"

static BillingController* gController = nil;

static void Dispatch(FREContext ctx, NSString* code, NSString* level)
{
	if (!ctx || !code) return;
	FREDispatchStatusEventAsync(ctx, (const uint8_t*)[code UTF8String], (const uint8_t*)((level ?: @"") UTF8String));
}

static FREObject Command(FREContext ctx, void* functionData, uint32_t argc, FREObject argv[])
{
	(void)functionData;
	
	NSString* sub = @"";
	if (argc > 0)
	{
		const char* s = FREGetCString(argv[0]);
		if (s) sub = [NSString stringWithUTF8String:s];
	}
	
	@try
	{
		if (!gController)
		{
			gController = [[BillingController alloc] initWithContext:ctx];
		}
		
		if ([sub isEqualToString:@"init"])
		{
			// iOS: ("init", JSON.stringify(ids), parentalGate)
			NSString* idsJson = @"[]";
			BOOL parentalGate = NO;
			
			if (argc > 1)
			{
				const char* c = FREGetCString(argv[1]);
				if (c) idsJson = [NSString stringWithUTF8String:c];
			}
			if (argc > 2)
			{
				parentalGate = FREGetBool(argv[2], 0) != 0;
			}
			
			[gController initWithProductIdsJson:idsJson parentalGate:parentalGate];
			return NULL;
		}
		
		if ([sub isEqualToString:@"getPurchases"])
		{
			[gController getPurchases];
			return NULL;
		}
		
		if ([sub isEqualToString:@"doPayment"])
		{
			int type = argc > 1 ? (int)FREGetInt32(argv[1], 0) : 0;
			NSString* productId = argc > 2 && FREGetCString(argv[2]) ? [NSString stringWithUTF8String:FREGetCString(argv[2])] : @"";
			NSString* accountId = argc > 3 && FREGetCString(argv[3]) ? [NSString stringWithUTF8String:FREGetCString(argv[3])] : @"";
			[gController doPaymentWithType:type productId:productId accountId:accountId];
			return NULL;
		}
		
		if ([sub isEqualToString:@"replaceSubscription"])
		{
			NSString* oldId = argc > 1 && FREGetCString(argv[1]) ? [NSString stringWithUTF8String:FREGetCString(argv[1])] : @"";
			NSString* newId = argc > 2 && FREGetCString(argv[2]) ? [NSString stringWithUTF8String:FREGetCString(argv[2])] : @"";
			int proration = argc > 3 ? (int)FREGetInt32(argv[3], 0) : 0;
			NSString* accountId = argc > 4 && FREGetCString(argv[4]) ? [NSString stringWithUTF8String:FREGetCString(argv[4])] : @"";
			[gController replaceSubscriptionOld:oldId newId:newId prorationMode:proration accountId:accountId];
			return NULL;
		}
		
		if ([sub isEqualToString:@"consume"])
		{
			NSString* token = argc > 1 && FREGetCString(argv[1]) ? [NSString stringWithUTF8String:FREGetCString(argv[1])] : @"";
			[gController consume:token];
			return NULL;
		}
		
		if ([sub isEqualToString:@"acknowledgePurchase"])
		{
			NSString* token = argc > 1 && FREGetCString(argv[1]) ? [NSString stringWithUTF8String:FREGetCString(argv[1])] : @"";
			[gController acknowledge:token];
			return NULL;
		}
		
		if ([sub isEqualToString:@"getReceipt"])
		{
			NSString* receipt = [gController getReceiptBase64] ?: @"";
			return FRENewString([receipt UTF8String]);
		}
		
		if ([sub isEqualToString:@"isFeatureSupported"])
		{
			NSString* feature = argc > 1 && FREGetCString(argv[1]) ? [NSString stringWithUTF8String:FREGetCString(argv[1])] : @"";
			int res = [gController isFeatureSupported:feature];
			return FRENewInt(res);
		}
		
		if ([sub isEqualToString:@"priceChangeConfirmation"])
		{
			NSString* productId = argc > 1 && FREGetCString(argv[1]) ? [NSString stringWithUTF8String:FREGetCString(argv[1])] : @"";
			[gController priceChangeConfirmation:productId];
			return NULL;
		}
		
		if ([sub isEqualToString:@"redeem"])
		{
			[gController redeem];
			return NULL;
		}
		
		if ([sub isEqualToString:@"continueThePreventedPurchaseFlow"])
		{
			[gController continueThePreventedPurchaseFlow];
			return NULL;
		}
		
		if ([sub isEqualToString:@"setPublicKey"] || [sub isEqualToString:@"verify"])
		{
			// Android-only in this ANE API.
			return NULL;
		}
		
		if ([sub isEqualToString:@"dispose"])
		{
			if (gController)
			{
				[gController dispose];
				gController = nil;
			}
			return NULL;
		}
	}
	@catch (NSException* ex)
	{
		NSString* msg = ex.reason ?: @"Unknown error";
		Dispatch(ctx, @"onRareErrorOccured", [NSString stringWithFormat:@"1|||%@", msg]);
	}
	
	return NULL;
}

static FRENamedFunction gFunctions[] =
{
	{ (const uint8_t*)"command", NULL, &Command },
};

void cinAppBillingExtensionContextInitializer(void* extData, const uint8_t* ctxType, FREContext ctx, uint32_t* numFunctionsToSet, const FRENamedFunction** functionsToSet)
{
	(void)extData;
	(void)ctxType;
	*numFunctionsToSet = 1;
	*functionsToSet = gFunctions;
	
	// create controller bound to this context
	if (gController)
	{
		[gController dispose];
		gController = nil;
	}
	gController = [[BillingController alloc] initWithContext:ctx];
}

void inAppBillingExtensionFinalizer(FREContext ctx)
{
	(void)ctx;
	if (gController)
	{
		[gController dispose];
		gController = nil;
	}
}

void cinAppBillingExtensionInitializer(void** extDataToSet, FREContextInitializer* ctxInitializerToSet, FREContextFinalizer* ctxFinalizerToSet)
{
	*extDataToSet = NULL;
	*ctxInitializerToSet = &cinAppBillingExtensionContextInitializer;
	*ctxFinalizerToSet = &inAppBillingExtensionFinalizer;
}

void inAppBillingExtensionFinalizer(void* extData)
{
	(void)extData;
}

