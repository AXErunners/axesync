//
//  NSString+Axe.m
//  AxeSync
//
//  Created by Aaron Voisine for BreadWallet on 5/13/13.
//  Copyright (c) 2013 Aaron Voisine <voisine@gmail.com>
//  Copyright (c) 2018 Dash Core Group <contact@dash.org>
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

#import "NSString+Axe.h"
#import "NSData+Axe.h"
#import "NSMutableData+Axe.h"
#import "UIImage+DSUtils.h"
#import "DSPriceManager.h"
#import "DSChain.h"
#import "DSDerivationPath.h"
#import "DSECDSAKey.h"

@implementation NSString (Axe)

// NOTE: It's important here to be permissive with scriptSig (spends) and strict with scriptPubKey (receives). If we
// miss a receive transaction, only that transaction's funds are missed, however if we accept a receive transaction that
// we are unable to correctly sign later, then the entire wallet balance after that point would become stuck with the
// current coin selection code
+ (NSString *)addressWithScriptPubKey:(NSData *)script onChain:(DSChain*)chain
{
    if (script == (id)[NSNull null]) return nil;
    
    NSArray *elem = [script scriptElements];
    NSUInteger l = elem.count;
    NSMutableData *d = [NSMutableData data];
    uint8_t v;
    
    if ([chain isMainnet]) {
        v = AXE_PUBKEY_ADDRESS;
    } else {
        v = AXE_PUBKEY_ADDRESS_TEST;
    }
    
    if (l == 5 && [elem[0] intValue] == OP_DUP && [elem[1] intValue] == OP_HASH160 && [elem[2] intValue] == 20 &&
        [elem[3] intValue] == OP_EQUALVERIFY && [elem[4] intValue] == OP_CHECKSIG) {
        // pay-to-pubkey-hash scriptPubKey
        [d appendBytes:&v length:1];
        [d appendData:elem[2]];
    }
    else if (l == 3 && [elem[0] intValue] == OP_HASH160 && [elem[1] intValue] == 20 && [elem[2] intValue] == OP_EQUAL) {
        // pay-to-script-hash scriptPubKey
        if ([chain isMainnet]) {
            v = AXE_SCRIPT_ADDRESS;
        } else {
            v = AXE_SCRIPT_ADDRESS_TEST;
        }
        [d appendBytes:&v length:1];
        [d appendData:elem[1]];
    }
    else if (l == 2 && ([elem[0] intValue] == 65 || [elem[0] intValue] == 33) && [elem[1] intValue] == OP_CHECKSIG) {
        // pay-to-pubkey scriptPubKey
        [d appendBytes:&v length:1];
        [d appendBytes:[elem[0] hash160].u8 length:sizeof(UInt160)];
    }
    else return nil; // unknown script type
    
    return [self base58checkWithData:d];
}

+ (NSString *)addressWithScriptSig:(NSData *)script onChain:(DSChain*)chain
{
    if (script == (id)[NSNull null]) return nil;
    
    NSArray *elem = [script scriptElements];
    NSUInteger l = elem.count;
    NSMutableData *d = [NSMutableData data];
    uint8_t v;
    
    if ([chain isMainnet]) {
        v = AXE_PUBKEY_ADDRESS;
    } else {
        v = AXE_PUBKEY_ADDRESS_TEST;
    }

    
    if (l >= 2 && [elem[l - 2] intValue] <= OP_PUSHDATA4 && [elem[l - 2] intValue] > 0 &&
        ([elem[l - 1] intValue] == 65 || [elem[l - 1] intValue] == 33)) { // pay-to-pubkey-hash scriptSig
        [d appendBytes:&v length:1];
        [d appendBytes:[elem[l - 1] hash160].u8 length:sizeof(UInt160)];
    }
    else if (l >= 2 && [elem[l - 2] intValue] <= OP_PUSHDATA4 && [elem[l - 2] intValue] > 0 &&
             [elem[l - 1] intValue] <= OP_PUSHDATA4 && [elem[l - 1] intValue] > 0) { // pay-to-script-hash scriptSig
        if ([chain isMainnet]) {
            v = AXE_SCRIPT_ADDRESS;
        } else {
            v = AXE_SCRIPT_ADDRESS_TEST;
        }
        [d appendBytes:&v length:1];
        [d appendBytes:[elem[l - 1] hash160].u8 length:sizeof(UInt160)];
    }
    else if (l >= 1 && [elem[l - 1] intValue] <= OP_PUSHDATA4 && [elem[l - 1] intValue] > 0) {// pay-to-pubkey scriptSig
        [d appendBytes:&v length:1];
//        DSKey * key = [DSKey keyRecoveredFromCompactSig:elem[l - 1] andMessageDigest:transactionHash];
//        [d appendBytes:[key.publicKey hash160].u8 length:sizeof(UInt160)];
        //TODO: implement Peter Wullie's pubKey recovery from signature
        return nil;
    }
    else {
        DSDLog(@"Unknown script type");
        return nil; // unknown script type
    }
    
    return [self base58checkWithData:d];
}

