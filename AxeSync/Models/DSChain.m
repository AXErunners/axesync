//
//  DSChain.m
//  AxeSync
//  Created by Quantum Explorer on 05/05/18.
//  Copyright (c) 2018 Quantum Explorer <quantum@dash.org>
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

#import "DSChain.h"
#import "DSPeer.h"
#import "NSString+Bitcoin.h"
#import "NSData+Bitcoin.h"
#import "NSManagedObject+Sugar.h"
#import "DSEventManager.h"
#import "DSBloomFilter.h"
#import "DSTransaction.h"
#import "DSTransactionEntity+CoreDataClass.h"
#import "DSMerkleBlock.h"
#import "DSMerkleBlockEntity+CoreDataClass.h"
#import "DSPriceManager.h"
#import "DSChainEntity+CoreDataClass.h"
#import "DSWallet.h"
#import "DSPeerManager.h"
#import "DSChainEntity+CoreDataClass.h"
#import "NSCoder+Axe.h"
#import "DSAccount.h"
#import "DSBIP39Mnemonic.h"
#import "DSDerivationPath.h"
#import "DSOptionsManager.h"
#import "DSChainsManager.h"
#import "DSMasternodeManager.h"
#import "DSDerivationPathEntity+CoreDataProperties.h"
#import "NSMutableData+Axe.h"
#import "NSData+Axe.h"
#import "DSSporkManager.h"
#import "DSSimplifiedMasternodeEntry.h"
#import "DSSimplifiedMasternodeEntryEntity+CoreDataProperties.h"
#import "DSChainManager.h"
#import "DSFundsDerivationPath.h"
#import "DSProviderRegistrationTransaction.h"
#import "DSProviderUpdateRevocationTransaction.h"
#import "DSProviderUpdateRegistrarTransaction.h"
#import "DSProviderUpdateServiceTransaction.h"
#import "DSBlockchainUserRegistrationTransaction.h"
#import "DSBlockchainUserResetTransaction.h"
#import "DSBlockchainUserTopupTransaction.h"
#import "DSBlockchainUserCloseTransaction.h"
#import "DSTransition.h"
#import "DSLocalMasternode+Protected.h"
#import "DSKey.h"
#import "DSDerivationPathFactory.h"
#import "DSAuthenticationKeysDerivationPath.h"
#import "DSMasternodeHoldingsDerivationPath.h"
#import "DSSpecialTransactionsWalletHolder.h"
#import "DSLocalMasternodeEntity+CoreDataProperties.h"
#import "DSMasternodeListEntity+CoreDataProperties.h"
#import "DSQuorumEntryEntity+CoreDataProperties.h"

typedef const struct checkpoint { uint32_t height; const char *checkpointHash; uint32_t timestamp; uint32_t target; const char * masternodeListPath; const char * merkleRoot;} checkpoint;

static checkpoint testnet_checkpoint_array[] = {
    {           0, "00000381388b90aff350a4d5913d4a50fed79159a3a687470e01ca1527e87568", 1518140232, 0x1e0ffff0u, "", "" }
};

// blockchain checkpoints - these are also used as starting points for partial chain downloads, so they need to be at
// difficulty transition boundaries in order to verify the block difficulty at the immediately following transition
static checkpoint mainnet_checkpoint_array[] = {
    {      0, "00000c33631ca6f2f61368991ce2dc03306b5bb50bf7cede5cfbba6db38e52e6", 1518140231, 0x1e0ffff0u, "", "" },
    {   1500, "000000d671ea75d2a5578862393e04c29d2368c7461f65f278e083b13696408e", 1518237227, 0x1e018c18u, "", "" },
    {   4991, "0000002d9b0d76fd076b4a6f2601f130ad7e2b43af92b8ffd2619f20478b01f2", 1518745517, 0x1e015880u, "", "" },
    {   9918, "00000000007a7f636d5075eba76dfe76fbe1d865890aa0a8620406e8cb937a78", 1518778918, 0x1c00ea5bu, "", "" },
    {  16912, "00000000000991c08af937ad98e3821a2fdc31dd636ce14c6597fb7820359749", 1519722114, 0x1b140cb3u, "", "" },
    {  23912, "000000000024573fae6b7e7561d931499d6abaddb9f2dff608ec693a34366b7f", 1520831809, 0x1b278e64u, "", "" },
    {  35457, "000000000013e6af48c778097fb5dc4b081ff9736bb8b74afcd67cf41b102111", 1522654685, 0x1b16e6e2u, "", "" },
    {  45479, "00000000002027c4ba5b4d1f5e451fd400d5bdd58b282ddd7a865a2ce76514c0", 1524238915, 0x1b3492e9u, "", "" },
    {  55895, "000000000035b29b53977dd38d7d09ea14749b5b5c6facf2d4f25c0abb9d864f", 1525888713, 0x1b7fd3f8u, "", "" },
    {  68899, "000000000005376de272e4d5b3b50f165d2ac57911d74b04f77018a9247d18a7", 1527946299, 0x1b22526au, "", "" },
    {  74619, "000000000030bc1f7703071874e3f1acf575b8aec566b36285e3e92248314da5", 1528853284, 0x1b313fb7u, "", "" },
    {  75095, "0000000000312041338e175624468d089f95e55a3525b1be27d21ee1c6533d09", 1528929084, 0x1b347da4u, "", "" },
    {  88805, "000000000023fb96f9bcb53f5637b06972bb7431b9fcf4198dc90f46a83d26ae", 1531095233, 0x1b4737e8u, "", "" },
    { 107996, "00000000000c20ee519d77edf18652fc61c86301e57bedc1623c10da48b329d0", 1534123375, 0x1b0cc534u, "", "" },
    { 126993, "00000000000118e53dcaedd2db54029b175217ce2d10b552744939deff3495fd", 1537123276, 0x1b15a29du, "", "" },
    { 145909, "0000000000008ec28fa572d5908458c2c02ce67dfa2bc6f82a61f1eef70ee491", 1540107698, 0x1b2535a5u, "", "" },
    { 161603, "000000000005787b2c4c2016f57bee0d91cdee8ba8628ab392486bc4513dae1d", 1542582844, 0x1b0854ecu, "", "" },
    { 180423, "000000000004c448af3a3157da422efb027abf6280f0ef5748b1b0410b3765c5", 1545554641, 0x1b089860u, "", "" },
    { 200024, "000000000000633bd0073ca5f52b8005c371e5fc9bd3d39b087eee83ee35ac12", 1548649180, 0x1a729536u, "", "" },
    { 211480, "000000000000d8f124bde34e19fe0664afcfd512ed9d13ea27c65772de3e1657", 1550458950, 0x1b014b4du, "", "" },
    { 221382, "00000000000020d9f2af1589c9087e7ec1542b7dd2b121e307f6a2a8cf0d453f", 1552020983, 0x1a4467cau, "", "" },
    { 230442, "0000000000003fe6bc8985bf8c137487c69c153c316cd67aea3ec1886fb1adf4", 1553458998, 0x1a427b99u, "", "" }
};

#define FEE_PER_BYTE_KEY          @"FEE_PER_BYTE"

#define CHAIN_WALLETS_KEY  @"CHAIN_WALLETS_KEY"
#define CHAIN_STANDALONE_DERIVATIONS_KEY  @"CHAIN_STANDALONE_DERIVATIONS_KEY"
#define REGISTERED_PEERS_KEY  @"REGISTERED_PEERS_KEY"

#define PROTOCOL_VERSION_LOCATION  @"PROTOCOL_VERSION_LOCATION"
#define DEFAULT_MIN_PROTOCOL_VERSION_LOCATION  @"MIN_PROTOCOL_VERSION_LOCATION"

#define SPORK_PUBLIC_KEY_LOCATION  @"SPORK_PUBLIC_KEY_LOCATION"
#define SPORK_ADDRESS_LOCATION  @"SPORK_ADDRESS_LOCATION"
#define SPORK_PRIVATE_KEY_LOCATION  @"SPORK_PRIVATE_KEY_LOCATION"

#define CHAIN_VOTING_KEYS_KEY  @"CHAIN_VOTING_KEYS_KEY"

#define LOG_PREV_BLOCKS_ON_ORPHAN 0

// number of previous confirmations needed in ix inputs
#define MAINNET_IX_PREVIOUS_CONFIRMATIONS_NEEDED 6
#define TESTNET_IX_PREVIOUS_CONFIRMATIONS_NEEDED 2

@interface DSChain ()

@property (nonatomic, strong) DSMerkleBlock *lastBlock, *lastOrphan;
@property (nonatomic, strong) NSMutableDictionary *blocks, *orphans;
@property (nonatomic, strong) NSMutableDictionary <NSData*,DSCheckpoint*> *checkpointsByHashDictionary;
@property (nonatomic, strong) NSMutableDictionary <NSNumber*,DSCheckpoint*> *checkpointsByHeightDictionary;
@property (nonatomic, strong) NSArray<DSCheckpoint*> * checkpoints;
@property (nonatomic, copy) NSString * uniqueID;
@property (nonatomic, copy) NSString * networkName;
@property (nonatomic, strong) NSMutableArray<DSWallet *> * mWallets;
@property (nonatomic, strong) DSChainEntity * mainThreadChainEntity;
@property (nonatomic, strong) DSChainEntity * delegateQueueChainEntity;
@property (nonatomic, strong) NSString * devnetIdentifier;
@property (nonatomic, strong) DSAccount * viewingAccount;
@property (nonatomic, strong) NSMutableDictionary * estimatedBlockHeights;
@property (nonatomic, assign) uint32_t bestEstimatedBlockHeight;
@property (nonatomic, assign) uint64_t ixPreviousConfirmationsNeeded;
@property (nonatomic, assign) uint32_t cachedMinProtocolVersion;
@property (nonatomic, assign) uint32_t cachedProtocolVersion;
@property (nonatomic, strong) NSManagedObjectContext * managedObjectContext;

@end

@implementation DSChain

// MARK: - Creation, Setup and Getting a Chain

-(instancetype)init {
    if (! (self = [super init])) return nil;
    NSAssert([NSThread isMainThread], @"Chains should only be created on main thread (for chain entity optimizations)");
    self.orphans = [NSMutableDictionary dictionary];
    self.genesisHash = self.checkpoints[0].checkpointHash;
    self.mWallets = [NSMutableArray array];
    self.estimatedBlockHeights = [NSMutableDictionary dictionary];
    self.managedObjectContext = [NSManagedObject context];
    
    self.feePerByte = DEFAULT_FEE_PER_B;
    uint64_t feePerByte = [[NSUserDefaults standardUserDefaults] doubleForKey:FEE_PER_BYTE_KEY];
    if (feePerByte >= MIN_FEE_PER_B && feePerByte <= MAX_FEE_PER_B) self.feePerByte = feePerByte;
    
    return self;
}

- (instancetype)initWithType:(DSChainType)type checkpoints:(NSArray*)checkpoints
{
    if (! (self = [self init])) return nil;
    _chainType = type;
    switch (type) {
        case DSChainType_MainNet: {
            self.standardPort = MAINNET_STANDARD_PORT;
            self.standardDapiPort = MAINNET_DAPI_STANDARD_PORT;
            self.ixPreviousConfirmationsNeeded = MAINNET_IX_PREVIOUS_CONFIRMATIONS_NEEDED;
            break;
        }
        case DSChainType_TestNet: {
            self.standardPort = TESTNET_STANDARD_PORT;
            self.standardDapiPort = TESTNET_DAPI_STANDARD_PORT;
            self.ixPreviousConfirmationsNeeded = TESTNET_IX_PREVIOUS_CONFIRMATIONS_NEEDED;
            break;
        }
        case DSChainType_DevNet: {
            NSAssert(NO, @"DevNet should be configured with initAsDevnetWithIdentifier:checkpoints:port:dapiPort:ixPreviousConfirmationsNeeded:");
            break;
        }
    }
    self.checkpoints = checkpoints;
    self.genesisHash = self.checkpoints[0].checkpointHash;
    self.mainThreadChainEntity = [self chainEntity];

    return self;
}

-(void)setUp {
    [self retrieveWallets];
    [self retrieveStandaloneDerivationPaths];
}


-(instancetype)initAsDevnetWithIdentifier:(NSString*)identifier checkpoints:(NSArray<DSCheckpoint*>*)checkpoints port:(uint32_t)port dapiPort:(uint32_t)dapiPort ixPreviousConfirmationsNeeded:(uint64_t)ixPreviousConfirmationsNeeded
{
    //for devnet the genesis checkpoint is really the second block
    if (! (self = [self init])) return nil;
    _chainType = DSChainType_DevNet;
    if (!checkpoints || ![checkpoints count]) {
        DSCheckpoint * genesisCheckpoint = [DSCheckpoint genesisDevnetCheckpoint];
        DSCheckpoint * secondCheckpoint = [self createDevNetGenesisBlockCheckpointForParentCheckpoint:genesisCheckpoint withIdentifier:identifier];
        self.checkpoints = @[genesisCheckpoint,secondCheckpoint];
        self.genesisHash = secondCheckpoint.checkpointHash;
    } else {
        self.checkpoints = checkpoints;
        self.genesisHash = checkpoints[1].checkpointHash;
    }
    //    DSDLog(@"%@",[NSData dataWithUInt256:self.checkpoints[0].checkpointHash]);
    //    DSDLog(@"%@",[NSData dataWithUInt256:self.genesisHash]);
    self.standardPort = port;
    self.standardDapiPort = dapiPort;
    self.ixPreviousConfirmationsNeeded = ixPreviousConfirmationsNeeded;
    self.devnetIdentifier = identifier;
    self.mainThreadChainEntity = [self chainEntity];
    return self;
}

//static CBlock CreateDevNetGenesisBlock(const uint256 &prevBlockHash, const std::string& devNetName, uint32_t nTime, uint32_t nNonce, uint32_t nBits, const CAmount& genesisReward)
//{
//    assert(!devNetName.empty());
//
//    CMutableTransaction txNew;
//    txNew.nVersion = 1;
//    txNew.vin.resize(1);
//    txNew.vout.resize(1);
//    // put height (BIP34) and devnet name into coinbase
//    txNew.vin[0].scriptSig = CScript() << 1 << std::vector<unsigned char>(devNetName.begin(), devNetName.end());
//    txNew.vout[0].nValue = genesisReward;
//    txNew.vout[0].scriptPubKey = CScript() << OP_RETURN;
//
//    CBlock genesis;
//    genesis.nTime    = nTime;
//    genesis.nBits    = nBits;
//    genesis.nNonce   = nNonce;
//    genesis.nVersion = 4;
//    genesis.vtx.push_back(MakeTransactionRef(std::move(txNew)));
//    genesis.hashPrevBlock = prevBlockHash;
//    genesis.hashMerkleRoot = BlockMerkleRoot(genesis);
//    return genesis;
//}

