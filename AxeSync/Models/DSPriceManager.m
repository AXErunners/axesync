//
//  DSPriceManager.m
//  AxeSync
//
//  Created by Aaron Voisine on 3/2/14.
//  Copyright (c) 2014 Aaron Voisine <voisine@gmail.com>
//  Updated by Quantum Explorer on 05/11/18.
//  Copyright (c) 2018 Quantum Explorer <quantum@dash.org>
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.

#import "DSPriceManager.h"
#import "DSWallet.h"
#import "DSChainManager.h"
#import "DSAccount.h"
#import "DSKey.h"
#import "DSChain.h"
#import "DSKey+BIP38.h"
#import "DSBIP39Mnemonic.h"
#import "DSTransaction.h"
#import "DSTransactionEntity+CoreDataClass.h"
#import "DSAddressEntity+CoreDataClass.h"
#import "DSEventManager.h"
#import "NSString+Bitcoin.h"
#import "NSData+Bitcoin.h"
#import "NSMutableData+Axe.h"
#import "NSManagedObject+Sugar.h"
#import "NSAttributedString+Attachments.h"
#import "NSString+Axe.h"
#import "Reachability.h"
#import "DSChainPeerManager.h"
#import "DSDerivationPath.h"
#import "DSAuthenticationManager.h"
#import "NSData+Bitcoin.h"

#define BITCOIN_TICKER_URL  @"https://bitpay.com/rates"
#define POLONIEX_TICKER_URL  @"https://poloniex.com/public?command=returnOrderBook&currencyPair=BTC_AXE&depth=1"
#define AXECENTRAL_TICKER_URL  @"https://www.axecentral.org/api/v1/public"
#define TICKER_REFRESH_TIME 60.0

#define DEFAULT_CURRENCY_CODE @"USD"
#define DEFAULT_SPENT_LIMIT   DUFFS

#define LOCAL_CURRENCY_CODE_KEY @"LOCAL_CURRENCY_CODE"
#define CURRENCY_CODES_KEY      @"CURRENCY_CODES"
#define CURRENCY_NAMES_KEY      @"CURRENCY_NAMES"
#define CURRENCY_PRICES_KEY     @"CURRENCY_PRICES"
#define POLONIEX_AXE_BTC_PRICE_KEY  @"POLONIEX_AXE_BTC_PRICE"
#define POLONIEX_AXE_BTC_UPDATE_TIME_KEY  @"POLONIEX_AXE_BTC_UPDATE_TIME"
#define AXECENTRAL_AXE_BTC_PRICE_KEY @"AXECENTRAL_AXE_BTC_PRICE"
#define AXECENTRAL_AXE_BTC_UPDATE_TIME_KEY @"AXECENTRAL_AXE_BTC_UPDATE_TIME"

#define USER_ACCOUNT_KEY    @"https://api.axewallet.com"


@interface DSPriceManager()

@property (nonatomic, strong) Reachability *reachability;
@property (nonatomic, strong) NSArray *currencyPrices;
@property (nonatomic, strong) id protectedObserver;

@property (nonatomic, strong) NSNumber * _Nullable bitcoinAxePrice; // exchange rate in bitcoin per axe
@property (nonatomic, strong) NSNumber * _Nullable localCurrencyBitcoinPrice; // exchange rate in local currency units per bitcoin
@property (nonatomic, strong) NSNumber * _Nullable localCurrencyAxePrice;

@end

@implementation DSPriceManager

+ (instancetype)sharedInstance
{
    static id singleton = nil;
    static dispatch_once_t onceToken = 0;
    
    dispatch_once(&onceToken, ^{
        singleton = [self new];
    });
    
    return singleton;
}

