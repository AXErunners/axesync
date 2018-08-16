//
//  DSChainManager.h
//  AxeSync
//
//  Created by Sam Westrich on 5/6/18.
//

#import <Foundation/Foundation.h>
#import "DSChainPeerManager.h"

FOUNDATION_EXPORT NSString* _Nonnull const DSChainsDidChangeNotification;

#define SPEND_LIMIT_KEY     @"SPEND_LIMIT_KEY"

@interface DSChainManager : NSObject

@property (nonatomic,strong) DSChainPeerManager * mainnetManager;
@property (nonatomic,strong) DSChainPeerManager * testnetManager;
@property (nonatomic,strong) NSArray * devnetManagers;
@property (nonatomic,readonly) NSArray * chains;
@property (nonatomic,readonly) NSArray * devnetChains;
@property (nonatomic,readonly) uint64_t spendingLimit;

-(DSChainPeerManager*)peerManagerForChain:(DSChain*)chain;

-(void)updateDevnetChain:(DSChain* _Nonnull)chain forServiceLocations:(NSMutableOrderedSet<NSString*>* _Nonnull)serviceLocations  standardPort:(uint32_t)standardPort protocolVersion:(uint32_t)protocolVersion minProtocolVersion:(uint32_t)minProtocolVersion sporkAddress:(NSString* _Nullable)sporkAddress sporkPrivateKey:(NSString* _Nullable)sporkPrivateKey;

-(DSChain* _Nullable)registerDevnetChainWithIdentifier:(NSString* _Nonnull)identifier forServiceLocations:(NSMutableOrderedSet<NSString*>* _Nonnull)serviceLocations standardPort:(uint32_t)standardPort protocolVersion:(uint32_t)protocolVersion minProtocolVersion:(uint32_t)minProtocolVersion sporkAddress:(NSString* _Nullable)sporkAddress sporkPrivateKey:(NSString* _Nullable)sporkPrivateKey;

-(void)removeDevnetChain:(DSChain* _Nonnull)chain;

+ (instancetype _Nullable)sharedInstance;

-(void)resetSpendingLimits;

@end
