//
//  DSPriceManager.m
//  AxeSync
//
//  Created by Aaron Voisine for BreadWallet on 3/2/14.
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
#import "DSChainsManager.h"
#import "DSAccount.h"
#import "DSECDSAKey.h"
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

#import "DSOperationQueue.h"
#import "DSOperation.h"
#import "DSPriceOperationProvider.h"
#import "DSCurrencyPriceObject.h"

#import "NSString+Axe.h"
#import "DSReachabilityManager.h"
#import "DSPeerManager.h"
#import "DSDerivationPath.h"
#import "DSAuthenticationManager.h"
#import "NSData+Bitcoin.h"
#import "NSDate+Utils.h"

#define TICKER_REFRESH_TIME 60.0

#define DEFAULT_CURRENCY_CODE @"USD"
#define DEFAULT_SPENT_LIMIT   HAKS

#define LOCAL_CURRENCY_CODE_KEY @"LOCAL_CURRENCY_CODE"

#define PRICESBYCODE_KEY @"DS_PRICEMANAGER_PRICESBYCODE"

#define USER_ACCOUNT_KEY    @"https://api.axewallet.com"


@interface DSPriceManager()

@property (nonatomic, strong) DSOperationQueue *operationQueue;
@property (nonatomic, strong) DSReachabilityManager *reachability;

@property (nonatomic, strong) NSNumber * _Nullable bitcoinAxePrice; // exchange rate in bitcoin per axe
@property (nonatomic, strong) NSNumber * _Nullable localCurrencyBitcoinPrice; // exchange rate in local currency units per bitcoin
@property (nonatomic, strong) NSNumber * _Nullable localCurrencyAxePrice;

@property (copy, nonatomic) NSArray <DSCurrencyPriceObject *> *prices;
@property (copy, nonatomic) NSDictionary <NSString *, DSCurrencyPriceObject *> *pricesByCode;

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
    
    self.operationQueue = [[DSOperationQueue alloc] init];
    
    [NSManagedObject setConcurrencyType:NSPrivateQueueConcurrencyType];
    self.reachability = [DSReachabilityManager sharedManager];
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
    
    NSString *bundlePath = [[NSBundle bundleForClass:self.class] pathForResource:@"AxeSync" ofType:@"bundle"];
    NSBundle *bundle = [NSBundle bundleWithPath:bundlePath];
    NSString *path = [bundle pathForResource:@"CurrenciesByCode" ofType:@"plist"];
    _currenciesByCode = [NSDictionary dictionaryWithContentsOfFile:path];
    
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    
    
    NSMutableDictionary <NSString *, NSNumber *> *plainPricesByCode = [defaults objectForKey:PRICESBYCODE_KEY];
    if (plainPricesByCode) {
        NSMutableDictionary<NSString *, DSCurrencyPriceObject *> *pricesByCode = [NSMutableDictionary dictionary];
        NSMutableArray<DSCurrencyPriceObject *> *prices = [NSMutableArray array];
        for (NSString *code in plainPricesByCode) {
            NSNumber *price = plainPricesByCode[code];
            NSString *name = _currenciesByCode[code];
            DSCurrencyPriceObject *priceObject = [[DSCurrencyPriceObject alloc] initWithCode:code
                                                                                        name:name
                                                                                       price:price];
            if (priceObject) {
                pricesByCode[code] = priceObject;
                [prices addObject:priceObject];
            }
        }
        
        _prices = [[self.class sortPrices:prices usingDictionary:pricesByCode] copy];
        _pricesByCode = [pricesByCode copy];
    }
    
    NSString * potentialLocalCurrencyCode = [defaults stringForKey:LOCAL_CURRENCY_CODE_KEY];
    
    self.localCurrencyCode = (potentialLocalCurrencyCode) ? potentialLocalCurrencyCode : [[NSLocale currentLocale] objectForKey:NSLocaleCurrencyCode];
    
    return self;
}

- (void)dealloc
{
    [NSObject cancelPreviousPerformRequestsWithTarget:self];
}

-(void)startExchangeRateFetching {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self updatePrices];
    });
}

// MARK: - exchange rate