-(UInt256)blockHashForDevNetGenesisBlockWithVersion:(uint32_t)version prevHash:(UInt256)prevHash merkleRoot:(UInt256)merkleRoot timestamp:(uint32_t)timestamp target:(uint32_t)target nonce:(uint32_t)nonce {
    NSMutableData *d = [NSMutableData data];
    
    [d appendUInt32:version];
    
    [d appendBytes:&prevHash length:sizeof(prevHash)];
    [d appendBytes:&merkleRoot length:sizeof(merkleRoot)];
    [d appendUInt32:timestamp];
    [d appendUInt32:target];
    [d appendUInt32:nonce];
    return d.x11;
}

-(DSCheckpoint*)createDevNetGenesisBlockCheckpointForParentCheckpoint:(DSCheckpoint*)checkpoint withIdentifier:(NSString*)identifier {
    uint32_t nTime = checkpoint.timestamp + 1;
    uint32_t nBits = checkpoint.target;
    UInt256 fullTarget = setCompact(nBits);
    uint32_t nVersion = 4;
    UInt256 prevHash = checkpoint.checkpointHash;
    UInt256 merkleRoot = [DSTransaction devnetGenesisCoinbaseWithIdentifier:identifier forChain:self].txHash;
    uint32_t nonce = UINT32_MAX; //+1 => 0;
    UInt256 blockhash;
    do {
        nonce++; //should start at 0;
        blockhash = [self blockHashForDevNetGenesisBlockWithVersion:nVersion prevHash:prevHash merkleRoot:merkleRoot timestamp:nTime target:nBits nonce:nonce];
    } while (nonce < UINT32_MAX && uint256_sup(blockhash, fullTarget));
    DSCheckpoint * block2Checkpoint = [[DSCheckpoint alloc] init];
    block2Checkpoint.height = 1;
    block2Checkpoint.checkpointHash = blockhash;//*(UInt256*)[NSData dataWithUInt256:blockhash].reverse.bytes;
    block2Checkpoint.target = nBits;
    block2Checkpoint.timestamp = nTime;
    return block2Checkpoint;
}

+(NSMutableArray*)createCheckpointsArrayFromCheckpoints:(checkpoint*)checkpoints count:(NSUInteger)checkpointCount {
    NSMutableArray * checkpointMutableArray = [NSMutableArray array];
    for (int i = 0; i <checkpointCount;i++) {
        DSCheckpoint * check = [DSCheckpoint new];
        check.height = checkpoints[i].height;
        check.checkpointHash = *(UInt256 *)[NSString stringWithCString:checkpoints[i].checkpointHash encoding:NSUTF8StringEncoding].hexToData.reverse.bytes;
        check.target = checkpoints[i].target;
        check.timestamp = checkpoints[i].timestamp;
        check.masternodeListName = [NSString stringWithCString:checkpoints[i].masternodeListPath encoding:NSUTF8StringEncoding];
        NSString * merkleRootString = [NSString stringWithCString:checkpoints[i].merkleRoot encoding:NSUTF8StringEncoding];
        check.merkleRoot = [merkleRootString isEqualToString:@""]?UINT256_ZERO:merkleRootString.hexToData.reverse.UInt256;
        [checkpointMutableArray addObject:check];
    }
    return [checkpointMutableArray copy];
}

-(DSChainEntity*)chainEntity {
    if ([NSThread isMainThread] && _mainThreadChainEntity) return self.mainThreadChainEntity;
    __block DSChainEntity* chainEntity = nil;
    [[DSChainEntity context] performBlockAndWait:^{
        chainEntity = [DSChainEntity chainEntityForType:self.chainType devnetIdentifier:self.devnetIdentifier checkpoints:self.checkpoints];
    }];
    return chainEntity;
}

-(DSChainManager*)chainManager {
    if (_chainManager) return _chainManager;
    return [[DSChainsManager sharedInstance] chainManagerForChain:self];
}

+(DSChain*)mainnet {
    static DSChain* _mainnet = nil;
    static dispatch_once_t mainnetToken = 0;
    __block BOOL inSetUp = FALSE;
    dispatch_once(&mainnetToken, ^{
        _mainnet = [[DSChain alloc] initWithType:DSChainType_MainNet checkpoints:[DSChain createCheckpointsArrayFromCheckpoints:mainnet_checkpoint_array count:(sizeof(mainnet_checkpoint_array)/sizeof(*mainnet_checkpoint_array))]];
        
        inSetUp = TRUE;
        //DSDLog(@"%@",[NSData dataWithUInt256:_mainnet.checkpoints[0].checkpointHash]);
    });
    if (inSetUp) {
        [_mainnet setUp];
        [[DSChainEntity context] performBlockAndWait:^{
            DSChainEntity * chainEntity = [_mainnet chainEntity];
            _mainnet.totalMasternodeCount = chainEntity.totalMasternodeCount;
            _mainnet.totalGovernanceObjectsCount = chainEntity.totalGovernanceObjectsCount;
            _mainnet.masternodeBaseBlockHash = chainEntity.baseBlockHash.UInt256;
        }];
    }
    
    return _mainnet;
}

+(DSChain*)testnet {
    static DSChain* _testnet = nil;
    static dispatch_once_t testnetToken = 0;
    __block BOOL inSetUp = FALSE;
    dispatch_once(&testnetToken, ^{
        _testnet = [[DSChain alloc] initWithType:DSChainType_TestNet checkpoints:[DSChain createCheckpointsArrayFromCheckpoints:testnet_checkpoint_array count:(sizeof(testnet_checkpoint_array)/sizeof(*testnet_checkpoint_array))]];
        inSetUp = TRUE;
    });
    if (inSetUp) {
        [_testnet setUp];
        [[DSChainEntity context] performBlockAndWait:^{
            DSChainEntity * chainEntity = [_testnet chainEntity];
            _testnet.totalMasternodeCount = chainEntity.totalMasternodeCount;
            _testnet.totalGovernanceObjectsCount = chainEntity.totalGovernanceObjectsCount;
            _testnet.masternodeBaseBlockHash = chainEntity.baseBlockHash.UInt256;
        }];
    }
    
    return _testnet;
}

static NSMutableDictionary * _devnetDictionary = nil;
static dispatch_once_t devnetToken = 0;

+(DSChain*)devnetWithIdentifier:(NSString*)identifier {
    dispatch_once(&devnetToken, ^{
        _devnetDictionary = [NSMutableDictionary dictionary];
    });
    DSChain * devnetChain = [_devnetDictionary objectForKey:identifier];
    return devnetChain;
}

+(DSChain*)setUpDevnetWithIdentifier:(NSString*)identifier withCheckpoints:(NSArray<DSCheckpoint*>*)checkpointArray withDefaultPort:(uint32_t)port withDefaultDapiPort:(uint32_t)dapiPort {
    dispatch_once(&devnetToken, ^{
        _devnetDictionary = [NSMutableDictionary dictionary];
    });
    DSChain * devnetChain = nil;
    __block BOOL inSetUp = FALSE;
    @synchronized(self) {
        if (![_devnetDictionary objectForKey:identifier]) {
            devnetChain = [[DSChain alloc] initAsDevnetWithIdentifier:identifier checkpoints:checkpointArray port:port dapiPort:dapiPort ixPreviousConfirmationsNeeded:TESTNET_IX_PREVIOUS_CONFIRMATIONS_NEEDED];
            [_devnetDictionary setObject:devnetChain forKey:identifier];
            inSetUp = TRUE;
        } else {
            devnetChain = [_devnetDictionary objectForKey:identifier];
        }
    }
    if (inSetUp) {
        [devnetChain setUp];
        [[DSChainEntity context] performBlockAndWait:^{
            DSChainEntity * chainEntity = [devnetChain chainEntity];
            devnetChain.totalMasternodeCount = chainEntity.totalMasternodeCount;
            devnetChain.totalGovernanceObjectsCount = chainEntity.totalGovernanceObjectsCount;
            devnetChain.masternodeBaseBlockHash = chainEntity.baseBlockHash.UInt256;
        }];
    }
    
    return devnetChain;
}

+(DSChain*)chainForNetworkName:(NSString*)networkName {
    if ([networkName isEqualToString:@"main"] || [networkName isEqualToString:@"live"] || [networkName isEqualToString:@"livenet"] || [networkName isEqualToString:@"mainnet"]) return [self mainnet];
    if ([networkName isEqualToString:@"test"] || [networkName isEqualToString:@"testnet"]) return [self testnet];
    return nil;
}

-(NSArray<DSFundsDerivationPath*>*)standardDerivationPathsForAccountNumber:(uint32_t)accountNumber {
    return @[[DSFundsDerivationPath bip32DerivationPathOnChain:self forAccountNumber:accountNumber],[DSFundsDerivationPath bip44DerivationPathOnChain:self forAccountNumber:accountNumber]];
}

-(void)save {
    [[DSChainEntity context] performBlockAndWait:^{
        self.chainEntity.totalMasternodeCount = self.totalMasternodeCount;
        self.chainEntity.totalGovernanceObjectsCount = self.totalGovernanceObjectsCount;
        self.chainEntity.baseBlockHash = [NSData dataWithUInt256:self.masternodeBaseBlockHash];
        [DSChainEntity saveContext];
    }];
}

-(NSString*)debugDescription {
    return [[super debugDescription] stringByAppendingString:[NSString stringWithFormat:@" {%@}",self.name]];
}

// MARK: - Check Type

-(BOOL)isMainnet {
    return [self chainType] == DSChainType_MainNet;
}
-(BOOL)isTestnet {
    return [self chainType] == DSChainType_TestNet;
}

-(BOOL)isDevnetAny {
    return [self chainType] == DSChainType_DevNet;
}

-(NSString*)uniqueID {
    if (!_uniqueID) {
        _uniqueID = [[NSData dataWithUInt256:[self genesisHash]] shortHexString];
    }
    return _uniqueID;
}

-(BOOL)isDevnetWithGenesisHash:(UInt256)genesisHash {
    if ([self chainType] != DSChainType_DevNet) {
        return false;
    } else {
        return uint256_eq([self genesisHash],genesisHash);
    }
}

-(uint32_t)magicNumber {
    switch (_chainType) {
        case DSChainType_MainNet:
            return AXE_MAGIC_NUMBER_MAINNET;
        case DSChainType_TestNet:
            return AXE_MAGIC_NUMBER_TESTNET;
        case DSChainType_DevNet:
            return AXE_MAGIC_NUMBER_DEVNET;
        default:
            return AXE_MAGIC_NUMBER_MAINNET;
            break;
    }
}

-(uint16_t)transactionVersion {
    switch (_chainType) {
        case DSChainType_MainNet:
            return 1;
        case DSChainType_TestNet:
            return 1;
        case DSChainType_DevNet:
            return 3;
        default:
            return 3;
            break;
    }
}

-(NSString*)chainWalletsKey {
    return [NSString stringWithFormat:@"%@_%@",CHAIN_WALLETS_KEY,[self uniqueID]];
}

-(NSString*)chainStandaloneDerivationPathsKey {
    return [NSString stringWithFormat:@"%@_%@",CHAIN_STANDALONE_DERIVATIONS_KEY,[self uniqueID]];
}

-(NSString*)registeredPeersKey {
    return [NSString stringWithFormat:@"%@_%@",REGISTERED_PEERS_KEY,[self uniqueID]];
}

-(NSString*)votingKeysKey {
    return [NSString stringWithFormat:@"%@_%@",CHAIN_VOTING_KEYS_KEY,[self uniqueID]];
}


// MARK: - Chain Parameters



-(uint32_t)protocolVersion {
    switch ([self chainType]) {
        case DSChainType_MainNet:
            return PROTOCOL_VERSION_MAINNET;
        case DSChainType_TestNet:
            return PROTOCOL_VERSION_TESTNET;
        case DSChainType_DevNet:
        {
            NSError * error = nil;
            uint32_t protocolVersion = (uint32_t)getKeychainInt([NSString stringWithFormat:@"%@%@",self.devnetIdentifier,PROTOCOL_VERSION_LOCATION], &error);
            if (!error && protocolVersion) return protocolVersion;
            else return PROTOCOL_VERSION_DEVNET;
        }
        default:
            break;
    }
}

-(void)setProtocolVersion:(uint32_t)protocolVersion
{
    switch ([self chainType]) {
        case DSChainType_MainNet:
            return;
        case DSChainType_TestNet:
            return;
        case DSChainType_DevNet:
        {
            setKeychainInt(protocolVersion,[NSString stringWithFormat:@"%@%@",self.devnetIdentifier,PROTOCOL_VERSION_LOCATION], NO);
            break;
        }
        default:
            break;
    }
}


-(uint32_t)minProtocolVersion {
    if (_cachedMinProtocolVersion) return _cachedMinProtocolVersion;
    switch ([self chainType]) {
        case DSChainType_MainNet:
        {
            NSError * error = nil;
            uint32_t minProtocolVersion = (uint32_t)getKeychainInt([NSString stringWithFormat:@"MAINNET_%@",DEFAULT_MIN_PROTOCOL_VERSION_LOCATION], &error);
            if (!error && minProtocolVersion) _cachedMinProtocolVersion = MAX(minProtocolVersion,DEFAULT_MIN_PROTOCOL_VERSION_MAINNET);
            else _cachedMinProtocolVersion = DEFAULT_MIN_PROTOCOL_VERSION_MAINNET;
            break;
        }
        case DSChainType_TestNet:
        {
            NSError * error = nil;
            uint32_t minProtocolVersion = (uint32_t)getKeychainInt([NSString stringWithFormat:@"TESTNET_%@",DEFAULT_MIN_PROTOCOL_VERSION_LOCATION], &error);
            if (!error && minProtocolVersion) _cachedMinProtocolVersion = MAX(minProtocolVersion,DEFAULT_MIN_PROTOCOL_VERSION_TESTNET);
            else _cachedMinProtocolVersion = DEFAULT_MIN_PROTOCOL_VERSION_TESTNET;
            break;
        }
        case DSChainType_DevNet:
        {
            NSError * error = nil;
            uint32_t minProtocolVersion = (uint32_t)getKeychainInt([NSString stringWithFormat:@"%@%@",self.devnetIdentifier,DEFAULT_MIN_PROTOCOL_VERSION_LOCATION], &error);
            if (!error && minProtocolVersion) _cachedMinProtocolVersion = MAX(minProtocolVersion,DEFAULT_MIN_PROTOCOL_VERSION_DEVNET);
            else _cachedMinProtocolVersion = DEFAULT_MIN_PROTOCOL_VERSION_DEVNET;
            break;
        }
        default:
            break;
    }
    return _cachedMinProtocolVersion;
}


