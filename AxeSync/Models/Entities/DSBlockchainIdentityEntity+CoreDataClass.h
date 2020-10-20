//
//  DSBlockchainIdentityEntity+CoreDataClass.h
//  AxeSync
//
//  Created by Sam Westrich on 12/31/19.
//
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

@class DSBlockchainIdentityKeyPathEntity, DSChainEntity, DSAxepayUserEntity, DSCreditFundingTransactionEntity, DSTransitionEntity, DSBlockchainIdentityUsernameEntity, DSBlockchainIdentity;

NS_ASSUME_NONNULL_BEGIN

@interface DSBlockchainIdentityEntity : NSManagedObject

-(DSBlockchainIdentity*)blockchainIdentity;

+(void)deleteBlockchainIdentitiesOnChainEntity:(DSChainEntity*)chainEntity;

@end

NS_ASSUME_NONNULL_END

#import "DSBlockchainIdentityEntity+CoreDataProperties.h"
