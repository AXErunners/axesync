//
//  DSKey.m
//  AxeSync
//
//  Created by Sam Westrich on 2/14/19.
//

#import "DSKey.h"
#import "NSString+Axe.h"
#import "NSData+Axe.h"
#import "NSString+Bitcoin.h"
#import "NSData+Bitcoin.h"
#import "NSMutableData+Axe.h"
#import "DSChain.h"

@implementation DSKey

- (UInt160)hash160
{
    return self.publicKeyData.hash160;
}

+ (NSString *)addressWithPublicKeyData:(NSData*)data forChain:(DSChain*)chain
{
    NSParameterAssert(data);
    NSParameterAssert(chain);
    
    NSMutableData *d = [NSMutableData secureDataWithCapacity:160/8 + 1];
    uint8_t version;
    UInt160 hash160 = data.hash160;
    
    if ([chain isMainnet]) {
        version = AXE_PUBKEY_ADDRESS;
    } else {
        version = AXE_PUBKEY_ADDRESS_TEST;
    }
    
    [d appendBytes:&version length:1];
    [d appendBytes:&hash160 length:sizeof(hash160)];
    return [NSString base58checkWithData:d];
}

- (NSString *)addressForChain:(DSChain*)chain
{
    NSParameterAssert(chain);
    
    return [DSKey addressWithPublicKeyData:self.publicKeyData forChain:chain];
}

- (NSString *)privateKeyStringForChain:(DSChain*)chain {
    return nil;
}

@end