- (instancetype)init
{
    if (! (self = [super init])) return nil;
    
    [NSManagedObject setConcurrencyType:NSPrivateQueueConcurrencyType];
    self.reachability = [Reachability reachabilityForInternetConnection];
    _axeFormat = [NSNumberFormatter new];
    self.axeFormat.lenient = YES;
    self.axeFormat.numberStyle = NSNumberFormatterCurrencyStyle;
    self.axeFormat.generatesDecimalNumbers = YES;
    self.axeFormat.negativeFormat = [self.axeFormat.positiveFormat
                                      stringByReplacingCharactersInRange:[self.axeFormat.positiveFormat rangeOfString:@"#"]
                                      withString:@"-#"];
    self.axeFormat.currencyCode = @"AXE";
    self.axeFormat.currencySymbol = AXE NARROW_NBSP;
    self.axeFormat.maximumFractionDigits = 8;
    self.axeFormat.minimumFractionDigits = 0; // iOS 8 bug, minimumFractionDigits now has to be set after currencySymbol
    self.axeFormat.maximum = @(MAX_MONEY/(int64_t)pow(10.0, self.axeFormat.maximumFractionDigits));
    
    _axeSignificantFormat = [NSNumberFormatter new];
    self.axeSignificantFormat.lenient = YES;
    self.axeSignificantFormat.numberStyle = NSNumberFormatterCurrencyStyle;
    self.axeSignificantFormat.generatesDecimalNumbers = YES;
    self.axeSignificantFormat.negativeFormat = [self.axeFormat.positiveFormat
                                                 stringByReplacingCharactersInRange:[self.axeFormat.positiveFormat rangeOfString:@"#"]
                                                 withString:@"-#"];
    self.axeSignificantFormat.currencyCode = @"AXE";
    self.axeSignificantFormat.currencySymbol = AXE NARROW_NBSP;
    self.axeSignificantFormat.usesSignificantDigits = TRUE;
    self.axeSignificantFormat.minimumSignificantDigits = 1;
    self.axeSignificantFormat.maximumSignificantDigits = 6;
    self.axeSignificantFormat.maximumFractionDigits = 8;
    self.axeSignificantFormat.minimumFractionDigits = 0; // iOS 8 bug, minimumFractionDigits now has to be set after currencySymbol
    self.axeSignificantFormat.maximum = @(MAX_MONEY/(int64_t)pow(10.0, self.axeFormat.maximumFractionDigits));
    
    _bitcoinFormat = [NSNumberFormatter new];
    self.bitcoinFormat.lenient = YES;
    self.bitcoinFormat.numberStyle = NSNumberFormatterCurrencyStyle;
    self.bitcoinFormat.generatesDecimalNumbers = YES;
    self.bitcoinFormat.negativeFormat = [self.bitcoinFormat.positiveFormat
                                         stringByReplacingCharactersInRange:[self.bitcoinFormat.positiveFormat rangeOfString:@"#"]
                                         withString:@"-#"];
    self.bitcoinFormat.currencyCode = @"BTC";
    self.bitcoinFormat.currencySymbol = BTC NARROW_NBSP;
    self.bitcoinFormat.maximumFractionDigits = 8;
    self.bitcoinFormat.minimumFractionDigits = 0; // iOS 8 bug, minimumFractionDigits now has to be set after currencySymbol
    self.bitcoinFormat.maximum = @(MAX_MONEY/(int64_t)pow(10.0, self.bitcoinFormat.maximumFractionDigits));
    
    _unknownFormat = [NSNumberFormatter new];
    self.unknownFormat.lenient = YES;
    self.unknownFormat.numberStyle = NSNumberFormatterDecimalStyle;
    self.unknownFormat.generatesDecimalNumbers = YES;
    self.unknownFormat.negativeFormat = [self.unknownFormat.positiveFormat
                                         stringByReplacingCharactersInRange:[self.unknownFormat.positiveFormat rangeOfString:@"#"]
                                         withString:@"-#"];
    self.unknownFormat.maximumFractionDigits = 8;
    self.unknownFormat.minimumFractionDigits = 0; // iOS 8 bug, minimumFractionDigits now has to be set after currencySymbol
    
    _localFormat = [NSNumberFormatter new];
    self.localFormat.lenient = YES;
    self.localFormat.numberStyle = NSNumberFormatterCurrencyStyle;
    self.localFormat.generatesDecimalNumbers = YES;
    self.localFormat.negativeFormat = self.axeFormat.negativeFormat;
    
    NSUserDefaults *defs = [NSUserDefaults standardUserDefaults];
    
    _currencyCodes = [defs arrayForKey:CURRENCY_CODES_KEY];
    _currencyNames = [defs arrayForKey:CURRENCY_NAMES_KEY];
    _currencyPrices = [defs arrayForKey:CURRENCY_PRICES_KEY];
    self.localCurrencyCode = ([defs stringForKey:LOCAL_CURRENCY_CODE_KEY]) ?
    [defs stringForKey:LOCAL_CURRENCY_CODE_KEY] : [[NSLocale currentLocale] objectForKey:NSLocaleCurrencyCode];
    
    return self;
}