// local currency ISO code
- (void)setLocalCurrencyCode:(NSString *)code
{
    NSUserDefaults *defs = [NSUserDefaults standardUserDefaults];


    _localCurrencyCode = [code copy];

    if ([self.pricesByCode objectForKey:code] && [DSAuthenticationManager sharedInstance].secureTime + 3*DAY_TIME_INTERVAL > [NSDate timeIntervalSince1970]) {
        DSCurrencyPriceObject * priceObject = self.pricesByCode[code];
        self.localCurrencyAxePrice = priceObject.price; // don't use exchange rate data more than 72hrs out of date
    }
    else {
        self.localCurrencyAxePrice = @(0);
    }
    
    self.localFormat.currencyCode = _localCurrencyCode;
    self.localFormat.maximum =
    [[NSDecimalNumber decimalNumberWithDecimal:self.localCurrencyAxePrice.decimalValue]
     decimalNumberByMultiplyingBy:(id)[NSDecimalNumber numberWithLongLong:MAX_MONEY/HAKS]];
    
    if ([self.localCurrencyCode isEqual:[[NSLocale currentLocale] objectForKey:NSLocaleCurrencyCode]]) {
        [defs removeObjectForKey:LOCAL_CURRENCY_CODE_KEY];
    }
    else {
        [defs setObject:self.localCurrencyCode forKey:LOCAL_CURRENCY_CODE_KEY];
    }
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:DSWalletBalanceDidChangeNotification object:nil];
    });
}

-(NSNumber*)bitcoinAxePrice {
    NSAssert(NO, @"Deprecated and must not be used");
    return @(0);
}

- (void)updatePrices {
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(updatePrices) object:nil];
    [self performSelector:@selector(updatePrices) withObject:nil afterDelay:TICKER_REFRESH_TIME];
    
    __weak typeof(self) weakSelf = self;
    DSOperation *priceOperation = [DSPriceOperationProvider fetchPrices:^(NSArray<DSCurrencyPriceObject *> * _Nullable prices) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) {
            return;
        }
        
        if (prices) {
            NSMutableDictionary <NSString *, DSCurrencyPriceObject *> *pricesByCode = [NSMutableDictionary dictionary];
            NSMutableDictionary <NSString *, NSNumber *> *plainPricesByCode = [NSMutableDictionary dictionary];
            for (DSCurrencyPriceObject *priceObject in prices) {
                pricesByCode[priceObject.code] = priceObject;
                plainPricesByCode[priceObject.code] = priceObject.price;
            }
            
            [[NSUserDefaults standardUserDefaults] setObject:plainPricesByCode forKey:PRICESBYCODE_KEY];
            
            strongSelf.prices = [strongSelf.class sortPrices:prices usingDictionary:pricesByCode];
            strongSelf.pricesByCode = pricesByCode;
            strongSelf.localCurrencyCode = strongSelf->_localCurrencyCode; // update localCurrencyPrice and localFormat.maximum
        }
    }];
    [self.operationQueue addOperation:priceOperation];
}

- (DSCurrencyPriceObject *)priceForCurrencyCode:(NSString *)code {
    NSParameterAssert(code);
    if (!code) {
        return nil;
    }
    return self.pricesByCode[code];
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
    while (llabs(local) + 1 > INT64_MAX/HAKS) local /= 2, overflowbits++; // make sure we won't overflow an int64_t
    min = llabs(local)*HAKS/price + 1; // minimum amount that safely matches local currency string
    max = (llabs(local) + 1)*HAKS/price - 1; // maximum amount that safely matches local currency string
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
    while (llabs(local) + 1 > INT64_MAX/HAKS) local /= 2, overflowbits++; // make sure we won't overflow an int64_t
    int64_t min = llabs(local)*HAKS/(int64_t)(price + DBL_EPSILON*price) + 1,
    max = (llabs(local) + 1)*HAKS/(int64_t)(price + DBL_EPSILON*price) - 1,
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
                          decimalNumberByDividingBy:(id)[NSDecimalNumber numberWithLongLong:HAKS]],
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
    if (n == nil) {
        return DSLocalizedString(@"Updating Price",@"Updating Price");
    }
    return [self.localFormat stringFromNumber:n];
}

