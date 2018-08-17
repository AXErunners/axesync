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
#import "DSChainPeerManager.h"
#import "DSChainEntity+CoreDataClass.h"
#import "NSCoder+Axe.h"
#import "DSAccount.h"
#import "DSBIP39Mnemonic.h"
#import "DSDerivationPath.h"
#import "DSOptionsManager.h"
#import "DSMasternodeBroadcast.h"
#import "DSChainManager.h"
#import "DSMasternodeManager.h"
#import "DSDerivationPathEntity+CoreDataProperties.h"
#import "NSMutableData+Axe.h"
#import "NSData+Axe.h"
#import "DSMasternodeBroadcastEntity+CoreDataClass.h"

typedef const struct checkpoint { uint32_t height; const char *checkpointHash; uint32_t timestamp; uint32_t target; } checkpoint;

static checkpoint testnet_checkpoint_array[] = {
    {           0, "00000381388b90aff350a4d5913d4a50fed79159a3a687470e01ca1527e87568", 1518140232, 0x1e0ffff0u }
};

// blockchain checkpoints - these are also used as starting points for partial chain downloads, so they need to be at
// difficulty transition boundaries in order to verify the block difficulty at the immediately following transition
static checkpoint mainnet_checkpoint_array[] = {
    {      0, "00000c33631ca6f2f61368991ce2dc03306b5bb50bf7cede5cfbba6db38e52e6", 1518140231, 0x1e0ffff0u },
    {   1500, "000000d671ea75d2a5578862393e04c29d2368c7461f65f278e083b13696408e", 1518237227, 0x1e018c18u },
    {   4991, "0000002d9b0d76fd076b4a6f2601f130ad7e2b43af92b8ffd2619f20478b01f2", 1518745517, 0x1e015880u },
    {   9918, "00000000007a7f636d5075eba76dfe76fbe1d865890aa0a8620406e8cb937a78", 1518778918, 0x1c00ea5bu },
    {  16912, "00000000000991c08af937ad98e3821a2fdc31dd636ce14c6597fb7820359749", 1519722114, 0x1b140cb3u },
    {  23912, "000000000024573fae6b7e7561d931499d6abaddb9f2dff608ec693a34366b7f", 1520831809, 0x1b278e64u },
    {  35457, "000000000013e6af48c778097fb5dc4b081ff9736bb8b74afcd67cf41b102111", 1522654685, 0x1b16e6e2u },
    {  45479, "00000000002027c4ba5b4d1f5e451fd400d5bdd58b282ddd7a865a2ce76514c0", 1524238915, 0x1b3492e9u },
    {  55895, "000000000035b29b53977dd38d7d09ea14749b5b5c6facf2d4f25c0abb9d864f", 1525888713, 0x1b7fd3f8u },
    {  68899, "000000000005376de272e4d5b3b50f165d2ac57911d74b04f77018a9247d18a7", 1527946299, 0x1b22526au },
    {  74619, "000000000030bc1f7703071874e3f1acf575b8aec566b36285e3e92248314da5", 1528853284, 0x1b313fb7u },
    {  75095, "0000000000312041338e175624468d089f95e55a3525b1be27d21ee1c6533d09", 1528929084, 0x1b347da4u },
    {  88805, "000000000023fb96f9bcb53f5637b06972bb7431b9fcf4198dc90f46a83d26ae", 1531095233, 0x1b4737e8u },
    { 107996, "00000000000c20ee519d77edf18652fc61c86301e57bedc1623c10da48b329d0", 1534123375, 0x1b0cc534u }
};

#define FEE_PER_KB_KEY          @"FEE_PER_KB"

#define CHAIN_WALLETS_KEY  @"CHAIN_WALLETS_KEY"
#define CHAIN_STANDALONE_DERIVATIONS_KEY  @"CHAIN_STANDALONE_DERIVATIONS_KEY"
#define REGISTERED_PEERS_KEY  @"REGISTERED_PEERS_KEY"

#define PROTOCOL_VERSION_LOCATION  @"PROTOCOL_VERSION_LOCATION"
#define MIN_PROTOCOL_VERSION_LOCATION  @"MIN_PROTOCOL_VERSION_LOCATION"

#define SPORK_PUBLIC_KEY_LOCATION  @"SPORK_PUBLIC_KEY_LOCATION"
#define SPORK_ADDRESS_LOCATION  @"SPORK_ADDRESS_LOCATION"
#define SPORK_PRIVATE_KEY_LOCATION  @"SPORK_PRIVATE_KEY_LOCATION"

