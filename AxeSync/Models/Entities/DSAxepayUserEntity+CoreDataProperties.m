//
//  DSaxepayUserEntity+CoreDataProperties.m
//  AxeSync
//
//  Created by Sam Westrich on 3/24/19.
//
//

#import "DSAxepayUserEntity+CoreDataProperties.h"

@implementation DSAxepayUserEntity (CoreDataProperties)

+ (NSFetchRequest<DSAxepayUserEntity *> *)fetchRequest {
	return [NSFetchRequest fetchRequestWithEntityName:@"DSAxepayUserEntity"];
}

@dynamic localProfileDocumentRevision;
@dynamic remoteProfileDocumentRevision;
@dynamic displayName;
@dynamic publicMessage;
@dynamic associatedBlockchainIdentity;
@dynamic outgoingRequests;
@dynamic incomingRequests;
@dynamic friends;
@dynamic avatarPath;
@dynamic chain;
@dynamic createdAt;
@dynamic updatedAt;
@dynamic documentIdentifier;
@dynamic originalEntropyString;

@end
