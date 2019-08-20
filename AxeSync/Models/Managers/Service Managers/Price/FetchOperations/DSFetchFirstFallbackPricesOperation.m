//
//  Created by Andrew Podkovyrin
//  Copyright © 2019 Dash Core Group. All rights reserved.
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

#import "DSCurrencyPriceObject.h"
#import "DSHTTPBitcoinAvgOperation.h"
#import "DSHTTPAxeBtcCCOperation.h"
#import "DSHTTPAxeCasaOperation.h"
#import "DSOperationQueue.h"

NS_ASSUME_NONNULL_BEGIN

#define AXEBTCCC_TICKER_URL @"https://min-api.cryptocompare.com/data/generateAvg?fsym=AXE&tsym=BTC&e=Binance,Kraken,Poloniex,Bitfinex"
#define BITCOINAVG_TICKER_URL @"https://apiv2.bitcoinaverage.com/indices/global/ticker/short?crypto=BTC"
#define AXEVESCASA_TICKER_URL @"http://axe.casa/api/?cur=VES"

@interface DSFetchFirstFallbackPricesOperation ()

@property (strong, nonatomic) DSHTTPAxeBtcCCOperation *axeBtcCCOperation;
@property (strong, nonatomic) DSHTTPBitcoinAvgOperation *bitcoinAvgOperation;
@property (strong, nonatomic) DSHTTPAxeCasaOperation *axeCasaOperation;

@property (copy, nonatomic) void (^fetchCompletion)(NSArray<DSCurrencyPriceObject *> *_Nullable, NSString *priceSource);

@end

@implementation DSFetchFirstFallbackPricesOperation

- (DSOperation *)initOperationWithCompletion:(void (^)(NSArray<DSCurrencyPriceObject *> *_Nullable, NSString *priceSource))completion {
    self = [super initWithOperations:nil];
    if (self) {
        {
            HTTPRequest *request = [HTTPRequest requestWithURL:[NSURL URLWithString:AXEBTCCC_TICKER_URL]
                                                        method:HTTPRequestMethod_GET
                                                    parameters:nil];
            request.timeout = 30.0;
            request.cachePolicy = NSURLRequestReloadIgnoringCacheData;
            DSHTTPAxeBtcCCOperation *operation = [[DSHTTPAxeBtcCCOperation alloc] initWithRequest:request];
            _axeBtcCCOperation = operation;
            [self addOperation:operation];
        }
        {
            HTTPRequest *request = [HTTPRequest requestWithURL:[NSURL URLWithString:BITCOINAVG_TICKER_URL]
                                                        method:HTTPRequestMethod_GET
                                                    parameters:nil];
            request.timeout = 30.0;
            request.cachePolicy = NSURLRequestReloadIgnoringCacheData;
            DSHTTPBitcoinAvgOperation *operation = [[DSHTTPBitcoinAvgOperation alloc] initWithRequest:request];
            _bitcoinAvgOperation = operation;
            [self addOperation:operation];
        }
        {
            HTTPRequest *request = [HTTPRequest requestWithURL:[NSURL URLWithString:AXEVESCASA_TICKER_URL]
                                                        method:HTTPRequestMethod_GET
                                                    parameters:nil];
            request.timeout = 30.0;
            request.cachePolicy = NSURLRequestReloadIgnoringCacheData;

            DSHTTPAxeCasaOperation *operation = [[DSHTTPAxeCasaOperation alloc] initWithRequest:request];
            _axeCasaOperation = operation;
            [self addOperation:operation];
        }

        _fetchCompletion = [completion copy];
    }
    return self;
}

- (void)operationDidFinish:(NSOperation *)operation withErrors:(nullable NSArray<NSError *> *)errors {
    if (self.cancelled) {
        return;
    }

    if (errors.count > 0) {
        [self.axeBtcCCOperation cancel];
        [self.bitcoinAvgOperation cancel];
        [self.axeCasaOperation cancel];
    }
}

- (void)finishedWithErrors:(NSArray<NSError *> *)errors {
    if (self.cancelled) {
        return;
    }

    if (errors.count > 0) {
        self.fetchCompletion(nil, [self.class priceSourceInfo]);

        return;
    }

    double axeBtcPrice = self.axeBtcCCOperation.axeBtcPrice.doubleValue;
    NSDictionary<NSString *, NSNumber *> *pricesByCode = self.bitcoinAvgOperation.pricesByCode;
    NSNumber *axerateNumber = self.axeCasaOperation.axerate;

    if (!pricesByCode || axeBtcPrice < DBL_EPSILON || !axerateNumber) {
        self.fetchCompletion(nil, [self.class priceSourceInfo]);

        return;
    }

    NSMutableArray<DSCurrencyPriceObject *> *prices = [NSMutableArray array];
    for (NSString *code in pricesByCode) {
        double price = 0.0;
        if ([code isEqualToString:@"VES"]) {
            price = axerateNumber.doubleValue;
        }
        else {
            double btcPrice = [pricesByCode[code] doubleValue];
            price = btcPrice * axeBtcPrice;
        }

        if (price > DBL_EPSILON) {
            DSCurrencyPriceObject *priceObject = [[DSCurrencyPriceObject alloc] initWithCode:code price:@(price)];
            if (priceObject) {
                [prices addObject:priceObject];
            }
        }
    }

    self.fetchCompletion([prices copy], [self.class priceSourceInfo]);
}

+ (NSString *)priceSourceInfo {
    return @"cryptocompare.com, bitcoinaverage.com, axe.casa";
}

@end

NS_ASSUME_NONNULL_END