- (BOOL)isValidAxeAddressOnChain:(DSChain *)chain
{
    if (self.length > 35) return NO;
    
    NSData *d = self.base58checkToData;
    
    if (d.length != 21) return NO;
    
    uint8_t version = *(const uint8_t *)d.bytes;
    if ([chain isMainnet]) {
        return (version == AXE_PUBKEY_ADDRESS || version == AXE_SCRIPT_ADDRESS) ? YES : NO;
    } else {
        return (version == AXE_PUBKEY_ADDRESS_TEST || version == AXE_SCRIPT_ADDRESS_TEST) ? YES : NO;
    }
}

- (BOOL)isValidAxeDevnetAddress {
    if (self.length > 35) return NO;
    
    NSData *d = self.base58checkToData;
    
    if (d.length != 21) return NO;
    
    uint8_t version = *(const uint8_t *)d.bytes;

    return (version == AXE_PUBKEY_ADDRESS_TEST || version == AXE_SCRIPT_ADDRESS_TEST) ? YES : NO;
}

- (BOOL)isValidAxePrivateKeyOnChain:(DSChain *)chain
{
    if (![self isValidBase58]) return FALSE;
    NSData *d = self.base58checkToData;
    
    if (d.length == 33 || d.length == 34) { // wallet import format: https://en.bitcoin.it/wiki/Wallet_import_format
        if ([chain isMainnet]) {
            return (*(const uint8_t *)d.bytes == AXE_PRIVKEY) ? YES : NO;
        } else {
            return (*(const uint8_t *)d.bytes == AXE_PRIVKEY_TEST) ? YES : NO;
        }
    }
    else return (self.hexToData.length == 32) ? YES : NO; // hex encoded key
}

- (BOOL)isValidAxeDevnetPrivateKey {
    if (![self isValidBase58]) return FALSE;
    NSData *d = self.base58checkToData;
    
    if (d.length == 33 || d.length == 34) { // wallet import format: https://en.bitcoin.it/wiki/Wallet_import_format
        return (*(const uint8_t *)d.bytes == AXE_PRIVKEY_TEST) ? YES : NO;
    }
    else return (self.hexToData.length == 32) ? YES : NO; // hex encoded key
}

- (BOOL)isValidAxeExtendedPublicKeyOnChain:(DSChain*)chain
{
    if (![self isValidBase58]) return FALSE;
    NSData * allData = self.base58ToData;
    if (allData.length != 82) return FALSE;
    NSData * data = [allData subdataWithRange:NSMakeRange(0, allData.length - 4)];
    NSData * checkData = [allData subdataWithRange:NSMakeRange(allData.length - 4, 4)];
    if ((*(uint32_t*)data.SHA256_2.u32) != *(uint32_t*)checkData.bytes) return FALSE;
    uint8_t * bytes = (uint8_t *)[data bytes];
    if (memcmp(bytes,[chain isMainnet]?BIP32_XPRV_MAINNET:BIP32_XPRV_TESTNET,4) != 0 && memcmp(bytes,[chain isMainnet]?BIP32_XPUB_MAINNET:BIP32_XPUB_TESTNET,4) != 0) {
        return FALSE;
    }
    return TRUE;
}

// BIP38 encrypted keys: https://github.com/bitcoin/bips/blob/master/bip-0038.mediawiki
- (BOOL)isValidAxeBIP38Key
{
    NSData *d = self.base58checkToData;
    
    if (d.length != 39) return NO; // invalid length
    
    uint16_t prefix = CFSwapInt16BigToHost(*(const uint16_t *)d.bytes);
    uint8_t flag = ((const uint8_t *)d.bytes)[2];
    
    if (prefix == BIP38_NOEC_PREFIX) { // non EC multiplied key
        return ((flag & BIP38_NOEC_FLAG) == BIP38_NOEC_FLAG && (flag & BIP38_LOTSEQUENCE_FLAG) == 0 &&
                (flag & BIP38_INVALID_FLAG) == 0) ? YES : NO;
    }
    else if (prefix == BIP38_EC_PREFIX) { // EC multiplied key
        return ((flag & BIP38_NOEC_FLAG) == 0 && (flag & BIP38_INVALID_FLAG) == 0) ? YES : NO;
    }
    else return NO; // invalid prefix
}

