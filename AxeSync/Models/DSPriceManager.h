//
//  DSPriceManager.h
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

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>

#define AXE         @"AXE"     // capital D with stroke (utf-8)
#define BTC          @"\xC9\x83"     // capital B with stroke (utf-8)
#define BITS         @"\xC6\x80"     // lowercase b with stroke (utf-8)
#define DITS         @"mAXE"     // lowercase d with stroke (utf-8)
#define NARROW_NBSP  @"\xE2\x80\xAF" // narrow no-break space (utf-8)
#define LDQUOTE      @"\xE2\x80\x9C" // left double quote (utf-8)
#define RDQUOTE      @"\xE2\x80\x9D" // right double quote (utf-8)
#define DISPLAY_NAME [NSString stringWithFormat:LDQUOTE @"%@" RDQUOTE,\
                      NSBundle.mainBundle.infoDictionary[@"CFBundleDisplayName"]]

typedef void (^ResetCancelHandlerBlock)(void);

@interface DSPriceManager : NSObject

@property (nonatomic, assign) uint64_t spendingLimit; // amount that can be spent using touch id without pin entry
@property (nonatomic, readonly) NSNumberFormatter * _Nullable axeFormat; // axe currency formatter
@property (nonatomic, readonly) NSNumberFormatter * _Nullable axeSignificantFormat; // axe currency formatter that shows significant digits
@property (nonatomic, readonly) NSNumberFormatter * _Nullable bitcoinFormat; // bitcoin currency formatter
@property (nonatomic, readonly) NSNumberFormatter * _Nullable unknownFormat; // unknown currency formatter
@property (nonatomic, readonly) NSNumberFormatter * _Nullable localFormat; // local currency formatter
@property (nonatomic, copy) NSString * _Nullable localCurrencyCode; // local currency ISO code
@property (nonatomic, readonly) NSNumber * _Nullable bitcoinAxePrice; // exchange rate in bitcoin per axe
@property (nonatomic, readonly) NSNumber * _Nullable localCurrencyBitcoinPrice; // exchange rate in local currency units per bitcoin
@property (nonatomic, readonly) NSNumber * _Nullable localCurrencyAxePrice;
@property (nonatomic, readonly) NSArray * _Nullable currencyCodes; // list of supported local currency codes
@property (nonatomic, readonly) NSArray * _Nullable currencyNames; // names for local currency codes

+ (instancetype _Nullable)sharedInstance;

- (void)startExchangeRateFetching;

- (int64_t)amountForUnknownCurrencyString:(NSString * _Nullable)string;
- (int64_t)amountForAxeString:(NSString * _Nullable)string;
- (int64_t)amountForBitcoinString:(NSString * _Nullable)string;
- (NSAttributedString * _Nonnull)attributedStringForAxeAmount:(int64_t)amount;
- (NSAttributedString * _Nonnull)attributedStringForAxeAmount:(int64_t)amount withTintColor:(UIColor* _Nonnull)color;
- (NSAttributedString * _Nonnull)attributedStringForAxeAmount:(int64_t)amount withTintColor:(UIColor* _Nonnull)color useSignificantDigits:(BOOL)useSignificantDigits;
- (NSAttributedString * _Nonnull)attributedStringForAxeAmount:(int64_t)amount withTintColor:(UIColor* _Nonnull)color axeSymbolSize:(CGSize)axeSymbolSize;
- (NSNumber * _Nonnull)numberForAmount:(int64_t)amount;
- (NSString * _Nonnull)stringForBitcoinAmount:(int64_t)amount;
- (NSString * _Nonnull)stringForAxeAmount:(int64_t)amount;
- (int64_t)amountForBitcoinCurrencyString:(NSString * _Nonnull)string;
- (int64_t)amountForLocalCurrencyString:(NSString * _Nonnull)string;
- (NSString * _Nonnull)bitcoinCurrencyStringForAmount:(int64_t)amount;
- (NSString * _Nonnull)localCurrencyStringForAxeAmount:(int64_t)amount;
- (NSString * _Nonnull)localCurrencyStringForBitcoinAmount:(int64_t)amount;
- (NSNumber * _Nullable)localCurrencyNumberForAxeAmount:(int64_t)amount;
- (NSNumber* _Nonnull)localCurrencyAxePrice;

@end
