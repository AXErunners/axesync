//
//  NSArray+Axe.m
//  AxeSync
//
//  Created by Sam Westrich on 11/21/19.
//

#import "NSArray+Axe.h"
#import "NSMutableData+Axe.h"

@implementation NSArray (Axe)

-(UInt256)hashDataComponents {
    NSMutableData * concatenatedData = [NSMutableData data];
    for (NSData * data in self) {
        [concatenatedData appendData:data];
    }
    return [concatenatedData SHA256];
}

-(UInt256)hashDataComponentsWithSelector:(SEL)hashFunction {
    NSMutableData * concatenatedData = [NSMutableData data];
    for (NSData * data in self) {
        [concatenatedData appendData:data];
    }
    NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:
                                [NSMutableData instanceMethodSignatureForSelector:hashFunction]];
    [invocation setSelector:hashFunction];
    [invocation setTarget:concatenatedData];
    [invocation invoke];
    UInt256 returnValue = UINT256_ZERO;
    [invocation getReturnValue:&returnValue];
    return returnValue;
}

@end