#define CHAIN_VOTING_KEYS_KEY  @"CHAIN_VOTING_KEYS_KEY"


@interface DSChain ()

@property (nonatomic, strong) DSMerkleBlock *lastBlock, *lastOrphan;
@property (nonatomic, strong) NSMutableDictionary *blocks, *orphans,*checkpointsDictionary;
@property (nonatomic, strong) NSArray<DSCheckpoint*> * checkpoints;
@property (nonatomic, copy) NSString * uniqueID;
@property (nonatomic, copy) NSString * networkName;
@property (nonatomic, strong) NSMutableArray<DSWallet *> * mWallets;
@property (nonatomic, strong) DSChainEntity * mainThreadChainEntity;
@property (nonatomic, strong) DSChainEntity * delegateQueueChainEntity;
@property (nonatomic, strong) NSString * devnetIdentifier;
@property (nonatomic, strong) DSAccount * viewingAccount;

@end

@implementation DSChain

// MARK: - Creation, Setup and Getting a Chain

-(instancetype)init {
    if (! (self = [super init])) return nil;
    NSAssert([NSThread isMainThread], @"Chains should only be created on main thread (for chain entity optimizations)");
    self.orphans = [NSMutableDictionary dictionary];
    self.genesisHash = self.checkpoints[0].checkpointHash;
    self.mWallets = [NSMutableArray array];

    self.feePerKb = DEFAULT_FEE_PER_KB;
    uint64_t feePerKb = [[NSUserDefaults standardUserDefaults] doubleForKey:FEE_PER_KB_KEY];
    if (feePerKb >= MIN_FEE_PER_KB && feePerKb <= MAX_FEE_PER_KB) self.feePerKb = feePerKb;
    return self;
}

- (instancetype)initWithType:(DSChainType)type checkpoints:(NSArray*)checkpoints port:(uint32_t)port
{
    if (! (self = [self init])) return nil;
    _chainType = type;
    self.checkpoints = checkpoints;
    self.genesisHash = self.checkpoints[0].checkpointHash;
    self.standardPort = port;
    self.mainThreadChainEntity = [self chainEntity];
    [self retrieveWallets];
    [self retrieveStandaloneDerivationPaths];
    return self;
}


-(instancetype)initAsDevnetWithIdentifier:(NSString*)identifier checkpoints:(NSArray<DSCheckpoint*>*)checkpoints port:(uint32_t)port
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
//    NSLog(@"%@",[NSData dataWithUInt256:self.checkpoints[0].checkpointHash]);
//    NSLog(@"%@",[NSData dataWithUInt256:self.genesisHash]);
    self.standardPort = port;
    self.devnetIdentifier = identifier;
    self.mainThreadChainEntity = [self chainEntity];
    [self retrieveWallets];
    [self retrieveStandaloneDerivationPaths];
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

+(DSChain*)mainnet {
    static DSChain* _mainnet = nil;
    static dispatch_once_t mainnetToken = 0;
    __block BOOL inSetUp = FALSE;
    dispatch_once(&mainnetToken, ^{
        _mainnet = [[DSChain alloc] initWithType:DSChainType_MainNet checkpoints:[DSChain createCheckpointsArrayFromCheckpoints:mainnet_checkpoint_array count:(sizeof(mainnet_checkpoint_array)/sizeof(*mainnet_checkpoint_array))] port:MAINNET_STANDARD_PORT];

        inSetUp = TRUE;
        //NSLog(@"%@",[NSData dataWithUInt256:_mainnet.checkpoints[0].checkpointHash]);
    });
    if (inSetUp) {
        [[DSChainEntity context] performBlockAndWait:^{
            DSChainEntity * chainEntity = [_mainnet chainEntity];
            _mainnet.totalMasternodeCount = chainEntity.totalMasternodeCount;
            _mainnet.totalGovernanceObjectsCount = chainEntity.totalGovernanceObjectsCount;
        }];
    }

    return _mainnet;
}