-(void)setMinProtocolVersion:(uint32_t)minProtocolVersion
{
    if (minProtocolVersion < MIN_VALID_MIN_PROTOCOL_VERSION || minProtocolVersion > MAX_VALID_MIN_PROTOCOL_VERSION) return;
    switch ([self chainType]) {
        case DSChainType_MainNet:
            setKeychainInt(MAX(minProtocolVersion,DEFAULT_MIN_PROTOCOL_VERSION_MAINNET),[NSString stringWithFormat:@"MAINNET_%@",DEFAULT_MIN_PROTOCOL_VERSION_LOCATION], NO);
            _cachedMinProtocolVersion = MAX(minProtocolVersion,DEFAULT_MIN_PROTOCOL_VERSION_MAINNET);
            break;
        case DSChainType_TestNet:
            setKeychainInt(MAX(minProtocolVersion,DEFAULT_MIN_PROTOCOL_VERSION_TESTNET),[NSString stringWithFormat:@"TESTNET_%@",DEFAULT_MIN_PROTOCOL_VERSION_LOCATION], NO);
            _cachedMinProtocolVersion = MAX(minProtocolVersion,DEFAULT_MIN_PROTOCOL_VERSION_TESTNET);
            break;
        case DSChainType_DevNet:
        {
            setKeychainInt(MAX(minProtocolVersion,DEFAULT_MIN_PROTOCOL_VERSION_DEVNET),[NSString stringWithFormat:@"%@%@",self.devnetIdentifier,DEFAULT_MIN_PROTOCOL_VERSION_LOCATION], NO);
            _cachedMinProtocolVersion = MAX(minProtocolVersion,DEFAULT_MIN_PROTOCOL_VERSION_DEVNET);
            break;
        }
        default:
            break;
    }
}


-(uint32_t)maxProofOfWork {
    switch ([self chainType]) {
        case DSChainType_MainNet:
            return MAX_PROOF_OF_WORK_MAINNET;
        case DSChainType_TestNet:
            return MAX_PROOF_OF_WORK_TESTNET;
        case DSChainType_DevNet:
            return MAX_PROOF_OF_WORK_DEVNET;
        default:
            return MAX_PROOF_OF_WORK_MAINNET;
            break;
    }
}

-(BOOL)allowMinDifficultyBlocks {
    switch ([self chainType]) {
        case DSChainType_MainNet:
            return NO;
        case DSChainType_TestNet:
            return YES;
        case DSChainType_DevNet:
            return YES;
        default:
            return NO;
            break;
    }
}


-(NSString*)networkName {
    switch ([self chainType]) {
        case DSChainType_MainNet:
            return @"main";
            break;
        case DSChainType_TestNet:
            return @"test";
            break;
        case DSChainType_DevNet:
            if (_networkName) return _networkName;
            return @"dev";
            break;
        default:
            break;
    }
    if (_networkName) return _networkName;
}

-(NSString*)name {
    switch ([self chainType]) {
        case DSChainType_MainNet:
            return @"Mainnet";
            break;
        case DSChainType_TestNet:
            return @"Testnet";
            break;
        case DSChainType_DevNet:
            if (_networkName) return _networkName;
            return [@"Devnet - " stringByAppendingString:self.devnetIdentifier];
            break;
        default:
            break;
    }
    if (_networkName) return _networkName;
}

-(NSString*)localizedName {
    switch ([self chainType]) {
        case DSChainType_MainNet:
            return DSLocalizedString(@"Mainnet",nil);
            break;
        case DSChainType_TestNet:
            return DSLocalizedString(@"Testnet",nil);
            break;
        case DSChainType_DevNet:
            if (_networkName) return _networkName;
            return [NSString stringWithFormat:@"%@ - %@", DSLocalizedString(@"Devnet",nil),self.devnetIdentifier];
            break;
        default:
            break;
    }
    if (_networkName) return _networkName;
}

-(uint64_t)baseReward {
    if ([self chainType] == DSChainType_MainNet) return 5 * HAKS;
    return 50 * HAKS;
}

-(uint32_t)peerMisbehavingThreshold {
    switch ([self chainType]) {
        case DSChainType_MainNet:
            return 20;
            break;
        case DSChainType_TestNet:
            return 40;
            break;
        case DSChainType_DevNet:
            return 3;
            break;
        default:
            break;
    }
    return 20;
}

-(DSCheckpoint*)lastCheckpoint {
    return [[self checkpoints] lastObject];
}

-(NSString*)sporkPublicKey {
    switch ([self chainType]) {
        case DSChainType_MainNet:
            return SPORK_PUBLIC_KEY_MAINNET;
            break;
        case DSChainType_TestNet:
            return SPORK_PUBLIC_KEY_TESTNET;
            break;
        case DSChainType_DevNet:
        {
            NSError * error = nil;
            NSString * publicKey = getKeychainString([NSString stringWithFormat:@"%@%@",self.devnetIdentifier,SPORK_PUBLIC_KEY_LOCATION], &error);
            if (!error && publicKey) {
                return publicKey;
            } else {
                return nil;
            }
        }
        default:
            break;
    }
    return nil;
}

-(void)setSporkPublicKey:(NSString *)sporkPublicKey {
    switch ([self chainType]) {
        case DSChainType_MainNet:
            return;
        case DSChainType_TestNet:
            return;
        case DSChainType_DevNet:
        {
            setKeychainString(sporkPublicKey,[NSString stringWithFormat:@"%@%@",self.devnetIdentifier,SPORK_PUBLIC_KEY_LOCATION], NO);
        }
        default:
            break;
    }
}

-(NSString*)sporkPrivateKey {
    switch ([self chainType]) {
        case DSChainType_MainNet:
            return nil;
            break;
        case DSChainType_TestNet:
            return nil;
            break;
        case DSChainType_DevNet:
        {
            NSError * error = nil;
            NSString * publicKey = getKeychainString([NSString stringWithFormat:@"%@%@",self.devnetIdentifier,SPORK_PRIVATE_KEY_LOCATION], &error);
            if (!error && publicKey) {
                return publicKey;
            } else {
                return nil;
            }
        }
        default:
            break;
    }
    return nil;
}

-(void)setSporkPrivateKey:(NSString *)sporkPrivateKey {
    switch ([self chainType]) {
        case DSChainType_MainNet:
            return;
        case DSChainType_TestNet:
            return;
        case DSChainType_DevNet:
        {
            setKeychainString(sporkPrivateKey,[NSString stringWithFormat:@"%@%@",self.devnetIdentifier,SPORK_PRIVATE_KEY_LOCATION], YES);
        }
        default:
            break;
    }
}

-(NSString*)sporkAddress {
    switch ([self chainType]) {
        case DSChainType_MainNet:
            return SPORK_ADDRESS_MAINNET;
            break;
        case DSChainType_TestNet:
            return SPORK_ADDRESS_TESTNET;
            break;
        case DSChainType_DevNet:
        {
            NSError * error = nil;
            NSString * publicKey = getKeychainString([NSString stringWithFormat:@"%@%@",self.devnetIdentifier,SPORK_ADDRESS_LOCATION], &error);
            if (!error && publicKey) {
                return publicKey;
            } else {
                return nil;
            }
        }
        default:
            break;
    }
    return nil;
}

-(void)setSporkAddress:(NSString *)sporkAddress {
    switch ([self chainType]) {
        case DSChainType_MainNet:
            return;
        case DSChainType_TestNet:
            return;
        case DSChainType_DevNet:
        {
            setKeychainString(sporkAddress,[NSString stringWithFormat:@"%@%@",self.devnetIdentifier,SPORK_ADDRESS_LOCATION], NO);
        }
        default:
            break;
    }
}

// MARK: - Standalone Derivation Paths

-(DSAccount*)viewingAccount {
    if (_viewingAccount) return _viewingAccount;
    self.viewingAccount = [[DSAccount alloc] initAsViewOnlyWithDerivationPaths:@[] inContext:self.managedObjectContext];
    return _viewingAccount;
}

-(void)retrieveStandaloneDerivationPaths {
    NSError * error = nil;
    NSArray * standaloneIdentifiers = getKeychainArray(self.chainStandaloneDerivationPathsKey, &error);
    if (!error) {
        for (NSString * derivationPathIdentifier in standaloneIdentifiers) {
            DSDerivationPath * derivationPath = [[DSDerivationPath alloc] initWithExtendedPublicKeyIdentifier:derivationPathIdentifier onChain:self];
            
            if (derivationPath) {
                [self addStandaloneDerivationPath:derivationPath];
            }
        }
    }
}

-(void)unregisterAllStandaloneDerivationPaths {
    for (DSDerivationPath * standaloneDerivationPath in [self.viewingAccount.derivationPaths copy]) {
        [self unregisterStandaloneDerivationPath:standaloneDerivationPath];
    }
}

-(void)unregisterStandaloneDerivationPath:(DSDerivationPath*)derivationPath {
    NSError * error = nil;
    NSMutableArray * keyChainArray = [getKeychainArray(self.chainStandaloneDerivationPathsKey, &error) mutableCopy];
    if (!keyChainArray) return;
    [keyChainArray removeObject:derivationPath.standaloneExtendedPublicKeyUniqueID];
    setKeychainArray(keyChainArray, self.chainStandaloneDerivationPathsKey, NO);
    [self.viewingAccount removeDerivationPath:derivationPath];
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:DSChainStandaloneDerivationPathsDidChangeNotification object:nil userInfo:@{DSChainManagerNotificationChainKey:self}];
    });
}
-(void)addStandaloneDerivationPath:(DSDerivationPath*)derivationPath {
    [self.viewingAccount addDerivationPath:derivationPath];
}

- (void)registerStandaloneDerivationPath:(DSDerivationPath*)derivationPath
{
    if ([derivationPath isKindOfClass:[DSFundsDerivationPath class]] && ![self.viewingAccount.derivationPaths containsObject:(DSFundsDerivationPath*)derivationPath]) {
        [self addStandaloneDerivationPath:derivationPath];
    }
    NSError * error = nil;
    NSMutableArray * keyChainArray = [getKeychainArray(self.chainStandaloneDerivationPathsKey, &error) mutableCopy];
    if (!keyChainArray) keyChainArray = [NSMutableArray array];
    [keyChainArray addObject:derivationPath.standaloneExtendedPublicKeyUniqueID];
    setKeychainArray(keyChainArray, self.chainStandaloneDerivationPathsKey, NO);
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:DSChainStandaloneDerivationPathsDidChangeNotification object:nil userInfo:@{DSChainManagerNotificationChainKey:self}];
    });
}

-(NSArray*)standaloneDerivationPaths {
    return [self.viewingAccount derivationPaths];
}

// MARK: - Voting Keys

//-(NSData*)votingKeyForMasternode:(DSSimplifiedMasternodeEntry*)masternodeEntry {
//    NSError * error = nil;
//    NSDictionary * keyChainDictionary = getKeychainDict(self.votingKeysKey, &error);
//    NSData * votingKey = [keyChainDictionary objectForKey:masternodeEntry.uniqueID];
//    return votingKey;
//}
//
//-(NSArray*)registeredMasternodes {
//    NSError * error = nil;
//    NSDictionary * keyChainDictionary = getKeychainDict(self.votingKeysKey, &error);
//    DSChainManager * chainManager = [[DSChainsManager sharedInstance] chainManagerForChain:self];
//    NSMutableArray * registeredMasternodes = [NSMutableArray array];
//    for (NSData * providerRegistrationTransactionHash in keyChainDictionary) {
//        DSSimplifiedMasternodeEntry * masternode = [chainManager.masternodeManager masternodeHavingProviderRegistrationTransactionHash:providerRegistrationTransactionHash];
//        [registeredMasternodes addObject:masternode];
//    }
//    return [registeredMasternodes copy];
//}
//
//-(void)registerVotingKey:(NSData*)votingKey forMasternodeEntry:(DSSimplifiedMasternodeEntry*)masternodeEntry {
//    NSError * error = nil;
//    NSMutableDictionary * keyChainDictionary = [getKeychainDict(self.votingKeysKey, &error) mutableCopy];
//    if (!keyChainDictionary) keyChainDictionary = [NSMutableDictionary dictionary];
//    [keyChainDictionary setObject:votingKey forKey:[NSData dataWithUInt256:masternodeEntry.providerRegistrationTransactionHash]];
//    setKeychainDict([keyChainDictionary copy], self.votingKeysKey, YES);
//    NSManagedObjectContext * context = [DSSimplifiedMasternodeEntryEntity context];
//    [context performBlockAndWait:^{
//        [DSSimplifiedMasternodeEntryEntity setContext:context];
//        DSSimplifiedMasternodeEntryEntity * masternodeEntryEntity = masternodeEntry.simplifiedMasternodeEntryEntity;
//        masternodeEntryEntity.claimed = TRUE;
//        [DSSimplifiedMasternodeEntryEntity saveContext];
//    }];
//}

// MARK: - Probabilistic Filters