- (NSString *)localCurrencyStringForBitcoinAmount:(int64_t)amount
{
    if (amount == 0) return [self.localFormat stringFromNumber:@(0)];
    if (self.localCurrencyBitcoinPrice.doubleValue <= DBL_EPSILON) return @""; // no exchange rate data
    
    NSDecimalNumber *n = [[[NSDecimalNumber decimalNumberWithDecimal:self.localCurrencyBitcoinPrice.decimalValue]
                           decimalNumberByMultiplyingBy:(id)[NSDecimalNumber numberWithLongLong:llabs(amount)]]
                          decimalNumberByDividingBy:(id)[NSDecimalNumber numberWithLongLong:HAKS]],
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
    
    if (self.localCurrencyAxePrice == nil) {
        return nil;
    }
    
    NSNumber *local = self.localCurrencyAxePrice;
    
    NSDecimalNumber *n = [[[NSDecimalNumber decimalNumberWithDecimal:local.decimalValue]
                           decimalNumberByMultiplyingBy:(id)[NSDecimalNumber numberWithLongLong:llabs(amount)]]
                          decimalNumberByDividingBy:(id)[NSDecimalNumber numberWithLongLong:HAKS]],
    *min = [[NSDecimalNumber one]
            decimalNumberByMultiplyingByPowerOf10:-self.localFormat.maximumFractionDigits];
    
    // if the amount is too small to be represented in local currency (but is != 0) then return a string like "$0.01"
    if ([n compare:min] == NSOrderedAscending) n = min;
    if (amount < 0) n = [n decimalNumberByMultiplyingBy:(id)[NSDecimalNumber numberWithInt:-1]];
    return n;
}

// MARK: - floating fees

- (void)updateFeePerKb
{
    if (self.reachability.networkReachabilityStatus == DSReachabilityStatusNotReachable) return;
    
#if (!!FEE_PER_KB_URL)
    
    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:FEE_PER_KB_URL]
                                                       cachePolicy:NSURLRequestReloadIgnoringCacheData timeoutInterval:10.0];
    
    //    DSDLog(@"%@", req.URL.absoluteString);
    
    [[[NSURLSession sharedSession] dataTaskWithRequest:req
                                     completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
                                         if (error != nil) {
                                             DSDLog(@"unable to fetch fee-per-kb: %@", error);
                                             return;
                                         }
                                         
                                         NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
                                         
                                         if (error || ! [json isKindOfClass:[NSDictionary class]] ||
                                             ! [json[@"fee_per_kb"] isKindOfClass:[NSNumber class]]) {
                                             DSDLog(@"unexpected response from %@:\n%@", req.URL.host,
                                                   [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding]);
                                             return;
                                         }
                                         
                                         uint64_t newFee = [json[@"fee_per_kb"] unsignedLongLongValue];
                                         NSUserDefaults *defs = [NSUserDefaults standardUserDefaults];
                                         
                                         if (newFee >= MIN_FEE_PER_KB && newFee <= MAX_FEE_PER_KB && newFee != [defs doubleForKey:FEE_PER_KB_KEY]) {
                                             DSDLog(@"setting new fee-per-kb %lld", newFee);
                                             [defs setDouble:newFee forKey:FEE_PER_KB_KEY]; // use setDouble since setInteger won't hold a uint64_t
                                             _wallet.feePerKb = newFee;
                                         }
                                     }] resume];
    
#else
    return;
#endif
}

+ (NSArray<DSCurrencyPriceObject *> *)sortPrices:(NSArray<DSCurrencyPriceObject *> *)prices
                                 usingDictionary:(NSMutableDictionary <NSString *, DSCurrencyPriceObject *> *)pricesByCode {
    NSSortDescriptor *sortDescriptor = [NSSortDescriptor sortDescriptorWithKey:@"code" ascending:YES];
    NSMutableArray<DSCurrencyPriceObject *> *mutablePrices = [[prices sortedArrayUsingDescriptors:@[ sortDescriptor ]] mutableCopy];
    // move USD and EUR to the top of the prices list
    DSCurrencyPriceObject *eurPriceObject = pricesByCode[@"EUR"];
    if (eurPriceObject) {
        [mutablePrices removeObject:eurPriceObject];
        [mutablePrices insertObject:eurPriceObject atIndex:0];
    }
    DSCurrencyPriceObject *usdPriceObject = pricesByCode[DEFAULT_CURRENCY_CODE];
    if (usdPriceObject) {
        [mutablePrices removeObject:usdPriceObject];
        [mutablePrices insertObject:usdPriceObject atIndex:0];
    }
    
    return [mutablePrices copy];
}

@end
