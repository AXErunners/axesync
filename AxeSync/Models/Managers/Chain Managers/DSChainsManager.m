//
//  DSChainManager.m
//  AxeSync
//
//  Created by Sam Westrich on 5/6/18.
//  Copyright (c) 2018 Dash Core Group <contact@dash.org>
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.

#import "DSChainsManager.h"
#import "DSChainEntity+CoreDataClass.h"
#import "NSManagedObject+Sugar.h"
#import "DSReachabilityManager.h"
#import "NSMutableData+Axe.h"
#import "NSData+Bitcoin.h"
#import "NSString+Axe.h"
#import "DSWallet.h"
#import "AxeSync.h"
#import "DSPeerManager+Protected.h"
#import "DSChainManager+Protected.h"
#include <arpa/inet.h>

#define DEVNET_CHAINS_KEY  @"DEVNET_CHAINS_KEY"

@interface DSChainsManager()

@property (nonatomic,strong) NSMutableArray * knownChains;
@property (nonatomic,strong) NSMutableArray * knownDevnetChains;
@property (nonatomic,strong) NSMutableDictionary * devnetGenesisDictionary;
@property (nonatomic,strong) DSReachabilityManager *reachability;

@end

@implementation DSChainsManager

+ (instancetype)sharedInstance
{
    static id singleton = nil;
    static dispatch_once_t onceToken = 0;
    
    dispatch_once(&onceToken, ^{
        singleton = [self new];
    });
    
    return singleton;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        self.knownChains = [NSMutableArray array];
        NSError * error = nil;
        NSMutableDictionary * registeredDevnetIdentifiers = [getKeychainDict(DEVNET_CHAINS_KEY, &error) mutableCopy];
        self.knownDevnetChains = [NSMutableArray array];
        for (NSString * string in registeredDevnetIdentifiers) {
            NSArray<DSCheckpoint*>* checkpointArray = registeredDevnetIdentifiers[string];
            [self.knownDevnetChains addObject:[DSChain setUpDevnetWithIdentifier:string withCheckpoints:checkpointArray withDefaultPort:DEVNET_STANDARD_PORT withDefaultDapiPort:DEVNET_DAPI_STANDARD_PORT]];
        }
        
        self.reachability = [DSReachabilityManager sharedManager];
    }
    return self;
}

-(DSChainManager*)mainnetManager {
    static id _mainnetManager = nil;
    static dispatch_once_t mainnetToken = 0;
    
    dispatch_once(&mainnetToken, ^{
        DSChain * mainnet = [DSChain mainnet];
        _mainnetManager = [[DSChainManager alloc] initWithChain:mainnet];
        mainnet.chainManager = _mainnetManager;
        
        [self.knownChains addObject:[DSChain mainnet]];
    });
    return _mainnetManager;
}

-(DSChainManager*)testnetManager {
    static id _testnetManager = nil;
    static dispatch_once_t testnetToken = 0;
    
    dispatch_once(&testnetToken, ^{
        DSChain * testnet = [DSChain testnet];
        _testnetManager = [[DSChainManager alloc] initWithChain:testnet];
        testnet.chainManager = _testnetManager;
        [self.knownChains addObject:[DSChain testnet]];
    });
    return _testnetManager;
}


-(DSChainManager*)devnetManagerForChain:(DSChain*)chain {
    static dispatch_once_t devnetToken = 0;
    dispatch_once(&devnetToken, ^{
        self.devnetGenesisDictionary = [NSMutableDictionary dictionary];
    });
    NSValue * genesisValue = uint256_obj(chain.genesisHash);
    DSChainManager * devnetChainManager = nil;
    @synchronized(self) {
        if (![self.devnetGenesisDictionary objectForKey:genesisValue]) {
            devnetChainManager = [[DSChainManager alloc] initWithChain:chain];
            chain.chainManager = devnetChainManager;
            [self.knownChains addObject:chain];
            [self.knownDevnetChains addObject:chain];
            [self.devnetGenesisDictionary setObject:devnetChainManager forKey:genesisValue];
        } else {
            devnetChainManager = [self.devnetGenesisDictionary objectForKey:genesisValue];
        }
    }
    return devnetChainManager;
}