- (DSBloomFilter*)bloomFilterWithFalsePositiveRate:(double)falsePositiveRate withTweak:(uint32_t)tweak {
    NSMutableSet * allAddresses = [NSMutableSet set];
    NSMutableSet * allUTXOs = [NSMutableSet set];
    for (DSWallet * wallet in self.wallets) {
        // every time a new wallet address is added, the bloom filter has to be rebuilt, and each address is only used for
        // one transaction, so here we generate some spare addresses to avoid rebuilding the filter each time a wallet
        // transaction is encountered during the blockchain download
        [wallet registerAddressesWithGapLimit:SEQUENCE_GAP_LIMIT_INITIAL internal:NO];
        [wallet registerAddressesWithGapLimit:SEQUENCE_GAP_LIMIT_INITIAL internal:YES];
        NSSet *addresses = [wallet.allReceiveAddresses setByAddingObjectsFromSet:wallet.allChangeAddresses];
        [allAddresses addObjectsFromArray:[addresses allObjects]];
        [allUTXOs addObjectsFromArray:wallet.unspentOutputs];
        
        //we should also add the blockchain user public keys to the filter
        //[allAddresses addObjectsFromArray:[wallet blockchainUserAddresses]];
    }
    
    for (DSFundsDerivationPath * derivationPath in self.standaloneDerivationPaths) {
        [derivationPath registerAddressesWithGapLimit:SEQUENCE_GAP_LIMIT_INITIAL internal:NO];
        [derivationPath registerAddressesWithGapLimit:SEQUENCE_GAP_LIMIT_INITIAL internal:YES];
        NSArray *addresses = [derivationPath.allReceiveAddresses arrayByAddingObjectsFromArray:derivationPath.allChangeAddresses];
        [allAddresses addObjectsFromArray:addresses];
    }
    
    
    [self clearOrphans];
    
    DSUTXO o;
    NSData *d;
    NSUInteger i, elemCount = allAddresses.count + allUTXOs.count;
    NSMutableArray *inputs = [NSMutableArray new];
    
    for (DSWallet * wallet in self.wallets) {
        for (DSTransaction *tx in wallet.allTransactions) { // find TXOs spent within the last 100 blocks
            if (tx.blockHeight != TX_UNCONFIRMED && tx.blockHeight + 100 < self.lastBlockHeight) {
                //DSDLog(@"Not adding transaction %@ inputs to bloom filter",uint256_hex(tx.txHash));
                continue; // the transaction is confirmed for at least 100 blocks, then break
            }
            
            //DSDLog(@"Adding transaction %@ inputs to bloom filter",uint256_hex(tx.txHash));
            
            i = 0;
            
            for (NSValue *hash in tx.inputHashes) {
                [hash getValue:&o.hash];
                o.n = [tx.inputIndexes[i++] unsignedIntValue];
                
                DSTransaction *t = [wallet transactionForHash:o.hash];
                
                if (o.n < t.outputAddresses.count && [wallet containsAddress:t.outputAddresses[o.n]]) {
                    [inputs addObject:dsutxo_data(o)];
                    elemCount++;
                }
            }
        }
    }
    
    DSBloomFilter *filter = [[DSBloomFilter alloc] initWithFalsePositiveRate:falsePositiveRate
                                                             forElementCount:(elemCount < 200 ? 300 : elemCount + 100) tweak:tweak
                                                                       flags:BLOOM_UPDATE_ALL];
    
    for (NSString *addr in allAddresses) {// add addresses to watch for tx receiveing money to the wallet
        NSData *hash = addr.addressToHash160;
        
        if (hash && ! [filter containsData:hash]) [filter insertData:hash];
    }
    
    for (NSValue *utxo in allUTXOs) { // add UTXOs to watch for tx sending money from the wallet
        [utxo getValue:&o];
        d = dsutxo_data(o);
        if (! [filter containsData:d]) [filter insertData:d];
    }
    
    for (d in inputs) { // also add TXOs spent within the last 100 blocks
        if (! [filter containsData:d]) [filter insertData:d];
    }
    return filter;
}

// MARK: - Wallet

- (void)wipeBlockchainInfo {
    for (DSWallet * wallet in self.wallets) {
        [wallet wipeBlockchainInfo];
    }
    [self.viewingAccount wipeBlockchainInfo];
    self.bestBlockHeight = 0;
    _blocks = nil;
    _lastBlock = nil;
    [self setLastBlockHeightForRescan];
    [self.chainManager chainWasWiped:self];
}

-(void)wipeMasternodesInContext:(NSManagedObjectContext*)context {
    [DSChainEntity setContext:context];
    [DSSimplifiedMasternodeEntryEntity setContext:context];
    [DSLocalMasternodeEntity setContext:context];
    DSChainEntity * chainEntity = self.chainEntity;
    [DSLocalMasternodeEntity deleteAllOnChain:chainEntity];
    [DSSimplifiedMasternodeEntryEntity deleteAllOnChain:chainEntity];
    [DSQuorumEntryEntity deleteAllOnChain:chainEntity];
    [DSMasternodeListEntity deleteAllOnChain:chainEntity];
    [self.chainManager.masternodeManager wipeMasternodeInfo];
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:[NSString stringWithFormat:@"%@_%@",self.uniqueID,LAST_SYNCED_MASTERNODE_LIST]];
}

-(void)wipeWalletsAndDerivatives {
    [self unregisterAllWallets];
    [self unregisterAllStandaloneDerivationPaths];
    self.mWallets = [NSMutableArray array];
    self.viewingAccount = nil;
}

-(void)retrieveWallets {
    NSError * error = nil;
    NSArray * walletIdentifiers = getKeychainArray(self.chainWalletsKey, &error);
    if (!error && walletIdentifiers) {
        for (NSString * uniqueID in walletIdentifiers) {
            DSWallet * wallet = [[DSWallet alloc] initWithUniqueID:uniqueID forChain:self];
            [self addWallet:wallet];
            
        }
    }
}

-(BOOL)canConstructAFilter {
    return [self hasAStandaloneDerivationPath] || [self hasAWallet];
}

-(BOOL)hasAStandaloneDerivationPath {
    return !![self.viewingAccount.derivationPaths count];
}

-(BOOL)hasAWallet {
    return !![self.mWallets count];
}

-(BOOL)syncsBlockchain { //required for SPV wallets
    return !!([[DSOptionsManager sharedInstance] syncType] & DSSyncType_NeedsWalletSyncType);
}

-(void)unregisterAllWallets {
    for (DSWallet * wallet in [self.mWallets copy]) {
        [self unregisterWallet:wallet];
    }
}

-(void)unregisterWallet:(DSWallet*)wallet {
    NSAssert(wallet.chain == self, @"the wallet you are trying to remove is not on this chain");
    [wallet wipeBlockchainInfo];
    [wallet wipeWalletInfo];
    [self.mWallets removeObject:wallet];
    NSError * error = nil;
    NSMutableArray * keyChainArray = [getKeychainArray(self.chainWalletsKey, &error) mutableCopy];
    if (!keyChainArray) keyChainArray = [NSMutableArray array];
    [keyChainArray removeObject:wallet.uniqueID];
    setKeychainArray(keyChainArray, self.chainWalletsKey, NO);
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:DSChainWalletsDidChangeNotification object:nil userInfo:@{DSChainManagerNotificationChainKey:self}];
    });
}

-(void)addWallet:(DSWallet*)wallet {
    [self.mWallets addObject:wallet];
}

- (void)registerWallet:(DSWallet*)wallet
{
    BOOL firstWallet = !self.mWallets.count;
    if ([self.mWallets indexOfObject:wallet] == NSNotFound) {
        [self addWallet:wallet];
    }
    
    if (firstWallet) {
        //this is the first wallet, we should reset the last block height to the most recent checkpoint.
        _lastBlock = nil; //it will lazy load later
    }
    
    NSError * error = nil;
    NSMutableArray * keyChainArray = [getKeychainArray(self.chainWalletsKey, &error) mutableCopy];
    if (!keyChainArray) keyChainArray = [NSMutableArray array];
    if (![keyChainArray containsObject:wallet.uniqueID]) {
        [keyChainArray addObject:wallet.uniqueID];
        setKeychainArray(keyChainArray, self.chainWalletsKey, NO);
        dispatch_async(dispatch_get_main_queue(), ^{
            [[NSNotificationCenter defaultCenter] postNotificationName:DSChainWalletsDidChangeNotification object:nil userInfo:@{DSChainManagerNotificationChainKey:self}];
        });
    }
}

-(uint64_t)balance {
    uint64_t rBalance = 0;
    for (DSWallet * wallet in self.wallets) {
        rBalance += wallet.balance;
    }
    for (DSDerivationPath * standaloneDerivationPath in self.standaloneDerivationPaths) {
        rBalance += standaloneDerivationPath.balance;
    }
    return rBalance;
}

-(NSArray*)wallets {
    return [self.mWallets copy];
}

-(void)reloadDerivationPaths {
    for (DSWallet * wallet in self.mWallets) {
        [wallet reloadDerivationPaths];
    }
}

// This is a time interval since 1970
-(NSTimeInterval)earliestWalletCreationTime {
    if (![self.wallets count]) return BIP39_CREATION_TIME;
    NSTimeInterval timeInterval = [[NSDate date] timeIntervalSince1970];
    for (DSWallet * wallet in self.wallets) {
        if (timeInterval > wallet.walletCreationTime) {
            timeInterval = wallet.walletCreationTime;
        }
    }
    return timeInterval;
}


-(NSTimeInterval)startSyncFromTime {
    if ([self syncsBlockchain]) {
        return [self earliestWalletCreationTime];
    } else {
        return self.checkpoints.lastObject.timestamp;
    }
}

- (DSCheckpoint* _Nullable)lastCheckpointWithMasternodeList {
    NSSet * set = [self.checkpointsByHeightDictionary keysOfEntriesPassingTest:^BOOL(id  _Nonnull key, id  _Nonnull obj, BOOL * _Nonnull stop) {
        DSCheckpoint * checkpoint = (DSCheckpoint *)obj;
        return (checkpoint.masternodeListName && ![checkpoint.masternodeListName isEqualToString:@""]);
    }];
    NSArray * numbers = [[set allObjects] sortedArrayUsingSelector: @selector(compare:)];
    if (!numbers.count) return nil;
    return self.checkpointsByHeightDictionary[numbers.lastObject];
}

- (DSCheckpoint*)checkpointForBlockHash:(UInt256)blockHash {
    return [self.checkpointsByHashDictionary objectForKey:uint256_data(blockHash)];
}

- (DSCheckpoint*)checkpointForBlockHeight:(uint32_t)blockHeight {
    return [self.checkpointsByHeightDictionary objectForKey:@(blockHeight)];
}

-(NSDictionary*)recentBlocks {
    return [[self blocks] copy];
}

- (NSMutableDictionary *)blocks
{
    if (_blocks.count > 0) {
        if (!_checkpointsByHashDictionary) _checkpointsByHashDictionary = [NSMutableDictionary dictionary];
        if (!_checkpointsByHeightDictionary) _checkpointsByHeightDictionary = [NSMutableDictionary dictionary];
        return _blocks;
    }
    
    [[DSMerkleBlockEntity context] performBlockAndWait:^{
        if (self->_blocks.count > 0) return;
        self->_blocks = [NSMutableDictionary dictionary];
        self.checkpointsByHashDictionary = [NSMutableDictionary dictionary];
        self.checkpointsByHeightDictionary = [NSMutableDictionary dictionary];
        for (DSCheckpoint * checkpoint in self.checkpoints) { // add checkpoints to the block collection
            UInt256 checkpointHash = checkpoint.checkpointHash;
            
            self->_blocks[uint256_obj(checkpointHash)] = [[DSMerkleBlock alloc] initWithBlockHash:checkpointHash onChain:self version:1 prevBlock:UINT256_ZERO
                                                                                       merkleRoot:checkpoint.merkleRoot timestamp:checkpoint.timestamp
                                                                                           target:checkpoint.target nonce:0 totalTransactions:0 hashes:nil
                                                                                            flags:nil height:checkpoint.height];
            self.checkpointsByHeightDictionary[@(checkpoint.height)] = checkpoint;
            self.checkpointsByHashDictionary[uint256_data(checkpointHash)] = checkpoint;
        }
        self.delegateQueueChainEntity = [self chainEntity];
        for (DSMerkleBlockEntity *e in [DSMerkleBlockEntity lastBlocks:LLMQ_KEEP_RECENT_BLOCKS onChain:self.delegateQueueChainEntity]) {
            @autoreleasepool {
                DSMerkleBlock *b = e.merkleBlock;
                
                if (b) self->_blocks[uint256_obj(b.blockHash)] = b;
            }
        };
    }];
    
    return _blocks;
}

-(NSMutableDictionary*)checkpointsByHashDictionary {
    if (!_checkpointsByHashDictionary) [self blocks];
    return _checkpointsByHashDictionary;
}

-(NSMutableDictionary*)checkpointsByHeightDictionary {
    if (!_checkpointsByHeightDictionary) [self blocks];
    return _checkpointsByHeightDictionary;
}


// this is used as part of a getblocks or getheaders request
- (NSArray *)blockLocatorArray
{
    // append 10 most recent block checkpointHashes, decending, then continue appending, doubling the step back each time,
    // finishing with the genesis block (top, -1, -2, -3, -4, -5, -6, -7, -8, -9, -11, -15, -23, -39, -71, -135, ..., 0)
    NSMutableArray *locators = [NSMutableArray array];
    int32_t step = 1, start = 0;
    DSMerkleBlock *b = self.lastBlock;
    uint32_t lastHeight = b.height;
    while (b && b.height > 0) {
        [locators addObject:uint256_data(b.blockHash)];
        lastHeight = b.height;
        if (++start >= 10) step *= 2;
        
        for (int32_t i = 0; b && i < step; i++) {
            b = self.blocks[uint256_obj(b.prevBlock)];
        }
    }
    DSCheckpoint * lastCheckpoint;
    //then add the last checkpoint we know about previous to this block
    for (DSCheckpoint * checkpoint in self.checkpoints) {
        if (checkpoint.height < lastHeight) {
            lastCheckpoint = checkpoint;
        } else {
            break;
        }
    }
    [locators addObject:uint256_data(lastCheckpoint.checkpointHash)];
    return locators;
}