- (void)dealloc
{
    [NSObject cancelPreviousPerformRequestsWithTarget:self];
}

-(void)startExchangeRateFetching {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self updateBitcoinExchangeRate];
        [self updateAxeExchangeRate];
        [self updateAxeCentralExchangeRateFallback];
    });
}

// MARK: - exchange rate

// local currency ISO code
- (void)setLocalCurrencyCode:(NSString *)code
{
    NSUserDefaults *defs = [NSUserDefaults standardUserDefaults];
    NSUInteger i = [_currencyCodes indexOfObject:code];
    
    if (i == NSNotFound) code = DEFAULT_CURRENCY_CODE, i = [_currencyCodes indexOfObject:DEFAULT_CURRENCY_CODE];
    _localCurrencyCode = [code copy];
    
    if (i < _currencyPrices.count && [DSAuthenticationManager sharedInstance].secureTime + 3*24*60*60 > [NSDate timeIntervalSinceReferenceDate]) {
        self.localCurrencyBitcoinPrice = _currencyPrices[i]; // don't use exchange rate data more than 72hrs out of date
    }
    else self.localCurrencyBitcoinPrice = @(0);
    
    self.localFormat.currencyCode = _localCurrencyCode;
    self.localFormat.maximum =
    [[NSDecimalNumber decimalNumberWithDecimal:self.localCurrencyBitcoinPrice.decimalValue]
     decimalNumberByMultiplyingBy:(id)[NSDecimalNumber numberWithLongLong:MAX_MONEY/DUFFS]];
    
    if ([self.localCurrencyCode isEqual:[[NSLocale currentLocale] objectForKey:NSLocaleCurrencyCode]]) {
        [defs removeObjectForKey:LOCAL_CURRENCY_CODE_KEY];
    }
    else [defs setObject:self.localCurrencyCode forKey:LOCAL_CURRENCY_CODE_KEY];
    
    //    if (! _wallet) return;
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:DSWalletBalanceDidChangeNotification object:nil];
    });
}

-(NSNumber*)bitcoinAxePrice {
    if (_bitcoinAxePrice.doubleValue == 0) {
        NSUserDefaults *defs = [NSUserDefaults standardUserDefaults];
        
        double poloniexPrice = [[defs objectForKey:POLONIEX_AXE_BTC_PRICE_KEY] doubleValue];
        double axecentralPrice = [[defs objectForKey:AXECENTRAL_AXE_BTC_PRICE_KEY] doubleValue];
        if (poloniexPrice > 0) {
            if (axecentralPrice > 0) {
                _bitcoinAxePrice = @((poloniexPrice + axecentralPrice)/2.0);
            } else {
                _bitcoinAxePrice = @(poloniexPrice);
            }
        } else if (axecentralPrice > 0) {
            _bitcoinAxePrice = @(axecentralPrice);
        }
    }
    return _bitcoinAxePrice;
}

- (void)refreshBitcoinAxePrice{
    NSUserDefaults *defs = [NSUserDefaults standardUserDefaults];
    double poloniexPrice = [[defs objectForKey:POLONIEX_AXE_BTC_PRICE_KEY] doubleValue];
    double axecentralPrice = [[defs objectForKey:AXECENTRAL_AXE_BTC_PRICE_KEY] doubleValue];
    NSNumber * newPrice = 0;
    if (poloniexPrice > 0) {
        if (axecentralPrice > 0) {
            newPrice = @((poloniexPrice + axecentralPrice)/2.0);
        } else {
            newPrice = @(poloniexPrice);
        }
    } else if (axecentralPrice > 0) {
        newPrice = @(axecentralPrice);
    }
    
    //    if (! _wallet ) return;
    //if ([newPrice doubleValue] == [_bitcoinAxePrice doubleValue]) return;
    _bitcoinAxePrice = newPrice;
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:DSWalletBalanceDidChangeNotification object:nil];
    });
}