+(DSChain*)testnet {
    static DSChain* _testnet = nil;
    static dispatch_once_t testnetToken = 0;
    __block BOOL inSetUp = FALSE;
    dispatch_once(&testnetToken, ^{
        _testnet = [[DSChain alloc] initWithType:DSChainType_TestNet checkpoints:[DSChain createCheckpointsArrayFromCheckpoints:testnet_checkpoint_array count:(sizeof(testnet_checkpoint_array)/sizeof(*testnet_checkpoint_array))] port:TESTNET_STANDARD_PORT];
        inSetUp = TRUE;
    });
    if (inSetUp) {
        [[DSChainEntity context] performBlockAndWait:^{
            DSChainEntity * chainEntity = [_testnet chainEntity];
            _testnet.totalMasternodeCount = chainEntity.totalMasternodeCount;
            _testnet.totalGovernanceObjectsCount = chainEntity.totalGovernanceObjectsCount;
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

+(DSChain*)setUpDevnetWithIdentifier:(NSString*)identifier withCheckpoints:(NSArray<DSCheckpoint*>*)checkpointArray withDefaultPort:(uint32_t)port {
    dispatch_once(&devnetToken, ^{
        _devnetDictionary = [NSMutableDictionary dictionary];
    });
    DSChain * devnetChain = nil;
    @synchronized(self) {
        if (![_devnetDictionary objectForKey:identifier]) {
            devnetChain = [[DSChain alloc] initAsDevnetWithIdentifier:identifier checkpoints:checkpointArray port:port];
            [_devnetDictionary setObject:devnetChain forKey:identifier];
        } else {
            devnetChain = [_devnetDictionary objectForKey:identifier];
        }
    }
    return devnetChain;
}

+(DSChain*)chainForNetworkName:(NSString*)networkName {
    if ([networkName isEqualToString:@"main"] || [networkName isEqualToString:@"live"] || [networkName isEqualToString:@"livenet"] || [networkName isEqualToString:@"mainnet"]) return [self mainnet];
    if ([networkName isEqualToString:@"test"] || [networkName isEqualToString:@"testnet"]) return [self testnet];
    return nil;
}

-(NSArray<DSDerivationPath*>*)standardDerivationPathsForAccountNumber:(uint32_t)accountNumber {
    return @[[DSDerivationPath bip32DerivationPathOnChain:self forAccountNumber:accountNumber],[DSDerivationPath bip44DerivationPathOnChain:self forAccountNumber:accountNumber]];
}

-(void)save {
    [[DSChainEntity context] performBlockAndWait:^{
        self.chainEntity.totalMasternodeCount = self.totalMasternodeCount;
        self.chainEntity.totalGovernanceObjectsCount = self.totalGovernanceObjectsCount;
        [DSChainEntity saveContext];
    }];
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
        }
        default:
            break;
    }
}


-(uint32_t)minProtocolVersion {
    switch ([self chainType]) {
        case DSChainType_MainNet:
            return MIN_PROTOCOL_VERSION_MAINNET;
        case DSChainType_TestNet:
            return MIN_PROTOCOL_VERSION_TESTNET;
        case DSChainType_DevNet:
        {
            NSError * error = nil;
            uint32_t minProtocolVersion = (uint32_t)getKeychainInt([NSString stringWithFormat:@"%@%@",self.devnetIdentifier,MIN_PROTOCOL_VERSION_LOCATION], &error);
            if (!error && minProtocolVersion) return minProtocolVersion;
            else return MIN_PROTOCOL_VERSION_DEVNET;
        }
        default:
            break;
    }
}


-(void)setMinProtocolVersion:(uint32_t)minProtocolVersion
{
    switch ([self chainType]) {
        case DSChainType_MainNet:
            return;
        case DSChainType_TestNet:
            return;
        case DSChainType_DevNet:
        {
            setKeychainInt(minProtocolVersion,[NSString stringWithFormat:@"%@%@",self.devnetIdentifier,MIN_PROTOCOL_VERSION_LOCATION], NO);
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

-(uint64_t)baseReward {
    if ([self chainType] == DSChainType_MainNet) return 5 * DUFFS;
    return 50 * DUFFS;
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
    self.viewingAccount = [[DSAccount alloc] initAsViewOnlyWithDerivationPaths:@[]];
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
        [[NSNotificationCenter defaultCenter] postNotificationName:DSChainStandaloneDerivationPathsDidChangeNotification object:nil userInfo:@{DSChainPeerManagerNotificationChainKey:self}];
    });
}
-(void)addStandaloneDerivationPath:(DSDerivationPath*)derivationPath {
    [self.viewingAccount addDerivationPath:derivationPath];
}

- (void)registerStandaloneDerivationPath:(DSDerivationPath*)derivationPath
{
    if (![self.viewingAccount.derivationPaths containsObject:derivationPath]) {
        [self addStandaloneDerivationPath:derivationPath];
    }
    NSError * error = nil;
    NSMutableArray * keyChainArray = [getKeychainArray(self.chainStandaloneDerivationPathsKey, &error) mutableCopy];
    if (!keyChainArray) keyChainArray = [NSMutableArray array];
    [keyChainArray addObject:derivationPath.standaloneExtendedPublicKeyUniqueID];
    setKeychainArray(keyChainArray, self.chainStandaloneDerivationPathsKey, NO);
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:DSChainStandaloneDerivationPathsDidChangeNotification object:nil userInfo:@{DSChainPeerManagerNotificationChainKey:self}];
    });
}