- (uint32_t)heightForBlockHash:(UInt256)blockhash {
    DSCheckpoint * checkpoint = [self.checkpointsByHashDictionary objectForKey:uint256_data(blockhash)];
    if (checkpoint) {
        return checkpoint.height;
    }
    
    DSMerkleBlock * block = [self.blocks objectForKey:uint256_obj(blockhash)];
    if (block && (block.height != UINT32_MAX)) {
        return block.height;
    }
    
    DSMerkleBlock *b = self.lastBlock;
    
    while (b && b.height > 0) {
        if (uint256_eq(b.blockHash, blockhash)) {
            return b.height;
        }
        b = self.blocks[uint256_obj(b.prevBlock)];
    }
    for (DSCheckpoint * checkpoint in self.checkpoints) {
        if (uint256_eq(checkpoint.checkpointHash, blockhash)) {
            return checkpoint.height;
        }
    }
    DSDLog(@"Requesting unknown blockhash %@ (it's probably being added asyncronously)",uint256_reverse_hex(blockhash));
    return UINT32_MAX;
}

- (DSMerkleBlock * _Nullable)blockForBlockHash:(UInt256)blockHash {
    return self.blocks[uint256_obj(blockHash)];
}

- (DSMerkleBlock *)blockAtHeight:(uint32_t)height {
    DSMerkleBlock *b = self.lastBlock;
    NSUInteger count = 0;
    while (b && b.height > height) {
        b = self.blocks[uint256_obj(b.prevBlock)];
        count++;
    }
    if (b.height != height) return nil;
    return b;
}

- (DSMerkleBlock *)blockFromChainTip:(NSUInteger)blocksAgo {
    DSMerkleBlock *b = self.lastBlock;
    NSUInteger count = 0;
    while (b && b.height > 0 && count < blocksAgo) {
        b = self.blocks[uint256_obj(b.prevBlock)];
        count++;
    }
    return b;
}

- (DSMerkleBlock *)lastBlock
{
    if (! _lastBlock) {
        [DSMerkleBlockEntity.context performBlockAndWait:^{
            NSArray * lastBlocks = [DSMerkleBlockEntity lastBlocks:1 onChain:self.chainEntity];
            DSMerkleBlock * lastBlock = [[lastBlocks firstObject] merkleBlock];
            self->_lastBlock = lastBlock;
            if (lastBlock) {
                DSDLog(@"last block at height %d recovered from db (hash is %@)",lastBlock.height,[NSData dataWithUInt256:lastBlock.blockHash].hexString);
            }
        }];

        if (!_lastBlock) {
            if ([[DSOptionsManager sharedInstance] syncFromGenesis]) {
                NSUInteger genesisHeight = [self isDevnetAny]?1:0;
                UInt256 checkpointHash = self.checkpoints[genesisHeight].checkpointHash;
                
                _lastBlock = self.blocks[uint256_obj(checkpointHash)];
                
            } else if ([[DSOptionsManager sharedInstance] shouldSyncFromHeight]) {
                // if we don't have any blocks yet, use the latest checkpoint that's at least a week older than earliestKeyTime
                for (long i = self.checkpoints.count - 1; ! _lastBlock && i >= 0; i--) {
                    if (i == 0 || ![self syncsBlockchain] || (self.checkpoints[i].height <= [[DSOptionsManager sharedInstance] syncFromHeight])) {
                        UInt256 checkpointHash = self.checkpoints[i].checkpointHash;
                        
                        _lastBlock = [[DSMerkleBlock alloc] initWithBlockHash:checkpointHash onChain:self version:1 prevBlock:UINT256_ZERO
                                                                   merkleRoot:self.checkpoints[i].merkleRoot timestamp:self.checkpoints[i].timestamp
                                                                       target:self.checkpoints[i].target nonce:0 totalTransactions:0 hashes:nil flags:nil
                                                                       height:self.checkpoints[i].height];
                    }
                }
            } else {
                NSTimeInterval startSyncTime = self.startSyncFromTime;
                NSUInteger genesisHeight = [self isDevnetAny]?1:0;
                // if we don't have any blocks yet, use the latest checkpoint that's at least a week older than earliestKeyTime
                for (long i = self.checkpoints.count - 1; ! _lastBlock && i >= genesisHeight; i--) {
                    if (i == genesisHeight || ![self syncsBlockchain] || (self.checkpoints[i].timestamp + WEEK_TIME_INTERVAL < startSyncTime)) {
                        UInt256 checkpointHash = self.checkpoints[i].checkpointHash;
                        
                        _lastBlock = [[DSMerkleBlock alloc] initWithBlockHash:checkpointHash onChain:self version:1 prevBlock:UINT256_ZERO
                                                                   merkleRoot:self.checkpoints[i].merkleRoot timestamp:self.checkpoints[i].timestamp
                                                                       target:self.checkpoints[i].target nonce:0 totalTransactions:0 hashes:nil flags:nil
                                                                       height:self.checkpoints[i].height];
                    }
                }
                if (_lastBlock) {
                    DSDLog(@"last block at height %d chosen from checkpoints (hash is %@)",_lastBlock.height,[NSData dataWithUInt256:_lastBlock.blockHash].hexString);
                }
            }
            
        }
        
        
        
        if (_lastBlock.height > self.estimatedBlockHeight) _bestEstimatedBlockHeight = _lastBlock.height;
    }
    
    return _lastBlock;
}

- (NSString*)chainTip {
    return [NSData dataWithUInt256:self.lastBlock.blockHash].shortHexString;
}

- (uint32_t)lastBlockHeight
{
    return self.lastBlock.height;
}

// seconds since reference date, 00:00:00 01/01/01 GMT
// NOTE: this is only accurate for the last two weeks worth of blocks, other timestamps are estimated from checkpoints
- (NSTimeInterval)timestampForBlockHeight:(uint32_t)blockHeight
{
    if (blockHeight == TX_UNCONFIRMED) return (self.lastBlock.timestamp) + 2.5*60; //next block
    
    if (blockHeight >= self.lastBlockHeight) { // future block, assume 2.5 minutes per block after last block
        return (self.lastBlock.timestamp) + (blockHeight - self.lastBlockHeight)*2.5*60;
    }
    
    if (_blocks.count > 0) {
        if (blockHeight >= self.lastBlockHeight - DGW_PAST_BLOCKS_MAX) { // recent block we have the header for
            DSMerkleBlock *block = self.lastBlock;
            
            while (block && block.height > blockHeight) block = self.blocks[uint256_obj(block.prevBlock)];
            if (block) return block.timestamp;
        }
    }
    else [[DSMerkleBlockEntity context] performBlock:^{ [self blocks]; }];
    
    uint32_t h = self.lastBlockHeight, t = self.lastBlock.timestamp;
    
    for (long i = self.checkpoints.count - 1; i >= 0; i--) { // estimate from checkpoints
        if (self.checkpoints[i].height <= blockHeight) {
            t = self.checkpoints[i].timestamp + (t - self.checkpoints[i].timestamp)*
            (blockHeight - self.checkpoints[i].height)/(h - self.checkpoints[i].height);
            return t;
        }
        
        h = self.checkpoints[i].height;
        t = self.checkpoints[i].timestamp;
    }
    
    return self.checkpoints[0].timestamp;
}

- (void)setBlockHeight:(int32_t)height andTimestamp:(NSTimeInterval)timestamp forTxHashes:(NSArray *)txHashes
{
    if (height != TX_UNCONFIRMED && height > self.bestBlockHeight) self.bestBlockHeight = height;
    NSMutableArray *updatedTx = [NSMutableArray array];
    if ([txHashes count]) {
        //need to reverify this works
        
        for (DSWallet * wallet in self.wallets) {
            [updatedTx addObjectsFromArray:[wallet setBlockHeight:height andTimestamp:timestamp
                                                      forTxHashes:txHashes]];
        }
    } else {
        for (DSWallet * wallet in self.wallets) {
            [wallet chainUpdatedBlockHeight:height];
        }
    }
    
    [self.chainManager chain:self didSetBlockHeight:height andTimestamp:timestamp forTxHashes:txHashes updatedTx:updatedTx];
}

- (BOOL)addBlock:(DSMerkleBlock *)block fromPeer:(DSPeer*)peer
{
    //DSDLog(@"a block %@",uint256_hex(block.blockHash));
    //All blocks will be added from same delegateQueue
    NSArray *txHashes = block.txHashes;
    
    NSValue *blockHash = uint256_obj(block.blockHash), *prevBlock = uint256_obj(block.prevBlock);
    DSMerkleBlock *prev = self.blocks[prevBlock];
    uint32_t txTime = 0;
    BOOL syncDone = NO;
    
    if (! prev) { // block is an orphan
#if LOG_PREV_BLOCKS_ON_ORPHAN
        NSSortDescriptor * sortDescriptor = [NSSortDescriptor sortDescriptorWithKey:@"height" ascending:TRUE];
        for (DSMerkleBlock * merkleBlock in [[self.blocks allValues] sortedArrayUsingDescriptors:@[sortDescriptor]]) {
            DSDLog(@"printing previous block at height %d : %@",merkleBlock.height,uint256_obj(merkleBlock.blockHash));
        }
#endif
        DSDLog(@"%@:%d relayed orphan block %@, previous %@, height %d, last block is %@, lastBlockHeight %d, time %@", peer.host, peer.port,
              uint256_reverse_hex(block.blockHash), uint256_reverse_hex(block.prevBlock), block.height, uint256_reverse_hex(self.lastBlock.blockHash), self.lastBlockHeight,[NSDate dateWithTimeIntervalSince1970:block.timestamp]);
        
        [self.chainManager chain:self receivedOrphanBlock:block fromPeer:peer];
        [peer receivedOrphanBlock];
        
        self.orphans[prevBlock] = block; // orphans are indexed by prevBlock instead of blockHash
        self.lastOrphan = block;
        return TRUE;
    }
    
    block.height = prev.height + 1;
    txTime = block.timestamp/2 + prev.timestamp/2;
    
    if ((block.height % 1000) == 0) { //free up some memory from time to time
        [self saveBlocks];
        DSMerkleBlock *b = block;
        
        for (uint32_t i = 0; b && i < LLMQ_KEEP_RECENT_BLOCKS; i++) {
            b = self.blocks[uint256_obj(b.prevBlock)];
        }
        NSMutableArray * blocksToRemove = [NSMutableArray array];
        while (b) { // free up some memory
            [blocksToRemove addObject:uint256_obj(b.blockHash)];
            b = self.blocks[uint256_obj(b.prevBlock)];
        }
        [self.blocks removeObjectsForKeys:blocksToRemove];
        //DSDLog(@"%lu blocks remaining",(unsigned long)[self.blocks count]);
    }
    
    // verify block difficulty if block is past last checkpoint
    DSCheckpoint * lastCheckpoint = [self lastCheckpoint];
    
    if (!self.isDevnetAny) {
        if ((block.height > (lastCheckpoint.height + DGW_PAST_BLOCKS_MAX)) &&
            ![block verifyDifficultyWithPreviousBlocks:self.blocks]) {
            uint32_t foundDifficulty = [block darkGravityWaveTargetWithPreviousBlocks:self.blocks];
            DSDLog(@"%@:%d relayed block with invalid difficulty height %d target %x foundTarget %x, blockHash: %@", peer.host, peer.port,
                  block.height,block.target,foundDifficulty, blockHash);
            [self.chainManager chain:self badBlockReceivedFromPeer:peer];
            return FALSE;
        }
    }
    
    DSCheckpoint * checkpoint = [self.checkpointsByHeightDictionary objectForKey:@(block.height)];

    // verify block chain checkpoints
    if (checkpoint && ! uint256_eq(block.blockHash, checkpoint.checkpointHash)) {
        DSDLog(@"%@:%d relayed a block that differs from the checkpoint at height %d, blockHash: %@, expected: %@",
              peer.host, peer.port, block.height, blockHash, uint256_hex(checkpoint.checkpointHash));
        [self.chainManager chain:self badBlockReceivedFromPeer:peer];
        return FALSE;
    }
    
    BOOL onMainChain = FALSE;
    
    if (uint256_eq(block.prevBlock, self.lastBlock.blockHash)) { // new block extends main chain
        if ((block.height % 500) == 0 || txHashes.count > 0 || block.height > peer.lastblock) {
            DSDLog(@"adding block on %@ at height: %d from peer %@", self.name, block.height,peer.host);
        }
        
        self.blocks[blockHash] = block;
        self.lastBlock = block;
        [self setBlockHeight:block.height andTimestamp:txTime forTxHashes:txHashes];
        peer.currentBlockHeight = block.height; //might be download peer instead
        if (block.height == self.estimatedBlockHeight) syncDone = YES;
        onMainChain = TRUE;
    }
    else if (self.blocks[blockHash] != nil) { // we already have the block (or at least the header)
        if ((block.height % 500) == 0 || txHashes.count > 0 || block.height > peer.lastblock) {
            DSDLog(@"%@:%d relayed existing block at height %d", peer.host, peer.port, block.height);
        }
        
        self.blocks[blockHash] = block;
        
        DSMerkleBlock *b = self.lastBlock;
        
        while (b && b.height > block.height) b = self.blocks[uint256_obj(b.prevBlock)]; // is block in main chain?
        
        if (b != nil && uint256_eq(b.blockHash, block.blockHash)) { // if it's not on a fork, set block heights for its transactions
            [self setBlockHeight:block.height andTimestamp:txTime forTxHashes:txHashes];
            if (block.height == self.lastBlockHeight) self.lastBlock = block;
        }
    }
    else { // new block is on a fork
        if (block.height <= [self lastCheckpoint].height) { // fork is older than last checkpoint
            DSDLog(@"ignoring block on fork older than most recent checkpoint, fork height: %d, blockHash: %@",
                  block.height, blockHash);
            return TRUE;
        }
        
        // special case, if a new block is mined while we're rescanning the chain, mark as orphan til we're caught up
        if (self.lastBlockHeight < peer.lastblock && block.height > self.lastBlockHeight + 1) {
            DSDLog(@"marking new block at height %d as orphan until rescan completes", block.height);
            self.orphans[prevBlock] = block;
            self.lastOrphan = block;
            return TRUE;
        }
        
        DSDLog(@"chain fork to height %d", block.height);
        self.blocks[blockHash] = block;
        if (block.height <= self.lastBlockHeight) return TRUE; // if fork is shorter than main chain, ignore it for now
        
        NSMutableArray *txHashes = [NSMutableArray array];
        DSMerkleBlock *b = block, *b2 = self.lastBlock;
        
        while (b && b2 && ! uint256_eq(b.blockHash, b2.blockHash)) { // walk back to where the fork joins the main chain
            b = self.blocks[uint256_obj(b.prevBlock)];
            if (b.height < b2.height) b2 = self.blocks[uint256_obj(b2.prevBlock)];
        }
        
        DSDLog(@"reorganizing chain from height %d, new height is %d", b.height, block.height);
        
        // mark transactions after the join point as unconfirmed
        for (DSWallet * wallet in self.wallets) {
            for (DSTransaction *tx in wallet.allTransactions) {
                if (tx.blockHeight <= b.height) break;
                [txHashes addObject:uint256_obj(tx.txHash)];
            }
        }
        
        [self setBlockHeight:TX_UNCONFIRMED andTimestamp:0 forTxHashes:txHashes];
        b = block;
        
        while (b.height > b2.height) { // set transaction heights for new main chain
            [self setBlockHeight:b.height andTimestamp:txTime forTxHashes:b.txHashes];
            b = self.blocks[uint256_obj(b.prevBlock)];
            txTime = b.timestamp/2 + ((DSMerkleBlock *)self.blocks[uint256_obj(b.prevBlock)]).timestamp/2;
        }
        
        self.lastBlock = block;
        if (block.height == self.estimatedBlockHeight) syncDone = YES;
    }
    
    //DSDLog(@"%@:%d added block at height %d target %x blockHash: %@", peer.host, peer.port,
    //      block.height,block.target, blockHash);
    
    if (syncDone) { // chain download is complete
        [self saveBlocks];
        [self.chainManager chainFinishedSyncingTransactionsAndBlocks:self fromPeer:peer onMainChain:onMainChain];
    }
    
    if (block.height > self.estimatedBlockHeight) {
        _bestEstimatedBlockHeight = block.height;
        [self saveBlocks];
        [self.chainManager chain:self wasExtendedWithBlock:block fromPeer:peer];
        
        // notify that transaction confirmations may have changed
        dispatch_async(dispatch_get_main_queue(), ^{
            [[NSNotificationCenter defaultCenter] postNotificationName:DSChainNewChainTipBlockNotification object:nil userInfo:@{DSChainManagerNotificationChainKey:self}];
            [[NSNotificationCenter defaultCenter] postNotificationName:DSChainBlocksDidChangeNotification object:nil userInfo:@{DSChainManagerNotificationChainKey:self}];
        });
    } else {
        dispatch_async(dispatch_get_main_queue(), ^{
            [[NSNotificationCenter defaultCenter] postNotificationName:DSChainBlocksDidChangeNotification object:nil userInfo:@{DSChainManagerNotificationChainKey:self}];
        });
    }
    
    // check if the next block was received as an orphan
    if (block == self.lastBlock && self.orphans[blockHash]) {
        DSMerkleBlock *b = self.orphans[blockHash];
        
        [self.orphans removeObjectForKey:blockHash];
        [self addBlock:b fromPeer:peer]; //used to be [self peer:peer relayedBlock:b]; (hopefully this works now)
    }
    return TRUE;
}

