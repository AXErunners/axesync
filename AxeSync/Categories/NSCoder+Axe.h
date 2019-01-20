//
//  NSCoder+Axe.h
//  AxeSync
//
//  Created by Sam Westrich on 5/19/18.
//

#import <Foundation/Foundation.h>
#import "BigIntTypes.h"

@interface NSCoder (Axe)

-(void)encodeUInt256:(UInt256)value forKey:(NSString*)string;
-(UInt256)decodeUInt256ForKey:(NSString*)string;

@end