-(DSChainManager *)chainManagerForChain:(DSChain*)chain {
    NSParameterAssert(chain);
    
    if ([chain isMainnet]) {
        return [self mainnetManager];
    } else if ([chain isTestnet]) {
        return [self testnetManager];
    } else if ([chain isDevnetAny]) {
        return [self devnetManagerForChain:chain];
    }
    return nil;
}

-(NSArray*)devnetChains {
    return [self.knownDevnetChains copy];
}

-(NSArray*)chains {
    return [self.knownChains copy];
}

-(void)updateDevnetChain:(DSChain*)chain forServiceLocations:(NSMutableOrderedSet<NSString*>*)serviceLocations standardPort:(uint32_t)standardPort dapiPort:(uint32_t)dapiPort protocolVersion:(uint32_t)protocolVersion minProtocolVersion:(uint32_t)minProtocolVersion sporkAddress:(NSString*)sporkAddress sporkPrivateKey:(NSString*)sporkPrivateKey {
    NSParameterAssert(chain);
    NSParameterAssert(serviceLocations);
    
    DSChainManager * chainManager = [self chainManagerForChain:chain];
    DSPeerManager * peerManager = chainManager.peerManager;
    [peerManager clearRegisteredPeers];
    if (protocolVersion) {
        chain.protocolVersion = protocolVersion;
    }
    if (minProtocolVersion) {
        chain.minProtocolVersion = minProtocolVersion;
    }
    if (sporkAddress && [sporkAddress isValidAxeDevnetAddress]) {
        chain.sporkAddress = sporkAddress;
    }
    if (sporkPrivateKey && [sporkPrivateKey isValidAxeDevnetPrivateKey]) {
        chain.sporkPrivateKey = sporkPrivateKey;
    }
    for (NSString * serviceLocation in serviceLocations) {
        NSArray * serviceArray = [serviceLocation componentsSeparatedByString:@":"];
        NSString * address = serviceArray[0];
        NSString * port = ([serviceArray count] > 1)? serviceArray[1]:nil;
        UInt128 ipAddress = { .u32 = { 0, 0, CFSwapInt32HostToBig(0xffff), 0 } };
        struct in_addr addrV4;
        struct in6_addr addrV6;
        if (inet_aton([address UTF8String], &addrV4) != 0) {
            uint32_t ip = ntohl(addrV4.s_addr);
            ipAddress.u32[3] = CFSwapInt32HostToBig(ip);
            DSDLog(@"%08x", ip);
        } else if (inet_pton(AF_INET6, [address UTF8String], &addrV6)) {
            //todo support IPV6
            DSDLog(@"we do not yet support IPV6");
        } else {
            DSDLog(@"invalid address");
        }
        
        [peerManager registerPeerAtLocation:ipAddress port:port?[port intValue]:standardPort dapiPort:dapiPort];
    }
}

-(DSChain*)registerDevnetChainWithIdentifier:(NSString*)identifier forServiceLocations:(NSMutableOrderedSet<NSString*>*)serviceLocations standardPort:(uint32_t)standardPort dapiPort:(uint32_t)dapiPort protocolVersion:(uint32_t)protocolVersion minProtocolVersion:(uint32_t)minProtocolVersion sporkAddress:(NSString*)sporkAddress sporkPrivateKey:(NSString*)sporkPrivateKey {
    NSParameterAssert(identifier);
    NSParameterAssert(serviceLocations);
    
    NSError * error = nil;
    
    DSChain * chain = [DSChain setUpDevnetWithIdentifier:identifier withCheckpoints:nil withDefaultPort:standardPort withDefaultDapiPort:dapiPort];
    if (protocolVersion) {
        chain.protocolVersion = protocolVersion;
    }
    if (minProtocolVersion) {
        chain.minProtocolVersion = minProtocolVersion;
    }
    if (sporkAddress && [sporkAddress isValidAxeDevnetAddress]) {
        chain.sporkAddress = sporkAddress;
    }
    if (sporkPrivateKey && [sporkPrivateKey isValidAxeDevnetPrivateKey]) {
        chain.sporkPrivateKey = sporkPrivateKey;
    }
    DSChainManager * chainManager = [self chainManagerForChain:chain];
    DSPeerManager * peerManager = chainManager.peerManager;
    for (NSString * serviceLocation in serviceLocations) {
        NSArray * serviceArray = [serviceLocation componentsSeparatedByString:@":"];
        NSString * address = serviceArray[0];
        NSString * port = ([serviceArray count] > 1)? serviceArray[1]:nil;
        UInt128 ipAddress = { .u32 = { 0, 0, CFSwapInt32HostToBig(0xffff), 0 } };
        struct in_addr addrV4;
        struct in6_addr addrV6;
        if (inet_aton([address UTF8String], &addrV4) != 0) {
            uint32_t ip = ntohl(addrV4.s_addr);
            ipAddress.u32[3] = CFSwapInt32HostToBig(ip);
            DSDLog(@"%08x", ip);
        } else if (inet_pton(AF_INET6, [address UTF8String], &addrV6)) {
            //todo support IPV6
            DSDLog(@"we do not yet support IPV6");
        } else {
            DSDLog(@"invalid address");
        }
        
        [peerManager registerPeerAtLocation:ipAddress port:port?[port intValue]:standardPort dapiPort:dapiPort];
    }
    
    NSMutableDictionary * registeredDevnetsDictionary = [getKeychainDict(DEVNET_CHAINS_KEY, &error) mutableCopy];
    
    if (!registeredDevnetsDictionary) registeredDevnetsDictionary = [NSMutableDictionary dictionary];
    if (![[registeredDevnetsDictionary allKeys] containsObject:identifier]) {
        [registeredDevnetsDictionary setObject:chain.checkpoints forKey:identifier];
        setKeychainDict(registeredDevnetsDictionary, DEVNET_CHAINS_KEY, NO);
    }
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:DSChainsDidChangeNotification object:nil];
    });
    return chain;
}

