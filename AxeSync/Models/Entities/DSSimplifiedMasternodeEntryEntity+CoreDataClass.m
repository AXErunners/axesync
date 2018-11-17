//
//  DSSimplifiedMasternodeEntryEntity+CoreDataClass.m
//  AxeSync
//
//  Created by Sam Westrich on 7/19/18.
//
//

#import "DSSimplifiedMasternodeEntryEntity+CoreDataClass.h"
#import "DSSimplifiedMasternodeEntry.h"
#import "DSChain.h"
#import "DSChainEntity+CoreDataProperties.h"
#import "NSData+Bitcoin.h"
#import "NSManagedObject+Sugar.h"

@implementation DSSimplifiedMasternodeEntryEntity

- (void)updateAttributesFromSimplifiedMasternodeEntry:(DSSimplifiedMasternodeEntry *)simplifiedMasternodeEntry {
    self.address = CFSwapInt32BigToHost(simplifiedMasternodeEntry.address.u32[3]);
    self.port = simplifiedMasternodeEntry.port;
    self.keyIDVoting = [NSData dataWithUInt160:simplifiedMasternodeEntry.keyIDVoting];
    self.operatorBLSPublicKey = [NSData dataWithUInt384:simplifiedMasternodeEntry.operatorBLSPublicKey];
    self.isValid = simplifiedMasternodeEntry.isValid;
    self.simplifiedMasternodeEntryHash = [NSData dataWithUInt256:simplifiedMasternodeEntry.simplifiedMasternodeEntryHash];
}

- (void)setAttributesFromSimplifiedMasternodeEntry:(DSSimplifiedMasternodeEntry *)simplifiedMasternodeEntry onChain:(DSChainEntity*)chainEntity {
    self.providerRegistrationTransactionHash = [NSData dataWithUInt256:simplifiedMasternodeEntry.providerRegistrationTransactionHash];
    self.confirmedHash = [NSData dataWithUInt256:simplifiedMasternodeEntry.confirmedHash];
    self.address = CFSwapInt32BigToHost(simplifiedMasternodeEntry.address.u32[3]);
    self.port = simplifiedMasternodeEntry.port;
    self.keyIDVoting = [NSData dataWithUInt160:simplifiedMasternodeEntry.keyIDVoting];
    self.operatorBLSPublicKey = [NSData dataWithUInt384:simplifiedMasternodeEntry.operatorBLSPublicKey];
    self.isValid = simplifiedMasternodeEntry.isValid;
    self.simplifiedMasternodeEntryHash = [NSData dataWithUInt256:simplifiedMasternodeEntry.simplifiedMasternodeEntryHash];
    if (!chainEntity) {
        self.chain = simplifiedMasternodeEntry.chain.chainEntity;
    } else {
        self.chain = chainEntity;
    }
}

+ (void)deleteHavingProviderTransactionHashes:(NSArray*)providerTransactionHashes onChain:(DSChainEntity*)chainEntity {
    NSArray * hashesToDelete = [self objectsMatching:@"(chain == %@) && (providerTransactionHash IN %@)",chainEntity,providerTransactionHashes];
    for (DSSimplifiedMasternodeEntryEntity * simplifiedMasternodeEntryEntity in hashesToDelete) {
        [chainEntity.managedObjectContext deleteObject:simplifiedMasternodeEntryEntity];
    }
}

+ (void)deleteAllOnChain:(DSChainEntity*)chainEntity {
        NSArray * hashesToDelete = [self objectsMatching:@"(chain == %@)",chainEntity];
        for (DSSimplifiedMasternodeEntryEntity * simplifiedMasternodeEntryEntity in hashesToDelete) {
            [chainEntity.managedObjectContext deleteObject:simplifiedMasternodeEntryEntity];
        }
}

+ (DSSimplifiedMasternodeEntryEntity*)simplifiedMasternodeEntryForHash:(NSData*)simplifiedMasternodeEntryHash onChain:(DSChainEntity*)chainEntity {
    NSArray * objects = [self objectsMatching:@"(chain == %@) && (simplifiedMasternodeEntryHash == %@)",chainEntity,simplifiedMasternodeEntryHash];
    return [objects firstObject];
}

- (DSSimplifiedMasternodeEntry*)simplifiedMasternodeEntry {
    UInt128 address = { .u32 = { 0, 0, CFSwapInt32HostToBig(0xffff), CFSwapInt32HostToBig(self.address) } };
    DSSimplifiedMasternodeEntry * simplifiedMasternodeEntry = [DSSimplifiedMasternodeEntry simplifiedMasternodeEntryWithProviderRegistrationTransactionHash:[self.providerRegistrationTransactionHash UInt256] confirmedHash:[self.confirmedHash UInt256] address:address port:self.port operatorBLSPublicKey:[self.operatorBLSPublicKey UInt384] keyIDVoting:[self.keyIDVoting UInt160AtOffset:0] isValid:self.isValid simplifiedMasternodeEntryHash:[self.simplifiedMasternodeEntryHash UInt256AtOffset:0] onChain:self.chain.chain];
    return simplifiedMasternodeEntry;
}

@end