- (NSAttributedString*)attributedStringForAxeSymbol {
    return [self attributedStringForAxeSymbolWithTintColor:[UIColor blackColor]];
}

- (NSAttributedString*)attributedStringForAxeSymbolWithTintColor:(UIColor*)color {
    return [self attributedStringForAxeSymbolWithTintColor:color axeSymbolSize:CGSizeMake(12, 12)];
}

+(NSAttributedString*)axeSymbolAttributedStringWithTintColor:(UIColor*)color forAxeSymbolSize:(CGSize)axeSymbolSize {
    NSTextAttachment *axeSymbol = [[NSTextAttachment alloc] init];
    
    axeSymbol.bounds = CGRectMake(0, 0, axeSymbolSize.width, axeSymbolSize.height);
    axeSymbol.image = [[UIImage imageNamed:@"Axe-Light"] ds_imageWithTintColor:color];
    return [NSAttributedString attributedStringWithAttachment:axeSymbol];
}


- (NSAttributedString*)attributedStringForAxeSymbolWithTintColor:(UIColor*)color axeSymbolSize:(CGSize)axeSymbolSize {
    
    NSMutableAttributedString *attributedString = [[NSMutableAttributedString alloc]
                                                   initWithString:[self stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]]];
    
    NSRange range = [attributedString.string rangeOfString:AXE];
    if (range.location == NSNotFound) {
        [attributedString insertAttributedString:[[NSAttributedString alloc] initWithString:@" "] atIndex:0];
        [attributedString insertAttributedString:[NSString axeSymbolAttributedStringWithTintColor:color forAxeSymbolSize:axeSymbolSize] atIndex:0];
        
        [attributedString addAttribute:NSForegroundColorAttributeName value:color range:NSMakeRange(0, attributedString.length)];
    } else {
        [attributedString replaceCharactersInRange:range
                              withAttributedString:[NSString axeSymbolAttributedStringWithTintColor:color forAxeSymbolSize:axeSymbolSize]];
        [attributedString addAttribute:NSForegroundColorAttributeName value:color range:NSMakeRange(0, attributedString.length)];
    }
    return attributedString;
}


-(NSInteger)indexOfCharacter:(unichar)character {
    for (int i = 0;i < self.length; i++) {
        if ([self characterAtIndex:i] == character) return i;
    }
    return NSNotFound;
}

// MARK: time

+(NSString*)waitTimeFromNow:(NSTimeInterval)wait {
    NSUInteger seconds = wait;
    NSUInteger hours = seconds / 360;
    seconds %= 360;
    NSUInteger minutes = seconds /60;
    seconds %=60;
    
    NSString * hoursUnit = hours!=1?DSLocalizedString(@"hours",nil):DSLocalizedString(@"hour",nil);
    NSString * minutesUnit = minutes!=1?DSLocalizedString(@"minutes",nil):DSLocalizedString(@"minute",nil);
    NSString * secondsUnit = seconds!=1?DSLocalizedString(@"seconds",nil):DSLocalizedString(@"second",nil);
    NSMutableString * tryAgainTime = [@"" mutableCopy];
    if (hours) {
        [tryAgainTime appendString:[NSString stringWithFormat:@"%ld %@",(unsigned long)hours,hoursUnit]];
        if (minutes && seconds) {
            [tryAgainTime appendString:DSLocalizedString(@", ",nil)];
        } else if (minutes || seconds) {
            [tryAgainTime appendString:DSLocalizedString(@" and ",nil)];
        }
    }
    if (minutes) {
        [tryAgainTime appendString:[NSString stringWithFormat:@"%ld %@",(unsigned long)minutes,minutesUnit]];
        if (seconds) {
            [tryAgainTime appendString:DSLocalizedString(@" and ",nil)];
        }
    }
    if (seconds) {
        [tryAgainTime appendString:[NSString stringWithFormat:@"%ld %@",(unsigned long)seconds,secondsUnit]];
    }
    return [NSString stringWithString:tryAgainTime];
}

@end
