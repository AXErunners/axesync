//
//  DSaxepayUserEntity+CoreDataClass.m
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


#import "DSAxepayUserEntity+CoreDataClass.h"
#import "DSAccount.h"
#import "DSWallet.h"
#import "DSDerivationPathFactory.h"
#import "DSFundsDerivationPath.h"
#import "DSAxePlatform.h"
#import "NSData+Bitcoin.h"
#import "DSPotentialOneWayFriendship.h"
#import "DSAccountEntity+CoreDataClass.h"
#import "DSChainEntity+CoreDataClass.h"
#import "DSChainManager.h"
#import "DSIncomingFundsDerivationPath.h"
#import "NSData+Bitcoin.h"
#import "DSDerivationPathEntity+CoreDataClass.h"
#import "DSBlockchainIdentityEntity+CoreDataClass.h"
#import "DSBlockchainIdentityUsernameEntity+CoreDataClass.h"
#import "NSManagedObject+Sugar.h"
#import "DSTxOutputEntity+CoreDataClass.h"

@implementation DSAxepayUserEntity

+(void)deleteContactsOnChainEntity:(DSChainEntity*)chainEntity {
    [chainEntity.managedObjectContext performBlockAndWait:^{
        NSArray * contactsToDelete = [self objectsInContext:chainEntity.managedObjectContext matching:@"(chain == %@)",chainEntity];
        for (DSAxepayUserEntity * contact in contactsToDelete) {
            [chainEntity.managedObjectContext deleteObject:contact];
        }
    }];
}

-(NSArray<DSAxepayUserEntity*>*)mostActiveFriends:(DSAxepayUserEntityFriendActivityType)activityType count:(NSUInteger)count ascending:(BOOL)ascending {
    NSDictionary<NSData*,NSNumber*>* friendsWithActivity = [self friendsWithActivityForType:activityType count:count ascending:ascending];
    if (!friendsWithActivity.count) return [NSArray array];
    NSArray *results = [DSAxepayUserEntity objectsInContext:self.managedObjectContext matching:@"associatedBlockchainIdentity.uniqueID IN %@",friendsWithActivity.allKeys];
    return results;
}
    

-(NSDictionary<NSData*,NSNumber*>*)friendsWithActivityForType:(DSAxepayUserEntityFriendActivityType)activityType count:(NSUInteger)count ascending:(BOOL)ascending {
    NSFetchRequest *fetchRequest = [NSFetchRequest fetchRequestWithEntityName:DSTxOutputEntity.entityName];

    NSExpression *keyPathExpression = [NSExpression expressionForKeyPath: @"n"]; // Does not really matter
    NSExpression *countExpression = [NSExpression expressionForFunction: @"count:"
                                                              arguments: [NSArray arrayWithObject:keyPathExpression]];
    NSExpressionDescription *expressionDescription = [[NSExpressionDescription alloc] init];
    [expressionDescription setName: @"count"];
    [expressionDescription setExpression: countExpression];
    [expressionDescription setExpressionResultType: NSInteger32AttributeType];
    if (activityType == DSAxepayUserEntityFriendActivityType_IncomingTransactions) {
        [fetchRequest setPropertiesToFetch:[NSArray arrayWithObjects:@"localAddress.derivationPath.friendRequest.destinationContact.associatedBlockchainIdentity.uniqueID", expressionDescription, nil]];
        [fetchRequest setPropertiesToGroupBy:[NSArray arrayWithObject:@"localAddress.derivationPath.friendRequest.destinationContact.associatedBlockchainIdentity.uniqueID"]];
        [fetchRequest setPredicate:[NSPredicate predicateWithFormat:@"localAddress.derivationPath.friendRequest != NULL && localAddress.derivationPath.friendRequest.sourceContact == %@",self]]; //first part is an optimization for left outer joins
    } else if (activityType == DSAxepayUserEntityFriendActivityType_OutgoingTransactions) {
        [fetchRequest setPropertiesToFetch:[NSArray arrayWithObjects:@"localAddress.derivationPath.friendRequest.sourceContact.associatedBlockchainIdentity.uniqueID", expressionDescription, nil]];
        [fetchRequest setPropertiesToGroupBy:[NSArray arrayWithObject:@"localAddress.derivationPath.friendRequest.sourceContact.associatedBlockchainIdentity.uniqueID"]];
        [fetchRequest setPredicate:[NSPredicate predicateWithFormat:@"localAddress.derivationPath.friendRequest != NULL && localAddress.derivationPath.friendRequest.destinationContact == %@",self]]; //first part is an optimization for left outer joins
    }
    [fetchRequest setResultType:NSDictionaryResultType];
    NSArray *results = [self.managedObjectContext executeFetchRequest:fetchRequest error:NULL];
    
    NSArray *orderedResults = [results sortedArrayUsingDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:@"count" ascending:ascending]]];
    NSMutableDictionary * rDictionary = [NSMutableDictionary dictionary];
    NSUInteger i = 0;
    for (NSDictionary * result in orderedResults) {
        if (activityType == DSAxepayUserEntityFriendActivityType_IncomingTransactions) {
            [rDictionary setObject:result[@"count"] forKey:result[@"localAddress.derivationPath.friendRequest.destinationContact.associatedBlockchainIdentity.uniqueID"]];
        } else if (activityType == DSAxepayUserEntityFriendActivityType_OutgoingTransactions) {
            [rDictionary setObject:result[@"count"] forKey:result[@"localAddress.derivationPath.friendRequest.sourceContact.associatedBlockchainIdentity.uniqueID"]];
        }
        i++;
        if (i==count) break;
    }
    return rDictionary;
}

-(NSString*)username {
    //todo manage when more than 1 username
    DSBlockchainIdentityUsernameEntity * username = self.associatedBlockchainIdentity.axepayUsername?self.associatedBlockchainIdentity.axepayUsername:[self.associatedBlockchainIdentity.usernames anyObject];
    return username.stringValue;
}

@end