- (void)saveBlocks
{
    DSDLog(@"[DSChain] save blocks");
    NSMutableDictionary *blocks = [NSMutableDictionary dictionary];
    DSMerkleBlock *b = self.lastBlock;
    uint32_t startHeight = 0;
    while (b) {
        blocks[[NSData dataWithBytes:b.blockHash.u8 length:sizeof(UInt256)]] = b;
        startHeight = b.height;
        b = self.blocks[uint256_obj(b.prevBlock)];
    }
    
    [[DSMerkleBlockEntity context] performBlock:^{
        if ([[DSOptionsManager sharedInstance] keepHeaders]) {
            //only remove orphan chains
            NSArray<DSMerkleBlockEntity *> * recentOrphans = [DSMerkleBlockEntity objectsMatching:@"(chain == %@) && (height > %u) && !(blockHash in %@) ",self.delegateQueueChainEntity,startHeight,blocks.allKeys];
            if ([recentOrphans count])  DSDLog(@"%lu recent orphans will be removed from disk",(unsigned long)[recentOrphans count]);
            [DSMerkleBlockEntity deleteObjects:recentOrphans];
        } else {
            //remember to not delete blocks needed for quorums
            NSArray<DSMerkleBlockEntity *> * oldBlockHeaders = [DSMerkleBlockEntity objectsMatching:@"(chain == %@) && !(blockHash in %@) && (usedByQuorums.@count == 0) && masternodeList == NIL",self.delegateQueueChainEntity,blocks.allKeys];
            [DSMerkleBlockEntity deleteObjects:oldBlockHeaders];
        }
        
        for (DSMerkleBlockEntity *e in [DSMerkleBlockEntity objectsMatching:@"blockHash in %@",blocks.allKeys]) {
            @autoreleasepool {
                [e setAttributesFromBlock:blocks[e.blockHash] forChain:self.delegateQueueChainEntity];
                [blocks removeObjectForKey:e.blockHash];
            }
        }
        
        for (DSMerkleBlock *b in blocks.allValues) {
            @autoreleasepool {
                [[DSMerkleBlockEntity managedObject] setAttributesFromBlock:b forChain:self.delegateQueueChainEntity];
            }
        }
        
        [DSMerkleBlockEntity saveContext];
    }];
}

-(void)clearOrphans {
    [self.orphans removeAllObjects]; // clear out orphans that may have been received on an old filter
    self.lastOrphan = nil;
}

-(void)setLastBlockHeightForRescan {
    _lastBlock = nil;
    
    if ([[DSOptionsManager sharedInstance] syncFromGenesis]) {
        NSUInteger genesisHeight = [self isDevnetAny]?1:0;
        UInt256 checkpointHash = self.checkpoints[genesisHeight].checkpointHash;
        
        _lastBlock = self.blocks[uint256_obj(checkpointHash)];
    } else if ([[DSOptionsManager sharedInstance] shouldSyncFromHeight]) {
        // start the chain download from the most recent checkpoint that's before the height variable
        for (long i = self.checkpoints.count - 1; ! _lastBlock && i >= 0; i--) {
            if (i == 0 || (self.checkpoints[i].height <= [[DSOptionsManager sharedInstance] syncFromHeight])) {
                UInt256 checkpointHash = self.checkpoints[i].checkpointHash;
                
                _lastBlock = self.blocks[uint256_obj(checkpointHash)];
            }
        }
    } else {
        
        // start the chain download from the most recent checkpoint that's at least a week older than earliestKeyTime
        for (long i = self.checkpoints.count - 1; ! _lastBlock && i >= 0; i--) {
            if (i == 0 || (self.checkpoints[i].timestamp + WEEK_TIME_INTERVAL < self.startSyncFromTime)) {
                UInt256 checkpointHash = self.checkpoints[i].checkpointHash;
                
                _lastBlock = self.blocks[uint256_obj(checkpointHash)];
            }
        }
    }
}

-(uint32_t)estimatedBlockHeight {
    if (_bestEstimatedBlockHeight) return _bestEstimatedBlockHeight;
    uint32_t maxCount = 0;
    uint32_t tempBestEstimatedBlockHeight = 0;
    for (NSNumber * height in self.estimatedBlockHeights) {
        NSArray * announcers = self.estimatedBlockHeights[height];
        if (announcers.count > maxCount) {
            tempBestEstimatedBlockHeight = [height intValue];
        }
    }
    _bestEstimatedBlockHeight = tempBestEstimatedBlockHeight;
    return _bestEstimatedBlockHeight;
}

-(void)setEstimatedBlockHeight:(uint32_t)estimatedBlockHeight fromPeer:(DSPeer*)peer {
    _bestEstimatedBlockHeight = 0; //lazy loading
    
    //remove from other heights
    for (NSNumber * height in [self.estimatedBlockHeights copy]) {
        if ([height intValue] == estimatedBlockHeight) continue;
        NSMutableArray * announcers = self.estimatedBlockHeights[height];
        if ([announcers containsObject:peer]) {
            [announcers removeObject:peer];
        }
        if (![announcers count]) {
            if (self.estimatedBlockHeights[height]) {
                [self.estimatedBlockHeights removeObjectForKey:height];
            }
        }
    }
    if (![self estimatedBlockHeights][@(estimatedBlockHeight)]) {
        [self estimatedBlockHeights][@(estimatedBlockHeight)] = [NSMutableArray arrayWithObject:peer];
    } else {
        NSMutableArray * peersAnnouncingHeight = [self estimatedBlockHeights][@(estimatedBlockHeight)];
        if (![peersAnnouncingHeight containsObject:peer]) {
            [peersAnnouncingHeight addObject:peer];
        }
    }
}

-(void)removeEstimatedBlockHeightOfPeer:(DSPeer*)peer {
    for (NSNumber * height in [self.estimatedBlockHeights copy]) {
        NSMutableArray * announcers = self.estimatedBlockHeights[height];
        if ([announcers containsObject:peer]) {
            [announcers removeObject:peer];
        }
        if (![announcers count]) {
            if (self.estimatedBlockHeights[height]) {
                [self.estimatedBlockHeights removeObjectForKey:height];
            }
        }
        if ([self.estimatedBlockHeights count]) { //keep best estimate if no other peers reporting on estimate
            if ([height intValue] == _bestEstimatedBlockHeight) _bestEstimatedBlockHeight = 0;
        }
    }
}

- (DSTransaction *)transactionForHash:(UInt256)txHash returnWallet:(DSWallet**)rWallet {
    for (DSWallet * wallet in self.wallets) {
        DSTransaction * transaction = [wallet transactionForHash:txHash];
        if (transaction) {
            if (rWallet) *rWallet = wallet;
            return transaction;
        }
    }
    return nil;
}

- (DSTransaction *)transactionForHash:(UInt256)txHash {
    return [self transactionForHash:txHash returnWallet:nil];
}

- (DSAccount* _Nullable)firstAccountThatCanContainTransaction:(DSTransaction *)transaction {
    if (!transaction) return nil;
    for (DSWallet * wallet in self.wallets) {
        DSAccount * account = [wallet firstAccountThatCanContainTransaction:transaction];
        if (account) return account;
    }
    return nil;
}

- (NSArray*)accountsThatCanContainTransaction:(DSTransaction *)transaction {
    NSMutableArray * mArray = [NSMutableArray array];
    if (!transaction) return @[];
    for (DSWallet * wallet in self.wallets) {
        [mArray addObjectsFromArray:[wallet accountsThatCanContainTransaction:transaction]];
    }
    return [mArray copy];
}

- (DSAccount* _Nullable)accountContainingAddress:(NSString *)address {
    if (!address) return nil;
    for (DSWallet * wallet in self.wallets) {
        DSAccount * account = [wallet accountForAddress:address];
        if (account) return account;
    }
    return nil;
}

// returns an account to which the given transaction hash is associated with, no account if the transaction hash is not associated with the wallet
- (DSAccount * _Nullable)accountForTransactionHash:(UInt256)txHash transaction:(DSTransaction **)transaction wallet:(DSWallet **)wallet {
    for (DSWallet * lWallet in self.wallets) {
        for (DSAccount * account in lWallet.accounts) {
            DSTransaction * lTransaction = [account transactionForHash:txHash];
            if (lTransaction) {
                if (transaction) *transaction = lTransaction;
                if (wallet) *wallet = lWallet;
                return account;
            }
        }
    }
    return nil;
}

-(uint32_t)blockchainUsersCount {
    uint32_t blockchainUsersCount = 0;
    for (DSWallet * lWallet in self.wallets) {
        blockchainUsersCount += [lWallet blockchainUsers].count;
    }
    return blockchainUsersCount;
}

-(NSArray *) allTransactions {
    NSMutableArray * mArray = [NSMutableArray array];
    for (DSWallet * wallet in self.wallets) {
        [mArray addObjectsFromArray:wallet.allTransactions];
    }
    return mArray;
}

// fee that will be added for a transaction of the given size in bytes
- (uint64_t)feeForTxSize:(NSUInteger)size isInstant:(BOOL)isInstant inputCount:(NSInteger)inputCount
{
    uint64_t standardFee = size*TX_FEE_PER_B; // standard fee based on tx size
    if (isInstant) {
        if ([self canUseAutoLocksWithInputCount:inputCount]) {
            return standardFee;
        } else {
            return TX_FEE_PER_INPUT*inputCount;
        }
    } else {
        
#if (!!FEE_PER_KB_URL)
        uint64_t fee = ((size*self.feePerByte + 99)/100)*100; // fee using feePerByte, rounded up to nearest 100 satoshi
        return (fee > standardFee) ? fee : standardFee;
#else
        return standardFee;
#endif
        
    }
}

// outputs below this amount are uneconomical due to fees
- (uint64_t)minOutputAmount
{
    uint64_t amount = (TX_MIN_OUTPUT_AMOUNT*self.feePerByte + MIN_FEE_PER_B - 1)/MIN_FEE_PER_B;
    
    return (amount > TX_MIN_OUTPUT_AMOUNT) ? amount : TX_MIN_OUTPUT_AMOUNT;
}

- (BOOL)canUseAutoLocksWithInputCount:(NSInteger)inputCount
{
    const NSInteger AutoLocksMaximumInputCount = 4;
    DSSporkManager * sporkManager = [self chainManager].sporkManager;
    if (sporkManager && [sporkManager instantSendAutoLocks] && inputCount <= AutoLocksMaximumInputCount) {
        return YES;
    }
    else {
        return NO;
    }
}

- (BOOL)isEqual:(id)obj
{
    return self == obj || ([obj isKindOfClass:[DSChain class]] && uint256_eq([obj genesisHash], _genesisHash));
}

// MARK: - Registering special transactions