// until there is a public api for axe prices among multiple currencies it's better that we pull Bitcoin prices per currency and convert it to axe
- (void)updateAxeExchangeRate
{
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(updateAxeExchangeRate) object:nil];
    [self performSelector:@selector(updateAxeExchangeRate) withObject:nil afterDelay:TICKER_REFRESH_TIME];
    if (self.reachability.currentReachabilityStatus == NotReachable) return;
    
    
    NSURLRequest *req = [NSURLRequest requestWithURL:[NSURL URLWithString:POLONIEX_TICKER_URL]
                                         cachePolicy:NSURLRequestReloadIgnoringCacheData timeoutInterval:30.0];
    
    [[[NSURLSession sharedSession] dataTaskWithRequest:req
                                     completionHandler:^(NSData *data, NSURLResponse *response, NSError *connectionError) {
                                         if (((((NSHTTPURLResponse*)response).statusCode /100) != 2) || connectionError) {
                                             NSLog(@"connectionError %@ (status %ld)", connectionError,(long)((NSHTTPURLResponse*)response).statusCode);
                                             return;
                                         }
                                         if ([response isKindOfClass:[NSHTTPURLResponse class]]) { // store server timestamp
                                             NSUserDefaults *defs = [NSUserDefaults standardUserDefaults];
                                             NSString *date = [(NSHTTPURLResponse *)response allHeaderFields][@"Date"];
                                             NSTimeInterval now = [[[NSDataDetector dataDetectorWithTypes:NSTextCheckingTypeDate error:nil]
                                                                    matchesInString:date options:0 range:NSMakeRange(0, date.length)].lastObject
                                                                   date].timeIntervalSinceReferenceDate;
                                             
                                             if (now > [DSAuthenticationManager sharedInstance].secureTime) [defs setDouble:now forKey:SECURE_TIME_KEY];
                                         }
                                         NSError *error = nil;
                                         NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
                                         NSArray * asks = [json objectForKey:@"asks"];
                                         NSArray * bids = [json objectForKey:@"bids"];
                                         if ([asks count] && [bids count] && [[asks objectAtIndex:0] count] && [[bids objectAtIndex:0] count]) {
                                             NSString * lastTradePriceStringAsks = [[asks objectAtIndex:0] objectAtIndex:0];
                                             NSString * lastTradePriceStringBids = [[bids objectAtIndex:0] objectAtIndex:0];
                                             if (lastTradePriceStringAsks && lastTradePriceStringBids) {
                                                 NSNumberFormatter *numberFormatter = [[NSNumberFormatter alloc] init];
                                                 NSLocale *usa = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US"];
                                                 numberFormatter.locale = usa;
                                                 numberFormatter.numberStyle = NSNumberFormatterDecimalStyle;
                                                 NSNumber *lastTradePriceNumberAsks = [numberFormatter numberFromString:lastTradePriceStringAsks];
                                                 NSNumber *lastTradePriceNumberBids = [numberFormatter numberFromString:lastTradePriceStringBids];
                                                 NSNumber * lastTradePriceNumber = @((lastTradePriceNumberAsks.floatValue + lastTradePriceNumberBids.floatValue) / 2);
                                                 NSUserDefaults *defs = [NSUserDefaults standardUserDefaults];
                                                 [defs setObject:lastTradePriceNumber forKey:POLONIEX_AXE_BTC_PRICE_KEY];
                                                 [defs setObject:[NSDate date] forKey:POLONIEX_AXE_BTC_UPDATE_TIME_KEY];
                                                 [defs synchronize];
                                                 [self refreshBitcoinAxePrice];
                                             }
                                         }
#if EXCHANGE_RATES_LOGGING
                                         NSLog(@"poloniex exchange rate updated to %@/%@", [self localCurrencyStringForAxeAmount:DUFFS],
                                               [self stringForAxeAmount:DUFFS]);
#endif
                                     }
      ] resume];
    
}

