//  
//  Created by Sam Westrich
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

#import "DSPotentialOneWayFriendship.h"
#import "DSAccount.h"
#import "DSWallet.h"
#import "DSDerivationPathFactory.h"
#import "DSFundsDerivationPath.h"
#import "DSAxePlatform.h"
#import "DSFriendRequestEntity+CoreDataClass.h"
#import "DSAxepayUserEntity+CoreDataClass.h"
#import "NSManagedObject+Sugar.h"
#import "DSBLSKey.h"
#import "DSIncomingFundsDerivationPath.h"
#import "DSDerivationPathEntity+CoreDataClass.h"
#import "DSPotentialContact.h"
#import "NSData+Encryption.h"
#import "DSKey.h"
#import "DSBlockchainIdentity+Protected.h"
#import "DSBlockchainIdentityEntity+CoreDataClass.h"

@interface DSPotentialOneWayFriendship()

@property (nonatomic, strong) DSAccount* account;
@property (nonatomic, strong) DSBlockchainIdentity * sourceBlockchainIdentity;
@property (nonatomic, strong) DSBlockchainIdentity * destinationBlockchainIdentity;
@property (nonatomic, strong) DSPotentialContact * destinationContact;
@property (nonatomic, strong) DSIncomingFundsDerivationPath * fundsDerivationPathForContact;
@property (nonatomic, strong) DSKey * extendedPublicKey;
@property (nonatomic, strong) NSData * encryptedExtendedPublicKeyData;
@property (nonatomic, assign) uint32_t sourceKeyIndex;
@property (nonatomic, assign) uint32_t destinationKeyIndex;
@property (nonatomic, assign) NSTimeInterval createdAt;

@end

@implementation DSPotentialOneWayFriendship

-(instancetype)initWithDestinationBlockchainIdentity:(DSBlockchainIdentity*)destinationBlockchainIdentity destinationKeyIndex:(uint32_t)destinationKeyIndex sourceBlockchainIdentity:(DSBlockchainIdentity*)sourceBlockchainIdentity sourceKeyIndex:(uint32_t)sourceKeyIndex account:(DSAccount*)account {
    return [self initWithDestinationBlockchainIdentity:destinationBlockchainIdentity destinationKeyIndex:destinationKeyIndex sourceBlockchainIdentity:sourceBlockchainIdentity sourceKeyIndex:sourceKeyIndex account:account createdAt:[[NSDate date] timeIntervalSince1970]];
}

-(instancetype)initWithDestinationBlockchainIdentity:(DSBlockchainIdentity*)destinationBlockchainIdentity destinationKeyIndex:(uint32_t)destinationKeyIndex sourceBlockchainIdentity:(DSBlockchainIdentity*)sourceBlockchainIdentity sourceKeyIndex:(uint32_t)sourceKeyIndex account:(DSAccount*)account createdAt:(NSTimeInterval)createdAt {
    if (!(self = [super init])) return nil;
    self.destinationBlockchainIdentity = destinationBlockchainIdentity;
    self.account = account;
    self.sourceBlockchainIdentity = sourceBlockchainIdentity;
    self.sourceKeyIndex = sourceKeyIndex;
    self.destinationKeyIndex = destinationKeyIndex;
    self.createdAt = createdAt;
    
    return self;
}

-(UInt256)destinationBlockchainIdentityUniqueId {
    if (self.destinationBlockchainIdentity) {
        return self.destinationBlockchainIdentity.uniqueID;
    } else if (self.destinationContact) {
        return self.destinationContact.associatedBlockchainIdentityUniqueId;
    }
    return UINT256_ZERO;
}

-(DSKey*)sourceKeyAtIndex {
    NSAssert(self.sourceBlockchainIdentity != nil, @"The source identity should be present");
    return [self.sourceBlockchainIdentity keyAtIndex:self.sourceKeyIndex];
}

-(DSKey*)destinationKeyAtIndex {
    if (self.destinationBlockchainIdentity) {
        return [self.destinationBlockchainIdentity keyAtIndex:self.destinationKeyIndex];
    } else if (self.destinationContact) {
        return [self.destinationContact publicKeyAtIndex:self.destinationKeyIndex];
    }
    return nil;
}

