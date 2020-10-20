//
//  DSaxepayUserEntity+CoreDataProperties.h
//  AxeSync
//
//  Created by Sam Westrich on 3/24/19.
//
//

#import "DSAxepayUserEntity+CoreDataClass.h"


NS_ASSUME_NONNULL_BEGIN

@interface DSAxepayUserEntity (CoreDataProperties)

+ (NSFetchRequest<DSAxepayUserEntity *> *)fetchRequest;

@property (nonatomic, assign) uint32_t localProfileDocumentRevision;
@property (nonatomic, assign) uint32_t remoteProfileDocumentRevision;
@property (nonatomic, assign) uint64_t createdAt;
@property (nonatomic, assign) uint64_t updatedAt;
@property (nullable, nonatomic, copy) NSString *displayName;
@property (nullable, nonatomic, copy) NSString *avatarPath;
@property (nullable, nonatomic, copy) NSString *publicMessage;
@property (nullable, nonatomic, retain) DSBlockchainIdentityEntity *associatedBlockchainIdentity;
@property (nullable, nonatomic, retain) NSSet<DSFriendRequestEntity *> *outgoingRequests;
@property (nullable, nonatomic, retain) NSSet<DSFriendRequestEntity *> *incomingRequests;
@property (nullable, nonatomic, retain) NSSet<DSAxepayUserEntity *> *friends;
@property (nullable, nonatomic, retain) DSChainEntity *chain;
@property (nullable, nonatomic, retain) NSData *documentIdentifier;
@property (nullable, nonatomic, copy) NSString *originalEntropyString;

@end

@interface DSAxepayUserEntity (CoreDataGeneratedAccessors)


- (void)addFriendsObject:(DSAxepayUserEntity *)value;
- (void)removeFriendsObject:(DSAxepayUserEntity *)value;
- (void)addFriends:(NSSet<DSAxepayUserEntity *> *)values;
- (void)removeFriends:(NSSet<DSAxepayUserEntity *> *)values;

- (void)addOutgoingRequestsObject:(DSFriendRequestEntity *)value;
- (void)removeOutgoingRequestsObject:(DSFriendRequestEntity *)value;
- (void)addOutgoingRequests:(NSSet<DSFriendRequestEntity *> *)values;
- (void)removeOutgoingRequests:(NSSet<DSFriendRequestEntity *> *)values;

- (void)addIncomingRequestsObject:(DSFriendRequestEntity *)value;
- (void)removeIncomingRequestsObject:(DSFriendRequestEntity *)value;
- (void)addIncomingRequests:(NSSet<DSFriendRequestEntity *> *)values;
- (void)removeIncomingRequests:(NSSet<DSFriendRequestEntity *> *)values;

@end

NS_ASSUME_NONNULL_END
