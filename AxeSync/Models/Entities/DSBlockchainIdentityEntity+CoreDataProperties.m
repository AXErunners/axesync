//
//  DSBlockchainIdentityEntity+CoreDataProperties.m
//  AxeSync
//
//  Created by Sam Westrich on 12/31/19.
//
//

#import "DSBlockchainIdentityEntity+CoreDataProperties.h"

@implementation DSBlockchainIdentityEntity (CoreDataProperties)

+ (NSFetchRequest<DSBlockchainIdentityEntity *> *)fetchRequest {
	return [NSFetchRequest fetchRequestWithEntityName:@"DSBlockchainIdentityEntity"];
}

@dynamic uniqueID;
@dynamic topUpFundingTransactions;
@dynamic registrationFundingTransaction;
@dynamic keyPaths;
@dynamic matchingAxepayUser;
@dynamic chain;
@dynamic usernames;
@dynamic creditBalance;
@dynamic registrationStatus;
@dynamic isLocal;
@dynamic axepayUsername;
@dynamic axepaySyncronizationBlockHash;
@dynamic lastCheckedUsernamesTimestamp;
@dynamic lastCheckedProfileTimestamp;
@dynamic lastCheckedIncomingContactsTimestamp;
@dynamic lastCheckedOutgoingContactsTimestamp;

@end