-(void)removeDevnetChain:(DSChain *)chain {
    NSParameterAssert(chain);
    
    [[DSAuthenticationManager sharedInstance] authenticateWithPrompt:@"Remove Devnet?" usingBiometricAuthentication:FALSE alertIfLockout:NO completion:^(BOOL authenticatedOrSuccess, BOOL usedBiometrics, BOOL cancelled) {
        if (!cancelled && authenticatedOrSuccess) {
            NSError * error = nil;
            DSChainManager * chainManager = [self chainManagerForChain:chain];
            DSPeerManager * peerManager = chainManager.peerManager;
            [peerManager clearRegisteredPeers];
            NSMutableDictionary * registeredDevnetsDictionary = [getKeychainDict(DEVNET_CHAINS_KEY, &error) mutableCopy];
            
            if (!registeredDevnetsDictionary) registeredDevnetsDictionary = [NSMutableDictionary dictionary];
            if ([[registeredDevnetsDictionary allKeys] containsObject:chain.devnetIdentifier]) {
                [registeredDevnetsDictionary removeObjectForKey:chain.devnetIdentifier];
                setKeychainDict(registeredDevnetsDictionary, DEVNET_CHAINS_KEY, NO);
            }
            [chain wipeWalletsAndDerivatives];
            [[AxeSync sharedSyncController] wipePeerDataForChain:chain];
            [[AxeSync sharedSyncController] wipeBlockchainDataForChain:chain];
            [[AxeSync sharedSyncController] wipeSporkDataForChain:chain];
            [[AxeSync sharedSyncController] wipeMasternodeDataForChain:chain];
            [[AxeSync sharedSyncController] wipeGovernanceDataForChain:chain];
            [[AxeSync sharedSyncController] wipeWalletDataForChain:chain forceReauthentication:NO]; //this takes care of blockchain info as well;
            [self.knownDevnetChains removeObject:chain];
            [self.knownChains removeObject:chain];
            NSValue * genesisValue = uint256_obj(chain.genesisHash);
            [self.devnetGenesisDictionary removeObjectForKey:genesisValue];
            dispatch_async(dispatch_get_main_queue(), ^{
                [[NSNotificationCenter defaultCenter] postNotificationName:DSChainsDidChangeNotification object:nil];
            });
        }
    }];
    
}

-(BOOL)hasAWallet {
    for (DSChain * chain in self.knownChains) {
        if (chain.hasAWallet) return TRUE;
    }
    return FALSE;
}

-(NSArray*)allWallets {
    NSMutableArray * mAllWallets = [NSMutableArray array];
    for (DSChain * chain in self.knownChains) {
        if (chain.wallets) [mAllWallets addObjectsFromArray:chain.wallets];
    }
    return [mAllWallets copy];
}

@end
