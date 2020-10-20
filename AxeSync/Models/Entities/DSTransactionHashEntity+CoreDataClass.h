//
//  DSTransactionHashEntity+CoreDataClass.h
//  AxeSync
//
//  Created by Sam Westrich on 7/23/18.
//
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

@class DSChainEntity, DSTransactionEntity;

NS_ASSUME_NONNULL_BEGIN

@interface DSTransactionHashEntity : NSManagedObject

+(NSArray*)standaloneTransactionHashEntitiesOnChainEntity:(DSChainEntity*)chainEntity;
+ (void)deleteTransactionHashesOnChainEntity:(DSChainEntity*)chainEntity;

@end

NS_ASSUME_NONNULL_END

#import "DSTransactionHashEntity+CoreDataProperties.h"