-(NSArray*)standaloneDerivationPaths {
    return [self.viewingAccount derivationPaths];
}

// MARK: - Voting Keys

-(NSData*)votingKeyForMasternodeBroadcast:(DSMasternodeBroadcast*)masternodeBroadcast {
    NSError * error = nil;
    NSDictionary * keyChainDictionary = getKeychainDict(self.votingKeysKey, &error);
    NSData * votingKey = [keyChainDictionary objectForKey:masternodeBroadcast.uniqueID];
    return votingKey;
}

-(NSArray*)registeredMasternodes {
    NSError * error = nil;
    NSDictionary * keyChainDictionary = getKeychainDict(self.votingKeysKey, &error);
    DSChainPeerManager * chainPeerManager = [[DSChainManager sharedInstance] peerManagerForChain:self];
    NSMutableArray * registeredMasternodes = [NSMutableArray array];
    for (NSString * key in keyChainDictionary) {
        DSMasternodeBroadcast * masternodeBroadcast = [chainPeerManager.masternodeManager masternodeBroadcastForUniqueID:key];
        [registeredMasternodes addObject:masternodeBroadcast];
    }
    return [registeredMasternodes copy];
}

-(void)registerVotingKey:(NSData*)votingKey forMasternodeBroadcast:(DSMasternodeBroadcast*)masternodeBroadcast {
    NSError * error = nil;
    NSMutableDictionary * keyChainDictionary = [getKeychainDict(self.votingKeysKey, &error) mutableCopy];
    if (!keyChainDictionary) keyChainDictionary = [NSMutableDictionary dictionary];
    [keyChainDictionary setObject:votingKey forKey:masternodeBroadcast.uniqueID];
    setKeychainDict([keyChainDictionary copy], self.votingKeysKey, YES);
    NSManagedObjectContext * context = [DSMasternodeBroadcastEntity context];
    [context performBlockAndWait:^{
        [DSMasternodeBroadcastEntity setContext:context];
        DSMasternodeBroadcastEntity * masternodeBroadcastEntity = masternodeBroadcast.masternodeBroadcastEntity;
        masternodeBroadcastEntity.claimed = TRUE;
        [DSMasternodeBroadcastEntity saveContext];
    }];
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
    [self.peerManagerDelegate chainWasWiped:self];
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
    if (!error) {
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
    [self.mWallets removeObject:wallet];
    NSError * error = nil;
    NSMutableArray * keyChainArray = [getKeychainArray(self.chainWalletsKey, &error) mutableCopy];
    if (!keyChainArray) keyChainArray = [NSMutableArray array];
    [keyChainArray removeObject:wallet.uniqueID];
    setKeychainArray(keyChainArray, self.chainWalletsKey, NO);
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:DSChainWalletsDidChangeNotification object:nil userInfo:@{DSChainPeerManagerNotificationChainKey:self}];
    });
}
-(void)addWallet:(DSWallet*)wallet {
    [self.mWallets addObject:wallet];
}

- (void)registerWallet:(DSWallet*)wallet
{
    if ([self.mWallets indexOfObject:wallet] == NSNotFound) {
        [self addWallet:wallet];
    }
    NSError * error = nil;
    NSMutableArray * keyChainArray = [getKeychainArray(self.chainWalletsKey, &error) mutableCopy];
    if (!keyChainArray) keyChainArray = [NSMutableArray array];
    [keyChainArray addObject:wallet.uniqueID];
    setKeychainArray(keyChainArray, self.chainWalletsKey, NO);
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:DSChainWalletsDidChangeNotification object:nil userInfo:@{DSChainPeerManagerNotificationChainKey:self}];
    });
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

// This is a time interval since the reference date 2001
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
        return self.checkpoints.lastObject.timestamp - NSTimeIntervalSince1970;
    }
}


#define GENESIS_BLOCK_HASH