-(void)registerProviderRegistrationTransaction:(DSProviderRegistrationTransaction*)providerRegistrationTransaction {
    DSWallet * ownerWallet = [self walletHavingProviderOwnerAuthenticationHash:providerRegistrationTransaction.ownerKeyHash foundAtIndex:nil];
    DSWallet * votingWallet = [self walletHavingProviderVotingAuthenticationHash:providerRegistrationTransaction.votingKeyHash foundAtIndex:nil];
    DSWallet * operatorWallet = [self walletHavingProviderOperatorAuthenticationKey:providerRegistrationTransaction.operatorKey foundAtIndex:nil];
    DSWallet * holdingWallet = [self walletContainingMasternodeHoldingAddressForProviderRegistrationTransaction:providerRegistrationTransaction foundAtIndex:nil];
    DSAccount * account = [self accountContainingAddress:providerRegistrationTransaction.payoutAddress];
    [account registerTransaction:providerRegistrationTransaction];
    [ownerWallet.specialTransactionsHolder registerTransaction:providerRegistrationTransaction];
    [votingWallet.specialTransactionsHolder registerTransaction:providerRegistrationTransaction];
    [operatorWallet.specialTransactionsHolder registerTransaction:providerRegistrationTransaction];
    [holdingWallet.specialTransactionsHolder registerTransaction:providerRegistrationTransaction];
    
    if (ownerWallet) {
        DSAuthenticationKeysDerivationPath * ownerDerivationPath = [[DSDerivationPathFactory sharedInstance] providerOwnerKeysDerivationPathForWallet:ownerWallet];
        [ownerDerivationPath registerTransactionAddress:providerRegistrationTransaction.ownerAddress];
    }
    
    if (votingWallet) {
        DSAuthenticationKeysDerivationPath * votingDerivationPath = [[DSDerivationPathFactory sharedInstance] providerVotingKeysDerivationPathForWallet:votingWallet];
        [votingDerivationPath registerTransactionAddress:providerRegistrationTransaction.votingAddress];
    }
    
    if (operatorWallet) {
        DSAuthenticationKeysDerivationPath * operatorDerivationPath = [[DSDerivationPathFactory sharedInstance] providerOperatorKeysDerivationPathForWallet:operatorWallet];
        [operatorDerivationPath registerTransactionAddress:providerRegistrationTransaction.operatorAddress];
    }
    
    if (holdingWallet) {
        DSMasternodeHoldingsDerivationPath * holdingDerivationPath = [[DSDerivationPathFactory sharedInstance] providerFundsDerivationPathForWallet:holdingWallet];
        [holdingDerivationPath registerTransactionAddress:providerRegistrationTransaction.holdingAddress];
    }
}

-(void)registerProviderUpdateServiceTransaction:(DSProviderUpdateServiceTransaction*)providerUpdateServiceTransaction {
    DSWallet * providerRegistrationWallet = nil;
    DSTransaction * providerRegistrationTransaction = [self transactionForHash:providerUpdateServiceTransaction.providerRegistrationTransactionHash returnWallet:&providerRegistrationWallet];
    DSAccount * account = [self accountContainingAddress:providerUpdateServiceTransaction.payoutAddress];
    [account registerTransaction:providerUpdateServiceTransaction];
    if (providerRegistrationTransaction && providerRegistrationWallet) {
        [providerRegistrationWallet.specialTransactionsHolder registerTransaction:providerUpdateServiceTransaction];
    }
}

-(void)registerProviderUpdateRegistrarTransaction:(DSProviderUpdateRegistrarTransaction*)providerUpdateRegistrarTransaction {
    
    DSWallet * votingWallet = [self walletHavingProviderVotingAuthenticationHash:providerUpdateRegistrarTransaction.votingKeyHash foundAtIndex:nil];
    DSWallet * operatorWallet = [self walletHavingProviderOperatorAuthenticationKey:providerUpdateRegistrarTransaction.operatorKey foundAtIndex:nil];
    [votingWallet.specialTransactionsHolder registerTransaction:providerUpdateRegistrarTransaction];
    [operatorWallet.specialTransactionsHolder registerTransaction:providerUpdateRegistrarTransaction];
    DSWallet * providerRegistrationWallet = nil;
    DSTransaction * providerRegistrationTransaction = [self transactionForHash:providerUpdateRegistrarTransaction.providerRegistrationTransactionHash returnWallet:&providerRegistrationWallet];
    DSAccount * account = [self accountContainingAddress:providerUpdateRegistrarTransaction.payoutAddress];
    [account registerTransaction:providerUpdateRegistrarTransaction];
    if (providerRegistrationTransaction && providerRegistrationWallet) {
        [providerRegistrationWallet.specialTransactionsHolder registerTransaction:providerUpdateRegistrarTransaction];
    }
    
    if (votingWallet) {
        DSAuthenticationKeysDerivationPath * votingDerivationPath = [[DSDerivationPathFactory sharedInstance] providerVotingKeysDerivationPathForWallet:votingWallet];
        [votingDerivationPath registerTransactionAddress:providerUpdateRegistrarTransaction.votingAddress];
    }
    
    if (operatorWallet) {
        DSAuthenticationKeysDerivationPath * operatorDerivationPath = [[DSDerivationPathFactory sharedInstance] providerOperatorKeysDerivationPathForWallet:operatorWallet];
        [operatorDerivationPath registerTransactionAddress:providerUpdateRegistrarTransaction.operatorAddress];
    }
}

-(void)registerProviderUpdateRevocationTransaction:(DSProviderUpdateRevocationTransaction*)providerUpdateRevocationTransaction {
    DSWallet * providerRegistrationWallet = nil;
    DSTransaction * providerRegistrationTransaction = [self transactionForHash:providerUpdateRevocationTransaction.providerRegistrationTransactionHash returnWallet:&providerRegistrationWallet];
    if (providerRegistrationTransaction && providerRegistrationWallet) {
        [providerRegistrationWallet.specialTransactionsHolder registerTransaction:providerUpdateRevocationTransaction];
    }
}

-(void)registerBlockchainUserRegistrationTransaction:(DSBlockchainUserRegistrationTransaction*)blockchainUserRegistrationTransaction {
    DSWallet * blockchainUserWallet = [self walletHavingBlockchainUserAuthenticationHash:blockchainUserRegistrationTransaction.pubkeyHash foundAtIndex:nil];
    [blockchainUserWallet.specialTransactionsHolder registerTransaction:blockchainUserRegistrationTransaction];
    
    if (blockchainUserWallet) {
        DSAuthenticationKeysDerivationPath * blockchainUsersDerivationPath = [[DSDerivationPathFactory sharedInstance] blockchainUsersKeysDerivationPathForWallet:blockchainUserWallet];
        [blockchainUsersDerivationPath registerTransactionAddress:blockchainUserRegistrationTransaction.pubkeyAddress];
    }
}

-(void)registerBlockchainUserResetTransaction:(DSBlockchainUserResetTransaction*)blockchainUserResetTransaction {
    DSWallet * blockchainUserWallet = [self walletHavingBlockchainUserAuthenticationHash:blockchainUserResetTransaction.replacementPublicKeyHash foundAtIndex:nil];
    [blockchainUserWallet.specialTransactionsHolder registerTransaction:blockchainUserResetTransaction];
    DSWallet * blockchainUserRegistrationWallet = nil;
    DSTransaction * blockchainUserRegistrationTransaction = [self transactionForHash:blockchainUserResetTransaction.registrationTransactionHash returnWallet:&blockchainUserRegistrationWallet];
    if (blockchainUserRegistrationTransaction && blockchainUserRegistrationWallet && (blockchainUserWallet != blockchainUserRegistrationWallet)) {
        [blockchainUserRegistrationWallet.specialTransactionsHolder registerTransaction:blockchainUserResetTransaction];
    }
    
    if (blockchainUserWallet) {
        DSAuthenticationKeysDerivationPath * blockchainUsersDerivationPath = [[DSDerivationPathFactory sharedInstance] blockchainUsersKeysDerivationPathForWallet:blockchainUserWallet];
        [blockchainUsersDerivationPath registerTransactionAddress:blockchainUserResetTransaction.replacementAddress];
    }
}

-(void)registerBlockchainUserCloseTransaction:(DSBlockchainUserCloseTransaction*)blockchainUserCloseTransaction {
    DSWallet * blockchainUserRegistrationWallet = nil;
    DSTransaction * blockchainUserRegistrationTransaction = [self transactionForHash:blockchainUserCloseTransaction.registrationTransactionHash returnWallet:&blockchainUserRegistrationWallet];
    if (blockchainUserRegistrationTransaction && blockchainUserRegistrationWallet) {
        [blockchainUserRegistrationWallet.specialTransactionsHolder registerTransaction:blockchainUserCloseTransaction];
    }
}

-(void)registerBlockchainUserTopupTransaction:(DSBlockchainUserTopupTransaction*)blockchainUserTopupTransaction {
    DSWallet * blockchainUserRegistrationWallet = nil;
    DSTransaction * blockchainUserRegistrationTransaction = [self transactionForHash:blockchainUserTopupTransaction.registrationTransactionHash returnWallet:&blockchainUserRegistrationWallet];
    if (blockchainUserRegistrationTransaction && blockchainUserRegistrationWallet) {
        [blockchainUserRegistrationWallet.specialTransactionsHolder registerTransaction:blockchainUserTopupTransaction];
    }
}

-(void)registerTransition:(DSTransition*)transition {
    DSWallet * blockchainUserRegistrationWallet = nil;
    DSTransaction * blockchainUserRegistrationTransaction = [self transactionForHash:transition.registrationTransactionHash returnWallet:&blockchainUserRegistrationWallet];
    if (blockchainUserRegistrationTransaction && blockchainUserRegistrationWallet) {
        [blockchainUserRegistrationWallet.specialTransactionsHolder registerTransaction:transition];
    }
}

-(void)registerSpecialTransaction:(DSTransaction*)transaction {
    if ([transaction isKindOfClass:[DSProviderRegistrationTransaction class]]) {
        DSProviderRegistrationTransaction * providerRegistrationTransaction = (DSProviderRegistrationTransaction *)transaction;
        [self registerProviderRegistrationTransaction:providerRegistrationTransaction];
    } else if ([transaction isKindOfClass:[DSProviderUpdateServiceTransaction class]]) {
        DSProviderUpdateServiceTransaction * providerUpdateServiceTransaction = (DSProviderUpdateServiceTransaction *)transaction;
        [self registerProviderUpdateServiceTransaction:providerUpdateServiceTransaction];
    } else if ([transaction isKindOfClass:[DSProviderUpdateRegistrarTransaction class]]) {
        DSProviderUpdateRegistrarTransaction * providerUpdateRegistrarTransaction = (DSProviderUpdateRegistrarTransaction *)transaction;
        [self registerProviderUpdateRegistrarTransaction:providerUpdateRegistrarTransaction];
    } else if ([transaction isKindOfClass:[DSProviderUpdateRevocationTransaction class]]) {
        DSProviderUpdateRevocationTransaction * providerUpdateRevocationTransaction = (DSProviderUpdateRevocationTransaction *)transaction;
        [self registerProviderUpdateRevocationTransaction:providerUpdateRevocationTransaction];
    } else if ([transaction isKindOfClass:[DSBlockchainUserRegistrationTransaction class]]) {
        DSBlockchainUserRegistrationTransaction * blockchainUserRegistrationTransaction = (DSBlockchainUserRegistrationTransaction *)transaction;
        [self registerBlockchainUserRegistrationTransaction:blockchainUserRegistrationTransaction];
    } else if ([transaction isKindOfClass:[DSBlockchainUserResetTransaction class]]) {
        DSBlockchainUserResetTransaction * blockchainUserResetTransaction = (DSBlockchainUserResetTransaction *)transaction;
        [self registerBlockchainUserResetTransaction:blockchainUserResetTransaction];
    } else if ([transaction isKindOfClass:[DSBlockchainUserCloseTransaction class]]) {
        DSBlockchainUserCloseTransaction * blockchainUserCloseTransaction = (DSBlockchainUserCloseTransaction *)transaction;
        [self registerBlockchainUserCloseTransaction:blockchainUserCloseTransaction];
    } else if ([transaction isKindOfClass:[DSBlockchainUserTopupTransaction class]]) {
        DSBlockchainUserTopupTransaction * blockchainUserTopupTransaction = (DSBlockchainUserTopupTransaction *)transaction;
        [self registerBlockchainUserTopupTransaction:blockchainUserTopupTransaction];
    } else if ([transaction isKindOfClass:[DSTransition class]]) {
        DSTransition * transition = (DSTransition*)transaction;
        [self registerTransition:transition];
    }
}

// MARK: - Special Transactions

//Does the chain mat
-(BOOL)transactionHasLocalReferences:(DSTransaction*)transaction {
    if ([self firstAccountThatCanContainTransaction:transaction]) return TRUE;
    
    //PROVIDERS
    if ([transaction isKindOfClass:[DSProviderRegistrationTransaction class]]) {
        DSProviderRegistrationTransaction * providerRegistrationTransaction = (DSProviderRegistrationTransaction *)transaction;
        if ([self walletHavingProviderOwnerAuthenticationHash:providerRegistrationTransaction.ownerKeyHash foundAtIndex:nil]) return TRUE;
        if ([self walletHavingProviderVotingAuthenticationHash:providerRegistrationTransaction.votingKeyHash foundAtIndex:nil]) return TRUE;
        if ([self walletHavingProviderOperatorAuthenticationKey:providerRegistrationTransaction.operatorKey foundAtIndex:nil]) return TRUE;
        if ([self walletContainingMasternodeHoldingAddressForProviderRegistrationTransaction:providerRegistrationTransaction foundAtIndex:nil]) return TRUE;
        if ([self accountContainingAddress:providerRegistrationTransaction.payoutAddress]) return TRUE;
    } else if ([transaction isKindOfClass:[DSProviderUpdateServiceTransaction class]]) {
        DSProviderUpdateServiceTransaction * providerUpdateServiceTransaction = (DSProviderUpdateServiceTransaction *)transaction;
        if ([self transactionForHash:providerUpdateServiceTransaction.providerRegistrationTransactionHash]) return TRUE;
        if ([self accountContainingAddress:providerUpdateServiceTransaction.payoutAddress]) return TRUE;
    } else if ([transaction isKindOfClass:[DSProviderUpdateRegistrarTransaction class]]) {
        DSProviderUpdateRegistrarTransaction * providerUpdateRegistrarTransaction = (DSProviderUpdateRegistrarTransaction *)transaction;
        if ([self walletHavingProviderVotingAuthenticationHash:providerUpdateRegistrarTransaction.votingKeyHash foundAtIndex:nil]) return TRUE;
        if ([self walletHavingProviderOperatorAuthenticationKey:providerUpdateRegistrarTransaction.operatorKey foundAtIndex:nil]) return TRUE;
        if ([self transactionForHash:providerUpdateRegistrarTransaction.providerRegistrationTransactionHash]) return TRUE;
        if ([self accountContainingAddress:providerUpdateRegistrarTransaction.payoutAddress]) return TRUE;
    } else if ([transaction isKindOfClass:[DSProviderUpdateRevocationTransaction class]]) {
        DSProviderUpdateRevocationTransaction * providerUpdateRevocationTransaction = (DSProviderUpdateRevocationTransaction *)transaction;
        if ([self transactionForHash:providerUpdateRevocationTransaction.providerRegistrationTransactionHash]) return TRUE;
        
        //BLOCKCHAIN USERS
    } else if ([transaction isKindOfClass:[DSBlockchainUserRegistrationTransaction class]]) {
        DSBlockchainUserRegistrationTransaction * blockchainUserRegistrationTransaction = (DSBlockchainUserRegistrationTransaction *)transaction;
        if ([self walletHavingBlockchainUserAuthenticationHash:blockchainUserRegistrationTransaction.pubkeyHash foundAtIndex:nil]) return TRUE;
    } else if ([transaction isKindOfClass:[DSBlockchainUserResetTransaction class]]) {
        DSBlockchainUserResetTransaction * blockchainUserResetTransaction = (DSBlockchainUserResetTransaction *)transaction;
        if ([self walletHavingBlockchainUserAuthenticationHash:blockchainUserResetTransaction.replacementPublicKeyHash foundAtIndex:nil]) return TRUE;
        if ([self transactionForHash:blockchainUserResetTransaction.registrationTransactionHash]) return TRUE;
    } else if ([transaction isKindOfClass:[DSBlockchainUserCloseTransaction class]]) {
        DSBlockchainUserCloseTransaction * blockchainUserCloseTransaction = (DSBlockchainUserCloseTransaction *)transaction;
        if ([self transactionForHash:blockchainUserCloseTransaction.registrationTransactionHash]) return TRUE;
    } else if ([transaction isKindOfClass:[DSBlockchainUserTopupTransaction class]]) {
        DSBlockchainUserTopupTransaction * blockchainUserTopupTransaction = (DSBlockchainUserTopupTransaction *)transaction;
        if ([self transactionForHash:blockchainUserTopupTransaction.registrationTransactionHash]) return TRUE;
    }
    return FALSE;
}

