//
//  NSCoder+Axe.m
//  AxeSync
//
//  Created by Sam Westrich on 5/19/18.
//

#import "NSCoder+Axe.h"
#import "BigIntTypes.h"
#import "NSData+Bitcoin.h"

@implementation NSCoder (Axe)

-(void)encodeUInt256:(UInt256)value forKey:(NSString*)string {
    [self encodeObject:[NSData dataWithUInt256:value] forKey:string];
}

-(UInt256)decodeUInt256ForKey:(NSString*)string {
    NSData * data = [self decodeObjectOfClass:[NSData class] forKey:string];
    UInt256 r = *(UInt256 *)data.bytes;
    return r;
}

@end