- (NSMutableDictionary *)blocks
{
    if (_blocks.count > 0) return _blocks;

    [[DSMerkleBlockEntity context] performBlockAndWait:^{
        if (_blocks.count > 0) return;
        _blocks = [NSMutableDictionary dictionary];
        self.checkpointsDictionary = [NSMutableDictionary dictionary];
        for (DSCheckpoint * checkpoint in self.checkpoints) { // add checkpoints to the block collection
            UInt256 checkpointHash = checkpoint.checkpointHash;

            _blocks[uint256_obj(checkpointHash)] = [[DSMerkleBlock alloc] initWithBlockHash:checkpointHash onChain:self version:1 prevBlock:UINT256_ZERO
                                                                                 merkleRoot:UINT256_ZERO timestamp:checkpoint.timestamp
                                                                                     target:checkpoint.target nonce:0 totalTransactions:0 hashes:nil
                                                                                      flags:nil height:checkpoint.height];
            self.checkpointsDictionary[@(checkpoint.height)] = uint256_obj(checkpointHash);
        }
        self.delegateQueueChainEntity = [self chainEntity];
        for (DSMerkleBlockEntity *e in [DSMerkleBlockEntity lastBlocks:50 onChain:self.delegateQueueChainEntity]) {
            @autoreleasepool {
                DSMerkleBlock *b = e.merkleBlock;

                if (b) _blocks[uint256_obj(b.blockHash)] = b;
            }
        };
    }];

    return _blocks;
}

-(BOOL)isActive {
    return false;
}

// this is used as part of a getblocks or getheaders request
- (NSArray *)blockLocatorArray
{
    // append 10 most recent block checkpointHashes, decending, then continue appending, doubling the step back each time,
    // finishing with the genesis block (top, -1, -2, -3, -4, -5, -6, -7, -8, -9, -11, -15, -23, -39, -71, -135, ..., 0)
    NSMutableArray *locators = [NSMutableArray array];
    int32_t step = 1, start = 0;
    DSMerkleBlock *b = self.lastBlock;

    while (b && b.height > 0) {
        [locators addObject:uint256_obj(b.blockHash)];
        if (++start >= 10) step *= 2;

        for (int32_t i = 0; b && i < step; i++) {
            b = self.blocks[uint256_obj(b.prevBlock)];
        }
    }

    [locators addObject:uint256_obj([self genesisHash])];
    return locators;
}

