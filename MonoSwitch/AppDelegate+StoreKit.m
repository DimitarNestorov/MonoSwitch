#import "AppDelegate+StoreKit.h"

#define $(...) [NSSet setWithObjects:__VA_ARGS__, nil]

NSString *proVersionInAppPurchaseId = @"MonoSwitch_Pro_Version";

void runOnMainQueueWithoutDeadlocking(void (^block)(void)) {
    if ([NSThread isMainThread]) {
        block();
    } else {
        dispatch_sync(dispatch_get_main_queue(), block);
    }
}

@interface AppDelegate (StoreKitUI)

@property (unsafe_unretained) IBOutlet NSButton *buyProVersionButton;

@property (unsafe_unretained) IBOutlet NSButton *restorePurchasesButton;

@property (unsafe_unretained) IBOutlet NSBox *box;

@end

@implementation AppDelegate (StoreKitUI)

NSButton *_buyProVersionButton;
NSButton *_restorePurchasesButton;
NSBox *_box;

- (void)setBuyProVersionButton:(NSButton *)buyProVersionButton {
    _buyProVersionButton = buyProVersionButton;
}

- (NSButton *)buyProVersionButton {
    return _buyProVersionButton;
}

- (void)setRestorePurchasesButton:(NSButton *)restorePurchasesButton {
    _restorePurchasesButton = restorePurchasesButton;
}

- (NSButton *)restorePurchasesButton {
    return _restorePurchasesButton;
}

- (void)setBox:(NSBox *)box {
    _box = box;
}

- (NSBox *)box {
    return _box;
}

@end

@implementation AppDelegate (StoreKit)

API_AVAILABLE(macos(10.7))
SKProduct *_proVersionProduct;

BOOL _isProVersionPurchased;

- (BOOL)isProVersionPurchased {
    return _isProVersionPurchased;
}

- (void)setProVersionPurchased:(BOOL)isProVersionPurchased {
    _isProVersionPurchased = isProVersionPurchased;
    if (isProVersionPurchased) {
        runOnMainQueueWithoutDeadlocking(^{
            self.buyProVersionButton.enabled = false;
            self.box.title = @"Pro Version (Purchased)";
        });
    }
}

- (void)initStoreKit {
    if (@available(macOS 10.7, *)) {
        SKProductsRequest *productsRequest = [[SKProductsRequest alloc] initWithProductIdentifiers:$(proVersionInAppPurchaseId)];
        productsRequest.delegate = self;
        [productsRequest start];
        
        [SKPaymentQueue.defaultQueue addTransactionObserver:self];
        
        self.restorePurchasesButton.enabled = true;
    }
}

- (IBAction)purchaseProVersion:(id)sender {
    if (@available(macOS 10.7, *)) {
        SKPayment *payment = [SKPayment paymentWithProduct:_proVersionProduct];
        [SKPaymentQueue.defaultQueue addPayment:payment];
    }
}

- (void)productsRequest:(SKProductsRequest *)request didReceiveResponse:(SKProductsResponse *)response API_AVAILABLE(macos(10.7)){
    for (SKProduct *product in response.products) {
        if ([product.productIdentifier isEqualToString:proVersionInAppPurchaseId]) {
            _proVersionProduct = product;
            if (!_isProVersionPurchased) {
                runOnMainQueueWithoutDeadlocking(^{
                    self.buyProVersionButton.enabled = true;
                });
            }
        }
    }
}

- (void)request:(SKRequest *)request didFailWithError:(NSError *)error API_AVAILABLE(macos(10.7)){
    // TODO: Sentry
    @throw error;
}

- (void)paymentQueue:(SKPaymentQueue *)queue updatedTransactions:(NSArray<SKPaymentTransaction *> *)transactions API_AVAILABLE(macos(10.7)){
    for (SKPaymentTransaction *transaction in transactions) {
        if ([transaction.payment.productIdentifier isEqualToString:proVersionInAppPurchaseId] && (transaction.transactionState == SKPaymentTransactionStatePurchased || transaction.transactionState == SKPaymentTransactionStateRestored)) {
            [self setProVersionPurchased:true];
        }
    }
}

- (IBAction)restorePurchases:(id)sender {
    if (@available(macOS 10.7, *)) {
        [SKPaymentQueue.defaultQueue restoreCompletedTransactions];
    }
}

@end
