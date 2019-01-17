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


#import "DSFetchFirstFallbackPricesOperation.h"

#import "DSChainedOperation.h"
#import "DSCurrencyPriceObject.h"
#import "DSHTTPOperation.h"
#import "DSOperationQueue.h"
#import "DSParseBitcoinAvgResponseOperation.h"
#import "DSParseAxeBtcCCResponseOperation.h"
#import "DSParseAxeCasaResponseOperation.h"

NS_ASSUME_NONNULL_BEGIN

#define AXEBTCCC_TICKER_URL @"https://min-api.cryptocompare.com/data/generateAvg?fsym=AXE&tsym=BTC&e=Binance,Kraken,Poloniex,Bitfinex"
#define BITCOINAVG_TICKER_URL @"https://apiv2.bitcoinaverage.com/indices/global/ticker/short?crypto=BTC"
#define AXECASA_TICKER_URL @"http://axe.casa/api/?cur=VES"

#pragma mark - Cache

@interface DSFetchFirstFallbackPricesOperationCache : NSObject

@property (strong, nonatomic, nullable) NSDictionary<NSString *, NSNumber *> *pricesByCode;
@property (strong, nonatomic, nullable) NSNumber *axeBtcPrice;
@property (strong, nonatomic, nullable) NSNumber *axecasaLastPrice;

@end

@implementation DSFetchFirstFallbackPricesOperationCache

+ (instancetype)sharedInstance {
    static DSFetchFirstFallbackPricesOperationCache *_sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _sharedInstance = [[self alloc] init];
    });
    return _sharedInstance;
}

@end

#pragma mark - Operation

@interface DSFetchFirstFallbackPricesOperation ()

@property (strong, nonatomic) DSParseAxeBtcCCResponseOperation *parseAxeBtcCCOperation;
@property (strong, nonatomic) DSParseBitcoinAvgResponseOperation *parseBitcoinAvgOperation;
@property (strong, nonatomic) DSParseAxeCasaResponseOperation *parseAxeCasaOperation;
@property (strong, nonatomic) DSChainedOperation *chainAxeBtcCCOperation;
@property (strong, nonatomic) DSChainedOperation *chainBitcoinAvgOperation;
@property (strong, nonatomic) DSChainedOperation *chainAxeCasaOperation;

@property (copy, nonatomic) void (^fetchCompletion)(NSArray<DSCurrencyPriceObject *> *_Nullable);

@end

@implementation DSFetchFirstFallbackPricesOperation

- (DSOperation *)initOperationWithCompletion:(void (^)(NSArray<DSCurrencyPriceObject *> *_Nullable))completion {
    self = [super initWithOperations:nil];
    if (self) {
        {
            NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL URLWithString:AXEBTCCC_TICKER_URL]
                                                     cachePolicy:NSURLRequestReloadIgnoringCacheData
                                                 timeoutInterval:30.0];
            DSHTTPOperation *getOperation = [[DSHTTPOperation alloc] initWithRequest:request];
            DSParseAxeBtcCCResponseOperation *parseOperation = [[DSParseAxeBtcCCResponseOperation alloc] init];
            DSChainedOperation *chainOperation = [DSChainedOperation operationWithOperations:@[ getOperation, parseOperation ]];
            _parseAxeBtcCCOperation = parseOperation;
            _chainAxeBtcCCOperation = chainOperation;
            [self addOperation:chainOperation];
        }
        {
            NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL URLWithString:BITCOINAVG_TICKER_URL]
                                                     cachePolicy:NSURLRequestReloadIgnoringCacheData
                                                 timeoutInterval:30.0];
            DSHTTPOperation *getOperation = [[DSHTTPOperation alloc] initWithRequest:request];
            DSParseBitcoinAvgResponseOperation *parseOperation = [[DSParseBitcoinAvgResponseOperation alloc] init];
            DSChainedOperation *chainOperation = [DSChainedOperation operationWithOperations:@[ getOperation, parseOperation ]];
            _parseBitcoinAvgOperation = parseOperation;
            _chainBitcoinAvgOperation = chainOperation;
            [self addOperation:chainOperation];
        }
        {
            NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL URLWithString:AXECASA_TICKER_URL]
                                                     cachePolicy:NSURLRequestReloadIgnoringCacheData
                                                 timeoutInterval:30.0];
            DSHTTPOperation *getOperation = [[DSHTTPOperation alloc] initWithRequest:request];
            DSParseAxeCasaResponseOperation *parseOperation = [[DSParseAxeCasaResponseOperation alloc] init];
            DSChainedOperation *chainOperation = [DSChainedOperation operationWithOperations:@[ getOperation, parseOperation ]];
            _parseAxeCasaOperation = parseOperation;
            _chainAxeCasaOperation = chainOperation;
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

    DSFetchFirstFallbackPricesOperationCache *cache = [DSFetchFirstFallbackPricesOperationCache sharedInstance];
    if (operation == self.chainAxeBtcCCOperation) {
        NSNumber *axeBtcPrice = self.parseAxeBtcCCOperation.axeBtcPrice;
        if (axeBtcPrice) {
            cache.axeBtcPrice = axeBtcPrice;
        }
    }
    else if (operation == self.chainBitcoinAvgOperation) {
        NSDictionary<NSString *, NSNumber *> *pricesByCode = self.parseBitcoinAvgOperation.pricesByCode;
        if (pricesByCode) {
            cache.pricesByCode = pricesByCode;
        }
    }
    else if (operation == self.chainAxeCasaOperation) {
        NSNumber *axecasaLastPrice = self.parseAxeCasaOperation.axerate;
        if (axecasaLastPrice) {
            cache.axecasaLastPrice = axecasaLastPrice;
        }
    }
}

- (void)finishedWithErrors:(NSArray<NSError *> *)errors {
    if (self.cancelled) {
        return;
    }

    DSFetchFirstFallbackPricesOperationCache *cache = [DSFetchFirstFallbackPricesOperationCache sharedInstance];
    double axeBtcPrice = cache.axeBtcPrice.doubleValue;
    NSDictionary<NSString *, NSNumber *> *pricesByCode = cache.pricesByCode;
    NSNumber *axecasaLastPrice = cache.axecasaLastPrice;

    if (!pricesByCode || axeBtcPrice < DBL_EPSILON) {
        self.fetchCompletion(nil);

        return;
    }

    NSMutableArray<DSCurrencyPriceObject *> *prices = [NSMutableArray array];
    for (NSString *code in pricesByCode) {
        DSCurrencyPriceObject *priceObject = nil;
        if ([code isEqualToString:@"VES"] && axecasaLastPrice) {
            priceObject = [[DSCurrencyPriceObject alloc] initWithCode:code price:axecasaLastPrice];
        }
        else {
            double btcPrice = [pricesByCode[code] doubleValue];
            double price = btcPrice * axeBtcPrice;
            if (price > DBL_EPSILON) {
                priceObject = [[DSCurrencyPriceObject alloc] initWithCode:code price:@(price)];
            }
        }
        if (priceObject) {
            [prices addObject:priceObject];
        }
    }

    self.fetchCompletion([prices copy]);
}

@end

NS_ASSUME_NONNULL_END
