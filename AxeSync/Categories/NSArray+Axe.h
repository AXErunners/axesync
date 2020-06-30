//
//  NSArray+Axe.h
//  AxeSync
//
//  Created by Sam Westrich on 11/21/19.
//

#import <Foundation/Foundation.h>
#import "NSData+Bitcoin.h"
#import "BigIntTypes.h"

NS_ASSUME_NONNULL_BEGIN

@interface NSArray (Axe)

-(UInt256)hashDataComponents;
-(UInt256)hashDataComponentsWithSelector:(SEL)hashFunction;

@end

NS_ASSUME_NONNULL_END