-(void)createDerivationPathWithCompletion:(void (^)(BOOL success, DSIncomingFundsDerivationPath * incomingFundsDerivationPath))completion {
    NSAssert(!uint256_is_zero([self destinationBlockchainIdentityUniqueId]), @"destinationBlockchainIdentityUniqueId must not be null");
    self.fundsDerivationPathForContact = [DSIncomingFundsDerivationPath
                                          contactBasedDerivationPathWithDestinationBlockchainIdentityUniqueId:[self destinationBlockchainIdentityUniqueId] sourceBlockchainIdentityUniqueId:self.sourceBlockchainIdentity.uniqueID forAccountNumber:self.account.accountNumber onChain:self.sourceBlockchainIdentity.wallet.chain];
    self.fundsDerivationPathForContact.account = self.account;
    DSDerivationPath * masterContactsDerivationPath = [self.account masterContactsDerivationPath];
    
    self.extendedPublicKey = [self.fundsDerivationPathForContact generateExtendedPublicKeyFromParentDerivationPath:masterContactsDerivationPath storeUnderWalletUniqueId:nil];
    if (completion) {
        completion(YES,self.fundsDerivationPathForContact);
    }
}

-(void)encryptExtendedPublicKeyWithCompletion:(void (^)(BOOL success))completion {
    NSAssert(self.extendedPublicKey, @"Problem creating extended public key for potential contact?");
     __weak typeof(self) weakSelf = self;
     DSKey * recipientKey = [self destinationKeyAtIndex];
    [self.sourceBlockchainIdentity encryptData:self.extendedPublicKey.extendedPublicKeyData withKeyAtIndex:self.sourceKeyIndex forRecipientKey:recipientKey completion:^(NSData * _Nonnull encryptedData) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) {
            if (completion) {
                completion(NO);
            }
            return;
        }
        strongSelf.encryptedExtendedPublicKeyData = encryptedData;
        if (completion) {
            completion(YES);
        }
    }];
}

-(uint32_t)createAccountReference {
    DSKey * key = [self sourceKeyAtIndex];
    
    UInt256 accountSecretKey = uint256_reverse([key HMAC256Data:self.extendedPublicKey.extendedPublicKeyData]);
    
    uint32_t accountSecretKey28 = accountSecretKey.u32[0] >> 4;
    uint32_t shortenedAccountBits = self.account.accountNumber & 0x00FFFFFF;
    uint32_t version = 0; //currently set to 0
    uint32_t versionBits = version << 28;
    uint32_t accountRef = versionBits | (accountSecretKey28 ^ shortenedAccountBits);

    return accountRef;
}

-(DPDocument*)contactRequestDocumentWithEntropy:(NSString*)entropyString {
    NSAssert(!uint256_is_zero([self destinationBlockchainIdentityUniqueId]), @"the destination contact's associatedBlockchainIdentityUniqueId must be set before making a friend request");
    NSAssert([self.encryptedExtendedPublicKeyData length] > 0, @"The encrypted extended public key must exist");
    NSAssert(self.extendedPublicKey, @"Problem creating extended public key for potential contact?");
    NSError *error = nil;
    
    uint64_t createAtMs = (self.createdAt)*1000;
    DSStringValueDictionary *data = @{
        @"$createdAt": @(createAtMs),
        @"toUserId" : uint256_data([self destinationBlockchainIdentityUniqueId]),
        @"encryptedPublicKey" : self.encryptedExtendedPublicKeyData,
        @"senderKeyIndex" : @(self.sourceKeyIndex),
        @"recipientKeyIndex" : @(self.destinationKeyIndex),
        @"accountReference": @([self createAccountReference])
    };
    
    
    DPDocument *contact = [self.sourceBlockchainIdentity.axepayDocumentFactory documentOnTable:@"contactRequest" withDataDictionary:data usingEntropy:entropyString error:&error];
    NSAssert(error == nil, @"Failed to build a contact");
    return contact;
}

