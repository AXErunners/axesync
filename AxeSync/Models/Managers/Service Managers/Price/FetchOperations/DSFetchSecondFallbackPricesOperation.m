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

#import "DSFetchSecondFallbackPricesOperation.h"

#import "DSCurrencyPriceObject.h"
#import "DSHTTPBitPayOperation.h"
#import "DSHTTPAxeCasaOperation.h"
#import "DSHTTPAxeCentralOperation.h"
#import "DSHTTPPoloniexOperation.h"

NS_ASSUME_NONNULL_BEGIN

#define BITPAY_TICKER_URL @"https://bitpay.com/rates"
#define POLONIEX_TICKER_URL @"https://poloniex.com/public?command=returnOrderBook&currencyPair=BTC_AXE&depth=1"
#define AXECENTRAL_TICKER_URL @"https://www.axecentral.org/api/v1/public"
#define AXECASA_TICKER_URL @"http://axe.casa/api/?cur=VES"

@interface DSFetchSecondFallbackPricesOperation ()

@property (strong, nonatomic) DSHTTPBitPayOperation *bitPayOperation;
@property (strong, nonatomic) DSHTTPPoloniexOperation *poloniexOperation;
@property (strong, nonatomic) DSHTTPAxeCentralOperation *axecentralOperation;
@property (strong, nonatomic) DSHTTPAxeCasaOperation *axeCasaOperation;

@property (copy, nonatomic) void (^fetchCompletion)(NSArray<DSCurrencyPriceObject *> *_Nullable);

@end

@implementation DSFetchSecondFallbackPricesOperation

- (DSOperation *)initOperationWithCompletion:(void (^)(NSArray<DSCurrencyPriceObject *> *_Nullable))completion {
    self = [super initWithOperations:nil];
    if (self) {
        {
            HTTPRequest *request = [HTTPRequest requestWithURL:[NSURL URLWithString:BITPAY_TICKER_URL]
                                                        method:HTTPRequestMethod_GET
                                                    parameters:nil];
            request.timeout = 30.0;
            request.cachePolicy = NSURLRequestReloadIgnoringCacheData;

            DSHTTPBitPayOperation *operation = [[DSHTTPBitPayOperation alloc] initWithRequest:request];
            _bitPayOperation = operation;
            [self addOperation:operation];
        }
        {
            HTTPRequest *request = [HTTPRequest requestWithURL:[NSURL URLWithString:POLONIEX_TICKER_URL]
                                                        method:HTTPRequestMethod_GET
                                                    parameters:nil];
            request.timeout = 30.0;
            request.cachePolicy = NSURLRequestReloadIgnoringCacheData;

            DSHTTPPoloniexOperation *operation = [[DSHTTPPoloniexOperation alloc] initWithRequest:request];
            _poloniexOperation = operation;
            [self addOperation:operation];
        }
        {
            HTTPRequest *request = [HTTPRequest requestWithURL:[NSURL URLWithString:AXECENTRAL_TICKER_URL]
                                                        method:HTTPRequestMethod_GET
                                                    parameters:nil];
            request.timeout = 30.0;
            request.cachePolicy = NSURLRequestReloadIgnoringCacheData;

            DSHTTPAxeCentralOperation *operation = [[DSHTTPAxeCentralOperation alloc] initWithRequest:request];
            _axecentralOperation = operation;
            [self addOperation:operation];
        }
        {
            HTTPRequest *request = [HTTPRequest requestWithURL:[NSURL URLWithString:AXECASA_TICKER_URL]
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
        [self.bitPayOperation cancel];
        [self.poloniexOperation cancel];
        [self.axecentralOperation cancel];
        [self.axeCasaOperation cancel];
    }
}

- (void)finishedWithErrors:(NSArray<NSError *> *)errors {
    if (self.cancelled) {
        return;
    }

    if (errors.count > 0) {
        self.fetchCompletion(nil);

        return;
    }

    NSArray *currencyCodes = self.bitPayOperation.currencyCodes;
    NSArray *currencyPrices = self.bitPayOperation.currencyPrices;
    NSNumber *poloniexPriceNumber = self.poloniexOperation.lastTradePriceNumber;
    NSNumber *axecentralPriceNumber = self.axecentralOperation.btcAxePrice;
    NSNumber *axecasaPrice = self.axeCasaOperation.axerate;


    // not enough data to build prices
    if (!currencyCodes ||
        !currencyPrices ||
        !(poloniexPriceNumber || axecentralPriceNumber) ||
        !axecasaPrice ||
        currencyCodes.count != currencyPrices.count) {

        self.fetchCompletion(nil);

        return;
    }

    double poloniexPrice = poloniexPriceNumber.doubleValue;
    double axecentralPrice = axecentralPriceNumber.doubleValue;
    double axeBtcPrice = 0.0;
    if (poloniexPrice > 0.0) {
        if (axecentralPrice > 0.0) {
            axeBtcPrice = (poloniexPrice + axecentralPrice) / 2.0;
        }
        else {
            axeBtcPrice = poloniexPrice;
        }
    }
    else if (axecentralPrice > 0.0) {
        axeBtcPrice = axecentralPrice;
    }

    if (axeBtcPrice < DBL_EPSILON) {
        self.fetchCompletion(nil);

        return;
    }

    NSMutableArray<DSCurrencyPriceObject *> *prices = [NSMutableArray array];
    for (NSString *code in currencyCodes) {
        double price = 0.0;
        if ([code isEqualToString:@"VES"]) {
            price = axecasaPrice.doubleValue;
        }
        else {
            NSUInteger index = [currencyCodes indexOfObject:code];
            NSNumber *btcPrice = currencyPrices[index];
            price = btcPrice.doubleValue * axeBtcPrice;
        }

        if (price > DBL_EPSILON) {
            DSCurrencyPriceObject *priceObject = [[DSCurrencyPriceObject alloc] initWithCode:code price:@(price)];
            if (priceObject) {
                [prices addObject:priceObject];
            }
        }
    }

    self.fetchCompletion([prices copy]);
}

@end

NS_ASSUME_NONNULL_END