// until there is a public api for axe prices among multiple currencies it's better that we pull Bitcoin prices per currency and convert it to axe
- (void)updateAxeCentralExchangeRateFallback
{
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(updateAxeCentralExchangeRateFallback) object:nil];
    [self performSelector:@selector(updateAxeCentralExchangeRateFallback) withObject:nil afterDelay:TICKER_REFRESH_TIME];
    if (self.reachability.currentReachabilityStatus == NotReachable) return;
    
    
    NSURLRequest *req = [NSURLRequest requestWithURL:[NSURL URLWithString:AXECENTRAL_TICKER_URL]
                                         cachePolicy:NSURLRequestReloadIgnoringCacheData timeoutInterval:30.0];
    
    [[[NSURLSession sharedSession] dataTaskWithRequest:req
                                     completionHandler:^(NSData *data, NSURLResponse *response, NSError *connectionError) {
                                         if (((((NSHTTPURLResponse*)response).statusCode /100) != 2) || connectionError) {
                                             NSLog(@"connectionError %@ (status %ld)", connectionError,(long)((NSHTTPURLResponse*)response).statusCode);
                                             return;
                                         }
                                         
                                         if ([response isKindOfClass:[NSHTTPURLResponse class]]) { // store server timestamp
                                             NSUserDefaults *defs = [NSUserDefaults standardUserDefaults];
                                             NSString *date = [(NSHTTPURLResponse *)response allHeaderFields][@"Date"];
                                             NSTimeInterval now = [[[NSDataDetector dataDetectorWithTypes:NSTextCheckingTypeDate error:nil]
                                                                    matchesInString:date options:0 range:NSMakeRange(0, date.length)].lastObject
                                                                   date].timeIntervalSinceReferenceDate;
                                             
                                             if (now > [DSAuthenticationManager sharedInstance].secureTime) [defs setDouble:now forKey:SECURE_TIME_KEY];
                                         }
                                         
                                         NSError *error = nil;
                                         NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
                                         if (!error) {
                                             NSNumber * axe_usd = @([[[json objectForKey:@"exchange_rates"] objectForKey:@"btc_axe"] doubleValue]);
                                             if (axe_usd && [axe_usd doubleValue] > 0) {
                                                 NSUserDefaults *defs = [NSUserDefaults standardUserDefaults];
                                                 
                                                 [defs setObject:axe_usd forKey:AXECENTRAL_AXE_BTC_PRICE_KEY];
                                                 [defs setObject:[NSDate date] forKey:AXECENTRAL_AXE_BTC_UPDATE_TIME_KEY];
                                                 [defs synchronize];
                                                 [self refreshBitcoinAxePrice];
#if EXCHANGE_RATES_LOGGING
                                                 NSLog(@"axe central exchange rate updated to %@/%@", [self localCurrencyStringForAxeAmount:DUFFS],
                                                       [self stringForAxeAmount:DUFFS]);
#endif
                                             }
                                         }
                                     }
      ] resume];
    
}

- (void)updateBitcoinExchangeRate
{
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(updateBitcoinExchangeRate) object:nil];
    [self performSelector:@selector(updateBitcoinExchangeRate) withObject:nil afterDelay:TICKER_REFRESH_TIME];
    if (self.reachability.currentReachabilityStatus == NotReachable) return;
    
    NSURLRequest *req = [NSURLRequest requestWithURL:[NSURL URLWithString:BITCOIN_TICKER_URL]
                                         cachePolicy:NSURLRequestReloadIgnoringCacheData timeoutInterval:10.0];
    
    [[[NSURLSession sharedSession] dataTaskWithRequest:req completionHandler:^(NSData *data, NSURLResponse *response, NSError *connectionError) {
        if (((((NSHTTPURLResponse*)response).statusCode /100) != 2) || connectionError) {
            NSLog(@"connectionError %@ (status %ld)", connectionError,(long)((NSHTTPURLResponse*)response).statusCode);
            return;
        }
        
        NSUserDefaults *defs = [NSUserDefaults standardUserDefaults];
        NSError *error = nil;
        NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
        NSMutableArray *codes = [NSMutableArray array], *names = [NSMutableArray array], *rates =[NSMutableArray array];
        
        if ([response isKindOfClass:[NSHTTPURLResponse class]]) { // store server timestamp
            NSString *date = [(NSHTTPURLResponse *)response allHeaderFields][@"Date"];
            NSTimeInterval now = [[[NSDataDetector dataDetectorWithTypes:NSTextCheckingTypeDate error:nil]
                                   matchesInString:date options:0 range:NSMakeRange(0, date.length)].lastObject
                                  date].timeIntervalSinceReferenceDate;
            
            if (now > [DSAuthenticationManager sharedInstance].secureTime) [defs setDouble:now forKey:SECURE_TIME_KEY];
        }
        
        if (error || ! [json isKindOfClass:[NSDictionary class]] || ! [json[@"data"] isKindOfClass:[NSArray class]]) {
            NSLog(@"unexpected response from %@:\n%@", req.URL.host,
                  [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding]);
            return;
        }
        
        for (NSDictionary *d in json[@"data"]) {
            if (! [d isKindOfClass:[NSDictionary class]] || ! [d[@"code"] isKindOfClass:[NSString class]] ||
                ! [d[@"name"] isKindOfClass:[NSString class]] || ! [d[@"rate"] isKindOfClass:[NSNumber class]]) {
                NSLog(@"unexpected response from %@:\n%@", req.URL.host,
                      [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding]);
                return;
            }
            
            if ([d[@"code"] isEqual:@"BTC"]) continue;
            [codes addObject:d[@"code"]];
            [names addObject:d[@"name"]];
            [rates addObject:d[@"rate"]];
        }
        
        self->_currencyCodes = codes;
        self->_currencyNames = names;
        self->_currencyPrices = rates;
        self.localCurrencyCode = self->_localCurrencyCode; // update localCurrencyPrice and localFormat.maximum
        [defs setObject:self.currencyCodes forKey:CURRENCY_CODES_KEY];
        [defs setObject:self.currencyNames forKey:CURRENCY_NAMES_KEY];
        [defs setObject:self.currencyPrices forKey:CURRENCY_PRICES_KEY];
        [defs synchronize];
#if EXCHANGE_RATES_LOGGING
        NSLog(@"bitcoin exchange rate updated to %@/%@", [self localCurrencyStringForAxeAmount:DUFFS],
              [self stringForAxeAmount:DUFFS]);
#endif
    }
      
      
      ] resume];
    
}