-(void)triggerUpdatesForLocalReferences:(DSTransaction*)transaction {
    if ([transaction isKindOfClass:[DSProviderRegistrationTransaction class]]) {
        DSProviderRegistrationTransaction * providerRegistrationTransaction = (DSProviderRegistrationTransaction *)transaction;
        if ([self walletHavingProviderOwnerAuthenticationHash:providerRegistrationTransaction.ownerKeyHash foundAtIndex:nil] || [self walletHavingProviderVotingAuthenticationHash:providerRegistrationTransaction.votingKeyHash foundAtIndex:nil] || [self walletHavingProviderOperatorAuthenticationKey:providerRegistrationTransaction.operatorKey foundAtIndex:nil]) {
            [self.chainManager.masternodeManager localMasternodeFromProviderRegistrationTransaction:providerRegistrationTransaction save:TRUE];
        }
    } else if ([transaction isKindOfClass:[DSProviderUpdateServiceTransaction class]]) {
        DSProviderUpdateServiceTransaction * providerUpdateServiceTransaction = (DSProviderUpdateServiceTransaction *)transaction;
        DSLocalMasternode * localMasternode = [self.chainManager.masternodeManager localMasternodeHavingProviderRegistrationTransactionHash:providerUpdateServiceTransaction.providerRegistrationTransactionHash];
        [localMasternode updateWithUpdateServiceTransaction:providerUpdateServiceTransaction save:TRUE];
    } else if ([transaction isKindOfClass:[DSProviderUpdateRegistrarTransaction class]]) {
        DSProviderUpdateRegistrarTransaction * providerUpdateRegistrarTransaction = (DSProviderUpdateRegistrarTransaction *)transaction;
        DSLocalMasternode * localMasternode = [self.chainManager.masternodeManager localMasternodeHavingProviderRegistrationTransactionHash:providerUpdateRegistrarTransaction.providerRegistrationTransactionHash];
        [localMasternode updateWithUpdateRegistrarTransaction:providerUpdateRegistrarTransaction save:TRUE];
    } else if ([transaction isKindOfClass:[DSProviderUpdateRevocationTransaction class]]) {
        DSProviderUpdateRevocationTransaction * providerUpdateRevocationTransaction = (DSProviderUpdateRevocationTransaction *)transaction;
        DSLocalMasternode * localMasternode = [self.chainManager.masternodeManager localMasternodeHavingProviderRegistrationTransactionHash:providerUpdateRevocationTransaction.providerRegistrationTransactionHash];
        [localMasternode updateWithUpdateRevocationTransaction:providerUpdateRevocationTransaction save:TRUE];
    } else if ([transaction isKindOfClass:[DSBlockchainUserRegistrationTransaction class]]) {
        DSBlockchainUserRegistrationTransaction * blockchainUserRegistrationTransaction = (DSBlockchainUserRegistrationTransaction *)transaction;
        DSWallet * wallet = [self walletHavingBlockchainUserAuthenticationHash:blockchainUserRegistrationTransaction.pubkeyHash foundAtIndex:nil];
        if (wallet) {
            DSBlockchainUser * blockchainUser = [[DSBlockchainUser alloc] initWithBlockchainUserRegistrationTransaction:blockchainUserRegistrationTransaction];
            [wallet registerBlockchainUser:blockchainUser];
        }
    } else if ([transaction isKindOfClass:[DSBlockchainUserTopupTransaction class]]) {
        DSBlockchainUserTopupTransaction * blockchainUserTopupTransaction = (DSBlockchainUserTopupTransaction *)transaction;
        DSWallet * wallet;
        [self transactionForHash:blockchainUserTopupTransaction.registrationTransactionHash returnWallet:&wallet];
        DSBlockchainUser * blockchainUser = [wallet blockchainUserForRegistrationHash:blockchainUserTopupTransaction.registrationTransactionHash];
        [blockchainUser updateWithTopupTransaction:blockchainUserTopupTransaction save:TRUE];
    } else if ([transaction isKindOfClass:[DSBlockchainUserResetTransaction class]]) {
        DSBlockchainUserResetTransaction * blockchainUserResetTransaction = (DSBlockchainUserResetTransaction *)transaction;
        DSWallet * wallet;
        [self transactionForHash:blockchainUserResetTransaction.registrationTransactionHash returnWallet:&wallet];
        DSBlockchainUser * blockchainUser = [wallet blockchainUserForRegistrationHash:blockchainUserResetTransaction.registrationTransactionHash];
        [blockchainUser updateWithResetTransaction:blockchainUserResetTransaction save:TRUE];
    } else if ([transaction isKindOfClass:[DSBlockchainUserCloseTransaction class]]) {
        DSBlockchainUserCloseTransaction * blockchainUserCloseTransaction = (DSBlockchainUserCloseTransaction *)transaction;
        DSWallet * wallet;
        [self transactionForHash:blockchainUserCloseTransaction.registrationTransactionHash returnWallet:&wallet];
        DSBlockchainUser * blockchainUser = [wallet blockchainUserForRegistrationHash:blockchainUserCloseTransaction.registrationTransactionHash];
        [blockchainUser updateWithCloseTransaction:blockchainUserCloseTransaction save:TRUE];
    } else if ([transaction isKindOfClass:[DSTransition class]]) {
        DSTransition * transition = (DSTransition *)transaction;
        DSWallet * wallet;
        [self transactionForHash:transition.registrationTransactionHash returnWallet:&wallet];
        DSBlockchainUser * blockchainUser = [wallet blockchainUserForRegistrationHash:transition.registrationTransactionHash];
        [blockchainUser updateWithTransition:transition save:TRUE];
    }
}

- (void)updateAddressUsageOfSimplifiedMasternodeEntries:(NSArray*)simplifiedMasternodeEntries {
    for (DSSimplifiedMasternodeEntry * simplifiedMasternodeEntry in simplifiedMasternodeEntries) {
        NSString * votingAddress = simplifiedMasternodeEntry.votingAddress;
        NSString * operatorAddress = simplifiedMasternodeEntry.operatorAddress;
        for (DSWallet * wallet in self.wallets) {
            DSAuthenticationKeysDerivationPath * providerOperatorKeysDerivationPath = [[DSDerivationPathFactory sharedInstance] providerOperatorKeysDerivationPathForWallet:wallet];
            if ([providerOperatorKeysDerivationPath containsAddress:operatorAddress]) {
                [providerOperatorKeysDerivationPath registerTransactionAddress:operatorAddress];
            }
            DSAuthenticationKeysDerivationPath * providerVotingKeysDerivationPath = [[DSDerivationPathFactory sharedInstance] providerVotingKeysDerivationPathForWallet:wallet];
            if ([providerVotingKeysDerivationPath containsAddress:votingAddress]) {
                [providerVotingKeysDerivationPath registerTransactionAddress:votingAddress];
            }
        }
    }
}

// MARK: - Merging Wallets

- (DSWallet*)walletHavingBlockchainUserAuthenticationHash:(UInt160)blockchainUserAuthenticationHash foundAtIndex:(uint32_t*)rIndex {
    for (DSWallet * wallet in self.wallets) {
        NSUInteger index = [wallet indexOfBlockchainUserAuthenticationHash:blockchainUserAuthenticationHash];
        if (index != NSNotFound) {
            if (rIndex) *rIndex = (uint32_t)index;
            return wallet;
        }
    }
    if (rIndex) *rIndex = UINT32_MAX;
    return nil;
}

- (DSWallet*)walletHavingProviderVotingAuthenticationHash:(UInt160)votingAuthenticationHash foundAtIndex:(uint32_t*)rIndex {
    for (DSWallet * wallet in self.wallets) {
        NSUInteger index = [wallet indexOfProviderVotingAuthenticationHash:votingAuthenticationHash];
        if (index != NSNotFound) {
            if (rIndex) *rIndex = (uint32_t)index;
            return wallet;
        }
    }
    if (rIndex) *rIndex = UINT32_MAX;
    return nil;
}

- (DSWallet* _Nullable)walletHavingProviderOwnerAuthenticationHash:(UInt160)owningAuthenticationHash foundAtIndex:(uint32_t*)rIndex {
    for (DSWallet * wallet in self.wallets) {
        NSUInteger index = [wallet indexOfProviderOwningAuthenticationHash:owningAuthenticationHash];
        if (index != NSNotFound) {
            if (rIndex) *rIndex = (uint32_t)index;
            return wallet;
        }
    }
    if (rIndex) *rIndex = UINT32_MAX;
    return nil;
}

- (DSWallet* _Nullable)walletHavingProviderOperatorAuthenticationKey:(UInt384)providerOperatorAuthenticationKey foundAtIndex:(uint32_t*)rIndex {
    for (DSWallet * wallet in self.wallets) {
        NSUInteger index = [wallet indexOfProviderOperatorAuthenticationKey:providerOperatorAuthenticationKey];
        if (index != NSNotFound) {
            if (rIndex) *rIndex = (uint32_t)index;
            return wallet;
        }
    }
    if (rIndex) *rIndex = UINT32_MAX;
    return nil;
}

- (DSWallet* _Nullable)walletContainingMasternodeHoldingAddressForProviderRegistrationTransaction:(DSProviderRegistrationTransaction * _Nonnull)transaction foundAtIndex:(uint32_t*)rIndex {
    for (DSWallet * wallet in self.wallets) {
        for (NSString * outputAddresses in transaction.outputAddresses) {
            NSUInteger index = [wallet indexOfHoldingAddress:outputAddresses];
            if (index != NSNotFound) {
                if (rIndex) *rIndex = (uint32_t)index;
                return wallet;
            }
        }
    }
    if (rIndex) *rIndex = UINT32_MAX;
    return nil;
}

@end

@implementation DSCheckpoint

#pragma mark NSCoding

#define kHeightKey       @"Height"
#define kCheckpointHashKey      @"CheckpointHash"
#define kTimestampKey      @"Timestamp"
#define kTargetKey      @"Target"

+(DSCheckpoint*)genesisDevnetCheckpoint {
    DSCheckpoint * checkpoint = [DSCheckpoint new];
    checkpoint.checkpointHash = *(UInt256 *)[NSString stringWithCString:"000008ca1832a4baf228eb1553c03d3a2c8e02399550dd6ea8d65cec3ef23d2e" encoding:NSUTF8StringEncoding].hexToData.reverse.bytes;
    checkpoint.height = 0;
    checkpoint.timestamp = 1417713337;
    checkpoint.target = 0x207fffffu;
    return checkpoint;
}

-(instancetype)initWithHash:(UInt256)checkpointHash height:(uint32_t)height timestamp:(uint32_t)timestamp target:(uint32_t)target {
    if (! (self = [super init])) return nil;
    
    self.checkpointHash = checkpointHash;
    self.height = height;
    self.timestamp = timestamp;
    self.target = target;
    
    return self;
}

- (id)initWithCoder:(NSCoder *)decoder {
    UInt256 checkpointHash = [decoder decodeUInt256ForKey:kCheckpointHashKey];
    uint32_t height = [decoder decodeInt32ForKey:kHeightKey];
    uint32_t timestamp = [decoder decodeInt32ForKey:kTimestampKey];
    uint32_t target = [decoder decodeInt32ForKey:kTargetKey];
    return [self initWithHash:checkpointHash height:height timestamp:timestamp target:target];
}

-(DSMerkleBlock*)merkleBlockForChain:(DSChain*)chain {
    return [[DSMerkleBlock alloc] initWithBlockHash:self.checkpointHash onChain:chain version:1 prevBlock:UINT256_ZERO
                                  merkleRoot:self.merkleRoot timestamp:self.timestamp
                                      target:self.target nonce:0 totalTransactions:0 hashes:nil
                                       flags:nil height:self.height];
}

-(void)encodeWithCoder:(NSCoder *)aCoder {
    [aCoder encodeUInt256:self.checkpointHash forKey:kCheckpointHashKey];
    [aCoder encodeInt32:self.height forKey:kHeightKey];
    [aCoder encodeInt32:self.timestamp forKey:kTimestampKey];
    [aCoder encodeInt32:self.target forKey:kTargetKey];
}

@end
