//
//  DSaxepayUserEntity+CoreDataClass.h
//  Copyright © 2019 Axe Core Group. All rights reserved.
//
//  Licensed under the MIT License (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//  https://opensource.org/licenses/MIT
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>
#import "BigIntTypes.h"
#import "DSPotentialOneWayFriendship.h"

typedef NS_ENUM(NSUInteger, DSAxepayUserEntityFriendActivityType) {
    DSAxepayUserEntityFriendActivityType_IncomingTransactions,
    DSAxepayUserEntityFriendActivityType_OutgoingTransactions
};

@class DSAccountEntity, DSFriendRequestEntity, DSTransitionEntity, DSBlockchainIdentity,DSPotentialOneWayFriendship,DSWallet,DSIncomingFundsDerivationPath,DSChainEntity, DSBlockchainIdentityEntity, DPDocument;

NS_ASSUME_NONNULL_BEGIN

@interface DSAxepayUserEntity : NSManagedObject

@property (nonatomic,readonly) NSString * username;

+(void)deleteContactsOnChainEntity:(DSChainEntity*)chainEntity;

//-(DPDocument*)profileDocument;

//-(DPDocument*)contactRequestDocument;

-(NSArray<DSAxepayUserEntity*>*)mostActiveFriends:(DSAxepayUserEntityFriendActivityType)activityType count:(NSUInteger)count ascending:(BOOL)ascending;

-(NSDictionary<NSData*,NSNumber*>*)friendsWithActivityForType:(DSAxepayUserEntityFriendActivityType)activityType count:(NSUInteger)count ascending:(BOOL)ascending;

@end

NS_ASSUME_NONNULL_END

#import "DSAxepayUserEntity+CoreDataProperties.h"
