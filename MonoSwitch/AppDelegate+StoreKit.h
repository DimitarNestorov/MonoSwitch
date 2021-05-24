#import <Foundation/Foundation.h>

#import "AppDelegate.h"

NS_ASSUME_NONNULL_BEGIN

@interface AppDelegate (StoreKit) <SKProductsRequestDelegate, SKPaymentTransactionObserver>

@property (getter=isProVersionPurchased) BOOL proVersionPurchased;

- (void)initStoreKit;

- (IBAction)purchaseProVersion:(id)sender;

@end

NS_ASSUME_NONNULL_END
