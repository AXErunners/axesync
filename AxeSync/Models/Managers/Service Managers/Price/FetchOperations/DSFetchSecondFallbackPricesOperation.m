//
//  Created by Andrew Podkovyrin
//  Copyright © 2018 Dash Core Group. All rights reserved.
//
//  Licensed under the MIT License (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//  https://opensource.org/licenses/MIT
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

#import "DSFetchSecondFallbackPricesOperation.h"

#import "DSChainedOperation.h"
#import "DSCurrencyPriceObject.h"
#import "DSDynamicOptions.h"
#import "DSHTTPGETOperation.h"
#import "DSOperationQueue.h"
#import "DSParseBitPayResponseOperation.h"
#import "DSParseAxeCentralResponseOperation.h"
#import "DSParsePoloniexResponseOperation.h"

NS_ASSUME_NONNULL_BEGIN

#define BITPAY_TICKER_URL @"https://bitpay.com/rates"
#define POLONIEX_TICKER_URL @"https://poloniex.com/public?command=returnOrderBook&currencyPair=BTC_AXE&depth=1"
#define AXECENTRAL_TICKER_URL @"https://www.axecentral.org/api/v1/public"

#define CURRENCY_CODES_KEY @"CURRENCY_CODES"
#define CURRENCY_PRICES_KEY @"CURRENCY_PRICES"
#define POLONIEX_AXE_BTC_PRICE_KEY @"POLONIEX_AXE_BTC_PRICE"
#define AXECENTRAL_AXE_BTC_PRICE_KEY @"AXECENTRAL_AXE_BTC_PRICE"

#pragma mark - Cache

@interface DSFetchSecondFallbackPricesOperationCache : DSDynamicOptions

@property (nonatomic, copy) NSArray<NSString *> *currencyCodes;
@property (nonatomic, copy) NSArray<NSNumber *> *currencyPrices;

@property (strong, nonatomic) NSNumber *poloniexLastPrice;
@property (strong, nonatomic) NSNumber *axecentralLastPrice;

@end

@implementation DSFetchSecondFallbackPricesOperationCache

@dynamic currencyCodes;
@dynamic currencyPrices;
@dynamic poloniexLastPrice;
@dynamic axecentralLastPrice;

+ (instancetype)sharedInstance {
    static DSFetchSecondFallbackPricesOperationCache *_sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _sharedInstance = [[self alloc] init];
    });
    return _sharedInstance;
}

- (NSString *)defaultsKeyForPropertyName:(NSString *)propertyName {
    NSDictionary *defaultsKeyByProperty = @{
        @"currencyCodes" : CURRENCY_CODES_KEY,
        @"currencyPrices" : CURRENCY_PRICES_KEY,
        @"poloniexLastPrice" : POLONIEX_AXE_BTC_PRICE_KEY,
        @"axecentralLastPrice" : AXECENTRAL_AXE_BTC_PRICE_KEY,
    };
    NSString *defaultsKey = defaultsKeyByProperty[propertyName];
    NSParameterAssert(defaultsKey);
    return defaultsKey ?: propertyName;
}

@end

#pragma mark - Operation

@interface DSFetchSecondFallbackPricesOperation ()

@property (strong, nonatomic) DSParseBitPayResponseOperation *parseBitPayOperation;
@property (strong, nonatomic) DSParsePoloniexResponseOperation *parsePoloniexOperation;
@property (strong, nonatomic) DSParseAxeCentralResponseOperation *parseAxecentralOperation;
@property (strong, nonatomic) DSChainedOperation *chainBitPayOperation;
@property (strong, nonatomic) DSChainedOperation *chainPoloniexOperation;
@property (strong, nonatomic) DSChainedOperation *chainAxecentralOperation;

@property (copy, nonatomic) void (^fetchCompletion)(NSArray<DSCurrencyPriceObject *> *_Nullable);

@end

@implementation DSFetchSecondFallbackPricesOperation