- (DSMerkleBlock *)lastBlock
{
    if (! _lastBlock) {
        [DSMerkleBlockEntity.context performBlockAndWait:^{
            NSArray * lastBlocks = [DSMerkleBlockEntity lastBlocks:1 onChain:self.chainEntity];
            self->_lastBlock = [[lastBlocks firstObject] merkleBlock];
        }];

        if (!_lastBlock) {
            if ([[DSOptionsManager sharedInstance] syncFromGenesis]) {
                UInt256 checkpointHash = self.checkpoints[0].checkpointHash;

                _lastBlock = self.blocks[uint256_obj(checkpointHash)];
            } else if ([[DSOptionsManager sharedInstance] shouldSyncFromHeight]) {
                // if we don't have any blocks yet, use the latest checkpoint that's at least a week older than earliestKeyTime
                for (long i = self.checkpoints.count - 1; ! _lastBlock && i >= 0; i--) {
                    if (i == 0 || ![self syncsBlockchain] || (self.checkpoints[i].height <= [[DSOptionsManager sharedInstance] syncFromHeight])) {
                        UInt256 checkpointHash = self.checkpoints[i].checkpointHash;

                        _lastBlock = [[DSMerkleBlock alloc] initWithBlockHash:checkpointHash onChain:self version:1 prevBlock:UINT256_ZERO
                                                                   merkleRoot:UINT256_ZERO timestamp:self.checkpoints[i].timestamp
                                                                       target:self.checkpoints[i].target nonce:0 totalTransactions:0 hashes:nil flags:nil
                                                                       height:self.checkpoints[i].height];
                    }
                }
            } else {

                // if we don't have any blocks yet, use the latest checkpoint that's at least a week older than earliestKeyTime
                for (long i = self.checkpoints.count - 1; ! _lastBlock && i >= 0; i--) {
                    if (i == 0 || ![self syncsBlockchain] || (self.checkpoints[i].timestamp + 7*24*60*60 < self.startSyncFromTime + NSTimeIntervalSince1970)) {
                        UInt256 checkpointHash = self.checkpoints[i].checkpointHash;

                        _lastBlock = [[DSMerkleBlock alloc] initWithBlockHash:checkpointHash onChain:self version:1 prevBlock:UINT256_ZERO
                                                                   merkleRoot:UINT256_ZERO timestamp:self.checkpoints[i].timestamp
                                                                       target:self.checkpoints[i].target nonce:0 totalTransactions:0 hashes:nil flags:nil
                                                                       height:self.checkpoints[i].height];
                    }
                }
            }

        }



        if (_lastBlock.height > _estimatedBlockHeight) _estimatedBlockHeight = _lastBlock.height;
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
    if (blockHeight == TX_UNCONFIRMED) return (self.lastBlock.timestamp - NSTimeIntervalSince1970) + 10*60; //next block

    if (blockHeight >= self.lastBlockHeight) { // future block, assume 10 minutes per block after last block
        return (self.lastBlock.timestamp - NSTimeIntervalSince1970) + (blockHeight - self.lastBlockHeight)*10*60;
    }

    if (_blocks.count > 0) {
        if (blockHeight >= self.lastBlockHeight - DGW_PAST_BLOCKS_MAX) { // recent block we have the header for
            DSMerkleBlock *block = self.lastBlock;

            while (block && block.height > blockHeight) block = self.blocks[uint256_obj(block.prevBlock)];
            if (block) return block.timestamp - NSTimeIntervalSince1970;
        }
    }
    else [[DSMerkleBlockEntity context] performBlock:^{ [self blocks]; }];

    uint32_t h = self.lastBlockHeight, t = self.lastBlock.timestamp;

    for (long i = self.checkpoints.count - 1; i >= 0; i--) { // estimate from checkpoints
        if (self.checkpoints[i].height <= blockHeight) {
            t = self.checkpoints[i].timestamp + (t - self.checkpoints[i].timestamp)*
            (blockHeight - self.checkpoints[i].height)/(h - self.checkpoints[i].height);
            return t - NSTimeIntervalSince1970;
        }

        h = self.checkpoints[i].height;
        t = self.checkpoints[i].timestamp;
    }

    return self.checkpoints[0].timestamp - NSTimeIntervalSince1970;
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
    }

    [self.peerManagerDelegate chain:self didSetBlockHeight:height andTimestamp:timestamp forTxHashes:txHashes updatedTx:updatedTx];
}