// MARK: - string helpers

- (int64_t)amountForUnknownCurrencyString:(NSString *)string
{
    if (! string.length) return 0;
    return [[[NSDecimalNumber decimalNumberWithString:string]
             decimalNumberByMultiplyingByPowerOf10:self.unknownFormat.maximumFractionDigits] longLongValue];
}

- (int64_t)amountForAxeString:(NSString *)string
{
    if (! string.length) return 0;
    NSInteger axeCharPos = [string indexOfCharacter:NSAttachmentCharacter];
    if (axeCharPos != NSNotFound) {
        string = [string stringByReplacingCharactersInRange:NSMakeRange(axeCharPos, 1) withString:AXE];
    }
    return [[[NSDecimalNumber decimalNumberWithDecimal:[[self.axeFormat numberFromString:string] decimalValue]]
             decimalNumberByMultiplyingByPowerOf10:self.axeFormat.maximumFractionDigits] longLongValue];
}

- (int64_t)amountForBitcoinString:(NSString *)string
{
    if (! string.length) return 0;
    return [[[NSDecimalNumber decimalNumberWithDecimal:[[self.bitcoinFormat numberFromString:string] decimalValue]]
             decimalNumberByMultiplyingByPowerOf10:self.bitcoinFormat.maximumFractionDigits] longLongValue];
}

- (NSAttributedString *)attributedStringForAxeAmount:(int64_t)amount
{
    NSString * string = [self.axeFormat stringFromNumber:[(id)[NSDecimalNumber numberWithLongLong:amount]
                                                           decimalNumberByMultiplyingByPowerOf10:-self.axeFormat.maximumFractionDigits]];
    return [string attributedStringForAxeSymbol];
}

- (NSAttributedString *)attributedStringForAxeAmount:(int64_t)amount withTintColor:(UIColor*)color {
    NSString * string = [self.axeFormat stringFromNumber:[(id)[NSDecimalNumber numberWithLongLong:amount]
                                                           decimalNumberByMultiplyingByPowerOf10:-self.axeFormat.maximumFractionDigits]];
    return [string attributedStringForAxeSymbolWithTintColor:color];
}

- (NSAttributedString *)attributedStringForAxeAmount:(int64_t)amount withTintColor:(UIColor*)color useSignificantDigits:(BOOL)useSignificantDigits {
    NSString * string = [(useSignificantDigits?self.axeSignificantFormat:self.axeFormat) stringFromNumber:[(id)[NSDecimalNumber numberWithLongLong:amount]
                                                                                                             decimalNumberByMultiplyingByPowerOf10:-self.axeFormat.maximumFractionDigits]];
    return [string attributedStringForAxeSymbolWithTintColor:color];
}

- (NSAttributedString *)attributedStringForAxeAmount:(int64_t)amount withTintColor:(UIColor*)color axeSymbolSize:(CGSize)axeSymbolSize
{
    NSString * string = [self.axeFormat stringFromNumber:[(id)[NSDecimalNumber numberWithLongLong:amount]
                                                           decimalNumberByMultiplyingByPowerOf10:-self.axeFormat.maximumFractionDigits]];
    return [string attributedStringForAxeSymbolWithTintColor:color axeSymbolSize:axeSymbolSize];
}

