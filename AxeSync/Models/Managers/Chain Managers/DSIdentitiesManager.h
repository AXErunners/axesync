//
//  Created by Sam Westrich
//  Copyright © 2020 Axe Core Group. All rights reserved.
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
#import "DSChain.h"

NS_ASSUME_NONNULL_BEGIN

@class DSChain, DSBlockchainIdentity, DSCreditFundingTransaction;

@protocol DSDAPINetworkServiceRequest;

typedef void (^IdentitiesCompletionBlock)(BOOL succeess, NSArray <DSBlockchainIdentity*> * _Nullable blockchainIdentities, NSArray<NSError *> * errors);
typedef void (^IdentityCompletionBlock)(BOOL succeess, DSBlockchainIdentity* _Nullable blockchainIdentity, NSError * _Nullable error);

@interface DSIdentitiesManager : NSObject <DSChainIdentitiesDelegate>

@property (nonatomic, readonly) DSChain * chain;

- (instancetype)initWithChain:(DSChain*)chain;

- (void)registerForeignBlockchainIdentity:(DSBlockchainIdentity*)blockchainIdentity;

- (DSBlockchainIdentity*)foreignBlockchainIdentityWithUniqueId:(UInt256)uniqueId;

- (DSBlockchainIdentity*)foreignBlockchainIdentityWithUniqueId:(UInt256)uniqueId createIfMissing:(BOOL)addIfMissing inContext:(NSManagedObjectContext* _Nullable)context;

- (NSArray*)unsyncedBlockchainIdentities;

- (void)syncBlockchainIdentitiesWithCompletion:(IdentitiesCompletionBlock)completion;

- (void)retrieveAllBlockchainIdentitiesChainStates;

- (void)checkCreditFundingTransactionForPossibleNewIdentity:(DSCreditFundingTransaction*)creditFundingTransaction;

- (id<DSDAPINetworkServiceRequest>)searchIdentityByAxepayUsername:(NSString*)name withCompletion:(IdentityCompletionBlock)completion;

- (id<DSDAPINetworkServiceRequest>)searchIdentityByName:(NSString*)namePrefix inDomain:(NSString*)domain withCompletion:(IdentityCompletionBlock)completion;

- (id<DSDAPINetworkServiceRequest>)searchIdentitiesByAxepayUsernamePrefix:(NSString*)namePrefix withCompletion:(IdentitiesCompletionBlock)completion;

- (id<DSDAPINetworkServiceRequest>)searchIdentitiesByAxepayUsernamePrefix:(NSString*)namePrefix offset:(uint32_t)offset limit:(uint32_t)limit withCompletion:(IdentitiesCompletionBlock)completion;

- (id<DSDAPINetworkServiceRequest>)searchIdentitiesByNamePrefix:(NSString*)namePrefix inDomain:(NSString*)domain offset:(uint32_t)offset limit:(uint32_t)limit withCompletion:(IdentitiesCompletionBlock)completion;

- (void)searchIdentitiesByDPNSRegisteredBlockchainIdentityUniqueID:(NSString*)userID withCompletion:(IdentitiesCompletionBlock)completion;

@end

NS_ASSUME_NONNULL_END