- (BOOL)addBlock:(DSMerkleBlock *)block fromPeer:(DSPeer*)peer
{
    //All blocks will be added from same delegateQueue
    NSArray *txHashes = block.txHashes;

    NSValue *blockHash = uint256_obj(block.blockHash), *prevBlock = uint256_obj(block.prevBlock);
    DSMerkleBlock *prev = self.blocks[prevBlock];
    uint32_t transitionTime = 0, txTime = 0;
    UInt256 checkpoint = UINT256_ZERO;
    BOOL syncDone = NO;

    if (! prev) { // block is an orphan
        //        NSSortDescriptor * sortDescriptor = [NSSortDescriptor sortDescriptorWithKey:@"height" ascending:TRUE];
        //        for (DSMerkleBlock * merkleBlock in [[self.blocks allValues] sortedArrayUsingDescriptors:@[sortDescriptor]]) {
        //            NSLog(@"printing previous block at height %d : %@",merkleBlock.height,uint256_obj(merkleBlock.blockHash));
        //        }
        NSLog(@"%@:%d relayed orphan block %@, previous %@, height %d, last block is %@, height %d", peer.host, peer.port,
              blockHash, prevBlock, block.height, uint256_obj(self.lastBlock.blockHash), self.lastBlockHeight);

        [self.peerManagerDelegate chain:self receivedOrphanBlock:block fromPeer:peer];

        self.orphans[prevBlock] = block; // orphans are indexed by prevBlock instead of blockHash
        self.lastOrphan = block;
        return TRUE;
    }

    block.height = prev.height + 1;
    txTime = block.timestamp/2 + prev.timestamp/2;

    if ((block.height % 1000) == 0) { //free up some memory from time to time
        [self saveBlocks];
        DSMerkleBlock *b = block;

        for (uint32_t i = 0; b && i < (DGW_PAST_BLOCKS_MAX + 50); i++) {
            b = self.blocks[uint256_obj(b.prevBlock)];
        }
        NSMutableArray * blocksToRemove = [NSMutableArray array];
        while (b) { // free up some memory
            [blocksToRemove addObject:uint256_obj(b.blockHash)];
            b = self.blocks[uint256_obj(b.prevBlock)];
        }
        [self.blocks removeObjectsForKeys:blocksToRemove];
        NSLog(@"%lu blocks remaining",(unsigned long)[self.blocks count]);
    }

    // verify block difficulty if block is past last checkpoint
    DSCheckpoint * lastCheckpoint = [self lastCheckpoint];
    if ((block.height > (lastCheckpoint.height + DGW_PAST_BLOCKS_MAX)) && [self isMainnet] &&
        ![block verifyDifficultyWithPreviousBlocks:self.blocks]) {
        uint32_t foundDifficulty = [block darkGravityWaveTargetWithPreviousBlocks:self.blocks];
        NSLog(@"%@:%d relayed block with invalid difficulty height %d target %x foundTarget %x, blockHash: %@", peer.host, peer.port,
              block.height,block.target,foundDifficulty, blockHash);
        [self.peerManagerDelegate chain:self badBlockReceivedFromPeer:peer];
        return FALSE;
    }

    [self.checkpointsDictionary[@(block.height)] getValue:&checkpoint ];

    // verify block chain checkpoints
    if (! uint256_is_zero(checkpoint) && ! uint256_eq(block.blockHash, checkpoint)) {
        NSLog(@"%@:%d relayed a block that differs from the checkpoint at height %d, blockHash: %@, expected: %@",
              peer.host, peer.port, block.height, blockHash, self.checkpointsDictionary[@(block.height)]);
        [self.peerManagerDelegate chain:self badBlockReceivedFromPeer:peer];
        return FALSE;
    }

    BOOL onMainChain = FALSE;

    if (uint256_eq(block.prevBlock, self.lastBlock.blockHash)) { // new block extends main chain
        if ((block.height % 500) == 0 || txHashes.count > 0 || block.height > peer.lastblock) {
            NSLog(@"adding block at height: %d", block.height);
        }

        self.blocks[blockHash] = block;
        self.lastBlock = block;
        [self setBlockHeight:block.height andTimestamp:txTime - NSTimeIntervalSince1970 forTxHashes:txHashes];
        peer.currentBlockHeight = block.height; //might be download peer instead
        if (block.height == _estimatedBlockHeight) syncDone = YES;
        onMainChain = TRUE;
    }
    else if (self.blocks[blockHash] != nil) { // we already have the block (or at least the header)
        if ((block.height % 500) == 0 || txHashes.count > 0 || block.height > peer.lastblock) {
            NSLog(@"%@:%d relayed existing block at height %d", peer.host, peer.port, block.height);
        }

        self.blocks[blockHash] = block;

        DSMerkleBlock *b = self.lastBlock;

        while (b && b.height > block.height) b = self.blocks[uint256_obj(b.prevBlock)]; // is block in main chain?

        if (uint256_eq(b.blockHash, block.blockHash)) { // if it's not on a fork, set block heights for its transactions
            [self setBlockHeight:block.height andTimestamp:txTime - NSTimeIntervalSince1970 forTxHashes:txHashes];
            if (block.height == self.lastBlockHeight) self.lastBlock = block;
        }
    }
    else { // new block is on a fork
        if (block.height <= [self lastCheckpoint].height) { // fork is older than last checkpoint
            NSLog(@"ignoring block on fork older than most recent checkpoint, fork height: %d, blockHash: %@",
                  block.height, blockHash);
            return TRUE;
        }

        // special case, if a new block is mined while we're rescanning the chain, mark as orphan til we're caught up
        if (self.lastBlockHeight < peer.lastblock && block.height > self.lastBlockHeight + 1) {
            NSLog(@"marking new block at height %d as orphan until rescan completes", block.height);
            self.orphans[prevBlock] = block;
            self.lastOrphan = block;
            return TRUE;
        }

        NSLog(@"chain fork to height %d", block.height);
        self.blocks[blockHash] = block;
        if (block.height <= self.lastBlockHeight) return TRUE; // if fork is shorter than main chain, ignore it for now

        NSMutableArray *txHashes = [NSMutableArray array];
        DSMerkleBlock *b = block, *b2 = self.lastBlock;

        while (b && b2 && ! uint256_eq(b.blockHash, b2.blockHash)) { // walk back to where the fork joins the main chain
            b = self.blocks[uint256_obj(b.prevBlock)];
            if (b.height < b2.height) b2 = self.blocks[uint256_obj(b2.prevBlock)];
        }

        NSLog(@"reorganizing chain from height %d, new height is %d", b.height, block.height);

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
            [self setBlockHeight:b.height andTimestamp:txTime - NSTimeIntervalSince1970 forTxHashes:b.txHashes];
            b = self.blocks[uint256_obj(b.prevBlock)];
            txTime = b.timestamp/2 + ((DSMerkleBlock *)self.blocks[uint256_obj(b.prevBlock)]).timestamp/2;
        }

        self.lastBlock = block;
        if (block.height == _estimatedBlockHeight) syncDone = YES;
    }

    //NSLog(@"%@:%d added block at height %d target %x blockHash: %@", peer.host, peer.port,
    //      block.height,block.target, blockHash);

    if (syncDone) { // chain download is complete
        [self saveBlocks];
        [self.peerManagerDelegate chainFinishedSyncing:self fromPeer:peer onMainChain:onMainChain];
    }

    if (block.height > _estimatedBlockHeight) {
        _estimatedBlockHeight = block.height;

        // notify that transaction confirmations may have changed
        dispatch_async(dispatch_get_main_queue(), ^{
            [[NSNotificationCenter defaultCenter] postNotificationName:DSChainPeerManagerNewBlockNotification object:nil userInfo:@{DSChainPeerManagerNotificationChainKey:self}];
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
    NSLog(@"[DSChain] save blocks");
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
            if ([recentOrphans count])  NSLog(@"%lu recent orphans will be removed from disk",(unsigned long)[recentOrphans count]);
            [DSMerkleBlockEntity deleteObjects:recentOrphans];
        } else {
            NSArray<DSMerkleBlockEntity *> * oldBlockHeaders = [DSMerkleBlockEntity objectsMatching:@"!(blockHash in %@)",blocks.allKeys];
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
        UInt256 checkpointHash = self.checkpoints[0].checkpointHash;

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
            if (i == 0 || (self.checkpoints[i].timestamp + 7*24*60*60 < self.startSyncFromTime + NSTimeIntervalSince1970)) {
                UInt256 checkpointHash = self.checkpoints[i].checkpointHash;

                _lastBlock = self.blocks[uint256_obj(checkpointHash)];
            }
        }
    }
}