- (NSNumber *)numberForAmount:(int64_t)amount
{
    return (id)[(id)[NSDecimalNumber numberWithLongLong:amount]
                decimalNumberByMultiplyingByPowerOf10:-self.axeFormat.maximumFractionDigits];
}

- (NSString *)stringForBitcoinAmount:(int64_t)amount
{
    return [self.bitcoinFormat stringFromNumber:[(id)[NSDecimalNumber numberWithLongLong:amount]
                                                 decimalNumberByMultiplyingByPowerOf10:-self.bitcoinFormat.maximumFractionDigits]];
}

- (NSString *)stringForAxeAmount:(int64_t)amount
{
    return [self.axeFormat stringFromNumber:[(id)[NSDecimalNumber numberWithLongLong:amount]
                                              decimalNumberByMultiplyingByPowerOf10:-self.axeFormat.maximumFractionDigits]];
}

-(NSNumber* _Nonnull)localCurrencyAxePrice {
    if (!_bitcoinAxePrice || !_localCurrencyBitcoinPrice) {
        return _localCurrencyAxePrice;
    } else {
        return @(_bitcoinAxePrice.doubleValue * _localCurrencyBitcoinPrice.doubleValue);
    }
}

// NOTE: For now these local currency methods assume that a satoshi has a smaller value than the smallest unit of any
// local currency. They will need to be revisited when that is no longer a safe assumption.
- (int64_t)amountForLocalCurrencyString:(NSString *)string
{
    if ([string hasPrefix:@"<"]) string = [string substringFromIndex:1];
    
    NSNumber *n = [self.localFormat numberFromString:string];
    int64_t price = [[NSDecimalNumber decimalNumberWithDecimal:self.localCurrencyAxePrice.decimalValue]
                     decimalNumberByMultiplyingByPowerOf10:self.localFormat.maximumFractionDigits].longLongValue,
    local = [[NSDecimalNumber decimalNumberWithDecimal:n.decimalValue]
             decimalNumberByMultiplyingByPowerOf10:self.localFormat.maximumFractionDigits].longLongValue,
    overflowbits = 0, p = 10, min, max, amount;
    
    if (local == 0 || price < 1) return 0;
    while (llabs(local) + 1 > INT64_MAX/DUFFS) local /= 2, overflowbits++; // make sure we won't overflow an int64_t
    min = llabs(local)*DUFFS/price + 1; // minimum amount that safely matches local currency string
    max = (llabs(local) + 1)*DUFFS/price - 1; // maximum amount that safely matches local currency string
    amount = (min + max)/2; // average min and max
    while (overflowbits > 0) local *= 2, min *= 2, max *= 2, amount *= 2, overflowbits--;
    
    if (amount >= MAX_MONEY) return (local < 0) ? -MAX_MONEY : MAX_MONEY;
    while ((amount/p)*p >= min && p <= INT64_MAX/10) p *= 10; // lowest decimal precision matching local currency string
    p /= 10;
    return (local < 0) ? -(amount/p)*p : (amount/p)*p;
}


- (int64_t)amountForBitcoinCurrencyString:(NSString *)string
{
    if (self.bitcoinAxePrice.doubleValue <= DBL_EPSILON) return 0;
    if ([string hasPrefix:@"<"]) string = [string substringFromIndex:1];
    
    double price = self.bitcoinAxePrice.doubleValue*pow(10.0, self.bitcoinFormat.maximumFractionDigits),
    amt = [[self.bitcoinFormat numberFromString:string] doubleValue]*
    pow(10.0, self.bitcoinFormat.maximumFractionDigits);
    int64_t local = amt + DBL_EPSILON*amt, overflowbits = 0;
    
    if (local == 0) return 0;
    while (llabs(local) + 1 > INT64_MAX/DUFFS) local /= 2, overflowbits++; // make sure we won't overflow an int64_t
    int64_t min = llabs(local)*DUFFS/(int64_t)(price + DBL_EPSILON*price) + 1,
    max = (llabs(local) + 1)*DUFFS/(int64_t)(price + DBL_EPSILON*price) - 1,
    amount = (min + max)/2, p = 10;
    
    while (overflowbits > 0) local *= 2, min *= 2, max *= 2, amount *= 2, overflowbits--;
    
    if (amount >= MAX_MONEY) return (local < 0) ? -MAX_MONEY : MAX_MONEY;
    while ((amount/p)*p >= min && p <= INT64_MAX/10) p *= 10; // lowest decimal precision matching local currency string
    p /= 10;
    return (local < 0) ? -(amount/p)*p : (amount/p)*p;
}