-(DSDerivationPathEntity*)storeExtendedPublicKeyAssociatedWithFriendRequest:(DSFriendRequestEntity*)friendRequestEntity {
    [self.fundsDerivationPathForContact storeExtendedPublicKeyUnderWalletUniqueId:self.account.wallet.uniqueIDString];
    __block DSDerivationPathEntity* fundsDerivationPathEntity = nil;
    
    [friendRequestEntity.managedObjectContext performBlockAndWait:^{
        fundsDerivationPathEntity = [DSDerivationPathEntity derivationPathEntityMatchingDerivationPath:self.fundsDerivationPathForContact associateWithFriendRequest:friendRequestEntity];
    }];
    return fundsDerivationPathEntity;
}


-(DSFriendRequestEntity*)outgoingFriendRequestForAxepayUserEntity:(DSAxepayUserEntity*)axepayUserEntity atTimestamp:(NSTimeInterval)timestamp {
    NSParameterAssert(axepayUserEntity);
    NSAssert(uint256_eq(axepayUserEntity.associatedBlockchainIdentity.uniqueID.UInt256, [self destinationBlockchainIdentityUniqueId]), @"contact entity must match");
    NSAssert(self.sourceBlockchainIdentity.matchingAxepayUserInViewContext,@"The own contact of the source Identity must be set");
    DSFriendRequestEntity * friendRequestEntity = [DSFriendRequestEntity managedObjectInBlockedContext:axepayUserEntity.managedObjectContext];
    friendRequestEntity.sourceContact = self.sourceBlockchainIdentity.matchingAxepayUserInViewContext;
    friendRequestEntity.destinationContact = axepayUserEntity;
    NSAssert(friendRequestEntity.sourceContact != friendRequestEntity.destinationContact, @"This must be different contacts");
    friendRequestEntity.derivationPath = [DSDerivationPathEntity derivationPathEntityMatchingDerivationPath:self.fundsDerivationPathForContact inContext:axepayUserEntity.managedObjectContext];
    NSAssert(friendRequestEntity.derivationPath, @"There must be a derivation path");
    friendRequestEntity.account = friendRequestEntity.derivationPath.account;
    friendRequestEntity.timestamp = timestamp;
    
    [friendRequestEntity finalizeWithFriendshipIdentifier];
    return friendRequestEntity;
}


//-(DSFriendRequestEntity*)outgoingFriendRequest {
//    NSAssert(!uint256_is_zero(self.destinationContact.associatedBlockchainIdentityUniqueId), @"destination contact must be known");
//    DSAxepayUserEntity * axepayUserEntity = [DSAxepayUserEntity anyObjectInContext:context matching:@"associatedBlockchainIdentityUniqueId == %@",uint256_data(self.destinationContact.associatedBlockchainIdentityUniqueId)];
//    if (!axepayUserEntity) {
//        axepayUserEntity =  [DSAxepayUserEntity managedObject];
//        axepayUserEntity.avatarPath = self.destinationContact.avatarPath;
//        axepayUserEntity.publicMessage = self.destinationContact.publicMessage;
//        axepayUserEntity.associatedBlockchainIdentity = uint256_data([self destinationBlockchainIdentityUniqueId]);
//        axepayUserEntity.chain = self.account.wallet.chain.chainEntity;
//    }
//    
//    return [self outgoingFriendRequestForAxepayUserEntity:axepayUserEntity];
//}

-(BOOL)isEqual:(id)object {
    if (self == object) {
        return TRUE;
    }
    
    if (![object isKindOfClass:[self class]]) {
        return FALSE;
    }
    
    if (uint256_eq(self.destinationBlockchainIdentity.uniqueID,((DSPotentialOneWayFriendship*)object).destinationBlockchainIdentity.uniqueID) && uint256_eq(self.sourceBlockchainIdentity.uniqueID,((DSPotentialOneWayFriendship*)object).sourceBlockchainIdentity.uniqueID) &&
        self.account.accountNumber == ((DSPotentialOneWayFriendship*)object).account.accountNumber) {
        return TRUE;
    }
    
    return FALSE;
}

- (NSUInteger)hash {
    return self.destinationBlockchainIdentity.hash ^ self.sourceBlockchainIdentity.hash ^ self.account.accountNumber;
}

-(NSString*)debugDescription {
    return [NSString stringWithFormat:@"%@ - s:%@ d:%@", [super debugDescription], self.sourceBlockchainIdentity.currentAxepayUsername, self.destinationBlockchainIdentity.currentAxepayUsername];
}

@end
