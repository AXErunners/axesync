//
//  DSAxeSync.h
//  axesync
//
//  Created by Sam Westrich on 3/4/18.
//  Copyright © 2018 axecore. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "DSChainPeerManager.h"
#import "DSChain.h"
#import "DSKey.h"
#import "DSDerivationPath.h"
#import "DSChainManager.h"
#import "DSPriceManager.h"
#import "DSMasternodeManager.h"
#import "DSGovernanceSyncManager.h"
#import "DSGovernanceObject.h"
#import "DSGovernanceVote.h"
#import "DSSporkManager.h"
#import "DSAuthenticationManager.h"
#import "DSEventManager.h"
#import "DSShapeshiftManager.h"
#import "DSBIP39Mnemonic.h"
#import "DSWallet.h"
#import "DSAccount.h"
#import "DSDerivationPath.h"
#import "NSString+Axe.h"
#import "NSMutableData+Axe.h"
#import "DSOptionsManager.h"
#import "NSData+Axe.h"
#import "DSAddressEntity+CoreDataProperties.h"
#import "DSDerivationPathEntity+CoreDataProperties.h"
#import "DSMerkleBlockEntity+CoreDataProperties.h"
#import "DSMasternodeBroadcastHashEntity+CoreDataProperties.h"
#import "DSMasternodeBroadcastEntity+CoreDataProperties.h"
#import "DSGovernanceObjectEntity+CoreDataProperties.h"
#import "DSGovernanceObjectHashEntity+CoreDataProperties.h"
#import "DSGovernanceVoteEntity+CoreDataProperties.h"
#import "DSGovernanceVoteHashEntity+CoreDataProperties.h"
#import "DSSporkEntity+CoreDataProperties.h"
#import "DSTransactionEntity+CoreDataProperties.h"
#import "DSTransactionHashEntity+CoreDataProperties.h"
#import "DSTxOutputEntity+CoreDataProperties.h"
#import "DSTxInputEntity+CoreDataProperties.h"
#import "DSSimplifiedMasternodeEntry.h"
#import "DSSimplifiedMasternodeEntryEntity+CoreDataProperties.h"
#import "NSManagedObject+Sugar.h"
#import "DSPaymentRequest.h"
#import "DSPaymentProtocol.h"

//! Project version number for axesync.
FOUNDATION_EXPORT double AxeSyncVersionNumber;

//! Project version string for axesync.
FOUNDATION_EXPORT const unsigned char AxeSyncVersionString[];

// In this header, you should import all the public headers of your framework using statements like #import <axesync/PublicHeader.h>

@interface AxeSync : NSObject

@property (nonatomic,assign) BOOL deviceIsJailbroken;

+ (instancetype _Nullable)sharedSyncController;

-(void)startSyncForChain:(DSChain*)chain;
-(void)stopSyncForChain:(DSChain*)chain;
-(void)stopSyncAllChains;

-(void)wipePeerDataForChain:(DSChain*)chain;
-(void)wipeBlockchainDataForChain:(DSChain*)chain;
-(void)wipeGovernanceDataForChain:(DSChain*)chain;
-(void)wipeMasternodeDataForChain:(DSChain*)chain;
-(void)wipeSporkDataForChain:(DSChain*)chain;
-(void)wipeWalletDataForChain:(DSChain*)chain;

-(uint64_t)dbSize;


@end
