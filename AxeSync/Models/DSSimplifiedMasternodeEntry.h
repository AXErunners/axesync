//
//  DSSimplifiedMasternodeEntry.h
//  AxeSync
//
//  Created by Sam Westrich on 7/12/18.
//

#import <Foundation/Foundation.h>
#import "BigIntTypes.h"

@class DSChain,DSSimplifiedMasternodeEntryEntity,DSWallet,DSMerkleBlock;

@interface DSSimplifiedMasternodeEntry : NSObject

@property(nonatomic,readonly) UInt256 providerRegistrationTransactionHash;
@property(nonatomic,readonly) UInt256 confirmedHash;
@property(nonatomic,readonly) UInt256 confirmedHashHashedWithProviderRegistrationTransactionHash;
@property(nonatomic,readonly) UInt128 address;
@property(nonatomic,readonly) NSString * host;
@property(nonatomic,readonly) NSString * ipAddressString;
@property(nonatomic,readonly) uint16_t port;
@property(nonatomic,readonly) NSString * portString;
@property(nonatomic,readonly) NSString * validString;
@property(nonatomic,readonly) UInt384 operatorPublicKey;
@property(nonatomic,readonly) NSDictionary * previousOperatorPublicKeys;
@property(nonatomic,readonly) NSDictionary * previousSimplifiedMasternodeEntryHashes;
@property(nonatomic,readonly) NSDictionary * previousValidity;
@property(nonatomic,readonly) UInt160 keyIDVoting;
@property(nonatomic,readonly) NSString * votingAddress;
@property(nonatomic,readonly) NSString * operatorAddress;
@property(nonatomic,readonly) BOOL isValid;
@property(nonatomic,readonly) UInt256 simplifiedMasternodeEntryHash;
@property(nonatomic,readonly) DSChain * chain;
@property(nonatomic,readonly) NSData * payloadData;
@property(nonatomic,readonly) NSString * uniqueID;
@property(nonatomic,readonly,class) uint32_t payloadLength;
@property(nonatomic,readonly) DSSimplifiedMasternodeEntryEntity * simplifiedMasternodeEntryEntity;

+(instancetype)simplifiedMasternodeEntryWithData:(NSData*)data onChain:(DSChain*)chain;

+(instancetype)simplifiedMasternodeEntryWithProviderRegistrationTransactionHash:(UInt256)providerRegistrationTransactionHash confirmedHash:(UInt256)confirmedHash address:(UInt128)address port:(uint16_t)port operatorBLSPublicKey:(UInt384)operatorBLSPublicKey previousOperatorBLSPublicKeys:(NSDictionary <DSMerkleBlock*,NSData*>*)previousOperatorBLSPublicKeys keyIDVoting:(UInt160)keyIDVoting isValid:(BOOL)isValid previousValidity:(NSDictionary <DSMerkleBlock*,NSData*>*)previousValidity simplifiedMasternodeEntryHash:(UInt256)simplifiedMasternodeEntryHash previousSimplifiedMasternodeEntryHashes:(NSDictionary <DSMerkleBlock*,NSData*>*)previousSimplifiedMasternodeEntryHashes onChain:(DSChain*)chain;

-(BOOL)verifySignature:(UInt768)signature forMessageDigest:(UInt256)messageDigest;

-(void)keepInfoOfPreviousEntryVersion:(DSSimplifiedMasternodeEntry*)masternodeEntry atBlockHash:(UInt256)blockHash;

-(UInt256)simplifiedMasternodeEntryHashAtBlock:(DSMerkleBlock*)merkleBlock;

-(UInt256)simplifiedMasternodeEntryHashAtBlockHash:(UInt256)blockHash;

-(UInt384)operatorPublicKeyAtBlock:(DSMerkleBlock*)merkleBlock;

-(UInt384)operatorPublicKeyAtBlockHash:(UInt256)blockHash;

-(BOOL)isValidAtBlock:(DSMerkleBlock*)merkleBlock;

-(BOOL)isValidAtBlockHash:(UInt256)blockHash;

-(NSDictionary*)compare:(DSSimplifiedMasternodeEntry*)other ourBlockHash:(UInt256)ourBlockHash theirBlockHash:(UInt256)theirBlockHash usingOurString:(NSString*)ours usingTheirString:(NSString*)theirs;

-(NSDictionary*)compare:(DSSimplifiedMasternodeEntry*)other atBlockHash:(UInt256)blockHash;

@end