-(NSString *)bitcoinCurrencyStringForAmount:(int64_t)amount
{
    if (amount == 0) return [self.bitcoinFormat stringFromNumber:@(0)];
    
    
    NSDecimalNumber *n = [[[NSDecimalNumber decimalNumberWithDecimal:self.bitcoinAxePrice.decimalValue]
                           decimalNumberByMultiplyingBy:(id)[NSDecimalNumber numberWithLongLong:llabs(amount)]]
                          decimalNumberByDividingBy:(id)[NSDecimalNumber numberWithLongLong:DUFFS]],
    *min = [[NSDecimalNumber one]
            decimalNumberByMultiplyingByPowerOf10:-self.bitcoinFormat.maximumFractionDigits];
    
    // if the amount is too small to be represented in local currency (but is != 0) then return a string like "$0.01"
    if ([n compare:min] == NSOrderedAscending) n = min;
    if (amount < 0) n = [n decimalNumberByMultiplyingBy:(id)[NSDecimalNumber numberWithInt:-1]];
    return [self.bitcoinFormat stringFromNumber:n];
}

- (NSString *)localCurrencyStringForAxeAmount:(int64_t)amount
{
    NSNumber *n = [self localCurrencyNumberForAxeAmount:amount];
    if (!n) {
        return NSLocalizedString(@"Updating Price",@"Updating Price");
    }
    return [self.localFormat stringFromNumber:n];
}

- (NSString *)localCurrencyStringForBitcoinAmount:(int64_t)amount
{
    if (amount == 0) return [self.localFormat stringFromNumber:@(0)];
    if (self.localCurrencyBitcoinPrice.doubleValue <= DBL_EPSILON) return @""; // no exchange rate data
    
    NSDecimalNumber *n = [[[NSDecimalNumber decimalNumberWithDecimal:self.localCurrencyBitcoinPrice.decimalValue]
                           decimalNumberByMultiplyingBy:(id)[NSDecimalNumber numberWithLongLong:llabs(amount)]]
                          decimalNumberByDividingBy:(id)[NSDecimalNumber numberWithLongLong:DUFFS]],
    *min = [[NSDecimalNumber one]
            decimalNumberByMultiplyingByPowerOf10:-self.localFormat.maximumFractionDigits];
    
    // if the amount is too small to be represented in local currency (but is != 0) then return a string like "$0.01"
    if ([n compare:min] == NSOrderedAscending) n = min;
    if (amount < 0) n = [n decimalNumberByMultiplyingBy:(id)[NSDecimalNumber numberWithInt:-1]];
    return [self.localFormat stringFromNumber:n];
}

- (NSNumber * _Nullable)localCurrencyNumberForAxeAmount:(int64_t)amount {
    if (amount == 0) {
        return @0;
    }
    
    if (!self.localCurrencyBitcoinPrice || !self.bitcoinAxePrice) {
        return nil;
    }
    
    NSNumber *local = [NSNumber numberWithDouble:self.localCurrencyBitcoinPrice.doubleValue*self.bitcoinAxePrice.doubleValue];
    
    NSDecimalNumber *n = [[[NSDecimalNumber decimalNumberWithDecimal:local.decimalValue]
                           decimalNumberByMultiplyingBy:(id)[NSDecimalNumber numberWithLongLong:llabs(amount)]]
                          decimalNumberByDividingBy:(id)[NSDecimalNumber numberWithLongLong:DUFFS]],
    *min = [[NSDecimalNumber one]
            decimalNumberByMultiplyingByPowerOf10:-self.localFormat.maximumFractionDigits];
    
    // if the amount is too small to be represented in local currency (but is != 0) then return a string like "$0.01"
    if ([n compare:min] == NSOrderedAscending) n = min;
    if (amount < 0) n = [n decimalNumberByMultiplyingBy:(id)[NSDecimalNumber numberWithInt:-1]];
    return n;
}

@end