- (DSOperation *)initOperationWithCompletion:(void (^)(NSArray<DSCurrencyPriceObject *> *_Nullable))completion {
    self = [super initWithOperations:nil];
    if (self) {
        {
            NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL URLWithString:BITPAY_TICKER_URL]
                                                     cachePolicy:NSURLRequestReloadIgnoringCacheData
                                                 timeoutInterval:10.0];
            DSHTTPGETOperation *getOperation = [[DSHTTPGETOperation alloc] initWithRequest:request];
            DSParseBitPayResponseOperation *parseOperation = [[DSParseBitPayResponseOperation alloc] init];
            DSChainedOperation *chainOperation = [DSChainedOperation operationWithOperations:@[ getOperation, parseOperation ]];
            _parseBitPayOperation = parseOperation;
            _chainBitPayOperation = chainOperation;
            [self addOperation:chainOperation];
        }
        {
            NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL URLWithString:POLONIEX_TICKER_URL]
                                                     cachePolicy:NSURLRequestReloadIgnoringCacheData
                                                 timeoutInterval:30.0];
            DSHTTPGETOperation *getOperation = [[DSHTTPGETOperation alloc] initWithRequest:request];
            DSParsePoloniexResponseOperation *parseOperation = [[DSParsePoloniexResponseOperation alloc] init];
            DSChainedOperation *chainOperation = [DSChainedOperation operationWithOperations:@[ getOperation, parseOperation ]];
            _parsePoloniexOperation = parseOperation;
            _chainPoloniexOperation = chainOperation;
            [self addOperation:chainOperation];
        }
        {
            NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL URLWithString:AXECENTRAL_TICKER_URL]
                                                     cachePolicy:NSURLRequestReloadIgnoringCacheData
                                                 timeoutInterval:30.0];
            DSHTTPGETOperation *getOperation = [[DSHTTPGETOperation alloc] initWithRequest:request];
            DSParseAxeCentralResponseOperation *parseOperation = [[DSParseAxeCentralResponseOperation alloc] init];
            DSChainedOperation *chainOperation = [DSChainedOperation operationWithOperations:@[ getOperation, parseOperation ]];
            _parseAxecentralOperation = parseOperation;
            _chainAxecentralOperation = chainOperation;
            [self addOperation:chainOperation];
        }

        _fetchCompletion = [completion copy];
    }
    return self;
}

- (void)operationDidFinish:(NSOperation *)operation withErrors:(nullable NSArray<NSError *> *)errors {
    if (self.cancelled) {
        return;
    }

    DSFetchSecondFallbackPricesOperationCache *cache = [DSFetchSecondFallbackPricesOperationCache sharedInstance];
    if (operation == self.chainBitPayOperation) {
        NSArray *currencyCodes = self.parseBitPayOperation.currencyCodes;
        NSArray *currencyPrices = self.parseBitPayOperation.currencyPrices;
        if (currencyCodes && currencyPrices) {
            cache.currencyCodes = currencyCodes;
            cache.currencyPrices = currencyPrices;
        }
    }
    else if (operation == self.chainPoloniexOperation) {
        NSNumber *poloniexPrice = self.parsePoloniexOperation.lastTradePriceNumber;
        if (poloniexPrice) {
            cache.poloniexLastPrice = poloniexPrice;
        }
    }
    else if (operation == self.chainAxecentralOperation) {
        NSNumber *axecentralPrice = self.parseAxecentralOperation.btcAxePrice;
        if (axecentralPrice) {
            cache.axecentralLastPrice = axecentralPrice;
        }
    }
}

- (void)finishedWithErrors:(NSArray<NSError *> *)errors {
    if (self.cancelled) {
        return;
    }

    DSFetchSecondFallbackPricesOperationCache *cache = [DSFetchSecondFallbackPricesOperationCache sharedInstance];
    NSArray<NSString *> *currencyCodes = cache.currencyCodes;
    NSArray<NSNumber *> *currencyPrices = cache.currencyPrices;
    NSNumber *poloniexPriceNumber = cache.poloniexLastPrice;
    NSNumber *axecentralPriceNumber = cache.axecentralLastPrice;

    // not enough data to build prices
    if (!currencyCodes ||
        !currencyPrices ||
        !(poloniexPriceNumber || axecentralPriceNumber) ||
        currencyCodes.count != currencyPrices.count) {

        self.fetchCompletion(nil);

        return;
    }

    double poloniexPrice = poloniexPriceNumber.doubleValue;
    double axecentralPrice = axecentralPriceNumber.doubleValue;
    double btcAxePrice = 0.0;
    if (poloniexPrice > 0.0) {
        if (axecentralPrice > 0.0) {
            btcAxePrice = (poloniexPrice + axecentralPrice) / 2.0;
        }
        else {
            btcAxePrice = poloniexPrice;
        }
    }
    else if (axecentralPrice > 0.0) {
        btcAxePrice = axecentralPrice;
    }

    if (btcAxePrice < DBL_EPSILON) {
        self.fetchCompletion(nil);

        return;
    }

    NSMutableArray<DSCurrencyPriceObject *> *prices = [NSMutableArray array];
    for (NSString *code in currencyCodes) {
        NSUInteger index = [currencyCodes indexOfObject:code];
        NSNumber *btcPrice = currencyPrices[index];
        NSNumber *price = @(btcPrice.doubleValue * btcAxePrice);
        DSCurrencyPriceObject *priceObject = [[DSCurrencyPriceObject alloc] initWithCode:code price:price];
        if (priceObject) {
            [prices addObject:priceObject];
        }
    }

    self.fetchCompletion([prices copy]);
}

@end

NS_ASSUME_NONNULL_END