-(void)setEstimatedBlockHeight:(uint32_t)estimatedBlockHeight fromPeer:(DSPeer*)peer {
    _estimatedBlockHeight = estimatedBlockHeight;
}

- (DSTransaction *)transactionForHash:(UInt256)txHash {
    for (DSWallet * wallet in self.wallets) {
        DSTransaction * transaction = [wallet transactionForHash:txHash];
        if (transaction) return transaction;
    }
    return nil;
}

- (DSAccount* _Nullable)accountContainingTransaction:(DSTransaction * _Nonnull)transaction {
    for (DSWallet * wallet in self.wallets) {
        DSAccount * account = [wallet accountContainingTransaction:transaction];
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
    if (isInstant) {
        return TX_FEE_PER_INPUT*inputCount;
    } else {
        uint64_t standardFee = ((size + 999)/1000)*TX_FEE_PER_KB; // standard fee based on tx size rounded up to nearest kb
#if (!!FEE_PER_KB_URL)
        uint64_t fee = (((size*self.feePerKb/1000) + 99)/100)*100; // fee using feePerKb, rounded up to nearest 100 satoshi
        return (fee > standardFee) ? fee : standardFee;
#else
        return standardFee;
#endif

    }
}

// outputs below this amount are uneconomical due to fees
- (uint64_t)minOutputAmount
{
    uint64_t amount = (TX_MIN_OUTPUT_AMOUNT*self.feePerKb + MIN_FEE_PER_KB - 1)/MIN_FEE_PER_KB;

    return (amount > TX_MIN_OUTPUT_AMOUNT) ? amount : TX_MIN_OUTPUT_AMOUNT;
}

- (BOOL)isEqual:(id)obj
{
    return self == obj || ([obj isKindOfClass:[DSChain class]] && uint256_eq([obj genesisHash], _genesisHash));
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

-(void)encodeWithCoder:(NSCoder *)aCoder {
    [aCoder encodeUInt256:self.checkpointHash forKey:kCheckpointHashKey];
    [aCoder encodeInt32:self.height forKey:kHeightKey];
    [aCoder encodeInt32:self.timestamp forKey:kTimestampKey];
    [aCoder encodeInt32:self.target forKey:kTargetKey];
}

@end
