//
//  DSBlockchainUser.m
//  AxeSync
//
//  Created by Sam Westrich on 7/26/18.
//

#import "DSBlockchainUser.h"
#import "DSChain.h"
#import "DSECDSAKey.h"
#import "DSAccount.h"
#import "DSWallet.h"
#import "DSDerivationPath.h"
#import "NSCoder+Axe.h"
#import "NSMutableData+Axe.h"
#import "DSBlockchainUserRegistrationTransaction.h"
#import "DSBlockchainUserTopupTransaction.h"
#import "DSBlockchainUserResetTransaction.h"
#import "DSBlockchainUserCloseTransaction.h"
#import "DSAuthenticationManager.h"
#import "DSPriceManager.h"
#import "DSPeerManager.h"
#import "DSDerivationPathFactory.h"
#import "DSAuthenticationKeysDerivationPath.h"
#import "DSDerivationPathFactory.h"

#define BLOCKCHAIN_USER_UNIQUE_IDENTIFIER_KEY @"BLOCKCHAIN_USER_UNIQUE_IDENTIFIER_KEY"

@interface DSBlockchainUser()

@property (nonatomic,strong) DSWallet * wallet;
@property (nonatomic,strong) NSString * username;
@property (nonatomic,strong) NSString * uniqueIdentifier;
@property (nonatomic,assign) uint32_t index;
@property (nonatomic,assign) UInt256 registrationTransactionHash;
@property (nonatomic,assign) UInt256 lastBlockchainUserTransactionHash;

@end

@implementation DSBlockchainUser

-(instancetype)initWithUsername:(NSString*)username atIndex:(uint32_t)index inWallet:(DSWallet*)wallet {
    if (!(self = [super init])) return nil;
    self.username = username;
    self.uniqueIdentifier = [NSString stringWithFormat:@"%@_%@_%@",BLOCKCHAIN_USER_UNIQUE_IDENTIFIER_KEY,wallet.chain.uniqueID,username];
    self.wallet = wallet;
    self.registrationTransactionHash = UINT256_ZERO;
    self.index = index;
    return self;
}

-(instancetype)initWithUsername:(NSString*)username atIndex:(uint32_t)index inWallet:(DSWallet*)wallet createdWithTransactionHash:(UInt256)registrationTransactionHash lastBlockchainUserTransactionHash:(UInt256)lastBlockchainUserTransactionHash {
    if (!(self = [super init])) return nil;
    self.username = username;
    self.uniqueIdentifier = [NSString stringWithFormat:@"%@_%@_%@",BLOCKCHAIN_USER_UNIQUE_IDENTIFIER_KEY,wallet.chain.uniqueID,username];
    self.wallet = wallet;
    self.registrationTransactionHash = registrationTransactionHash;
    self.lastBlockchainUserTransactionHash = lastBlockchainUserTransactionHash; //except topup and close, including state transitions
    self.index = index;
    return self;
}

-(instancetype)initWithBlockchainUserRegistrationTransaction:(DSBlockchainUserRegistrationTransaction*)blockchainUserRegistrationTransaction {
    if (!(self = [super init])) return nil;
    self.username = blockchainUserRegistrationTransaction.username;
    self.uniqueIdentifier = [NSString stringWithFormat:@"%@_%@_%@",BLOCKCHAIN_USER_UNIQUE_IDENTIFIER_KEY,blockchainUserRegistrationTransaction.chain.uniqueID,self.username];
    uint32_t index = 0;
    DSWallet * wallet = [blockchainUserRegistrationTransaction.chain walletHavingBlockchainUserAuthenticationHash:blockchainUserRegistrationTransaction.pubkeyHash foundAtIndex:&index];
    self.wallet = wallet;
    self.index = index;
    self.registrationTransactionHash = blockchainUserRegistrationTransaction.txHash;
    return self;
}

-(void)generateBlockchainUserExtendedPublicKey:(void (^ _Nullable)(BOOL registered))completion {
    __block DSAuthenticationKeysDerivationPath * derivationPath = [[DSDerivationPathFactory sharedInstance] blockchainUsersKeysDerivationPathForWallet:self.wallet];
    if ([derivationPath hasExtendedPublicKey]) {
        completion(YES);
        return;
    }
    [[DSAuthenticationManager sharedInstance] seedWithPrompt:@"Generate Blockchain User" forWallet:self.wallet forAmount:0 forceAuthentication:NO completion:^(NSData * _Nullable seed, BOOL cancelled) {
        if (!seed) {
            completion(NO);
            return;
        }
        [derivationPath generateExtendedPublicKeyFromSeed:seed storeUnderWalletUniqueId:self.wallet.uniqueID];
        completion(YES);
    }];
}

-(void)registerInWallet {
    [self.wallet registerBlockchainUser:self];
}

-(void)registrationTransactionForTopupAmount:(uint64_t)topupAmount fundedByAccount:(DSAccount*)fundingAccount completion:(void (^ _Nullable)(DSBlockchainUserRegistrationTransaction * blockchainUserRegistrationTransaction))completion {
    NSString * question = [NSString stringWithFormat:DSLocalizedString(@"Are you sure you would like to register the username %@ and spend %@ on credits?", nil),self.username,[[DSPriceManager sharedInstance] stringForAxeAmount:topupAmount]];
    [[DSAuthenticationManager sharedInstance] seedWithPrompt:question forWallet:self.wallet forAmount:topupAmount forceAuthentication:YES completion:^(NSData * _Nullable seed, BOOL cancelled) {
        if (!seed) {
            completion(nil);
            return;
        }
        DSAuthenticationKeysDerivationPath * derivationPath = [[DSDerivationPathFactory sharedInstance] blockchainUsersKeysDerivationPathForWallet:self.wallet];
        DSECDSAKey * privateKey = (DSECDSAKey *)[derivationPath privateKeyAtIndexPath:[NSIndexPath indexPathWithIndex:self.index] fromSeed:seed];

        DSBlockchainUserRegistrationTransaction * blockchainUserRegistrationTransaction = [[DSBlockchainUserRegistrationTransaction alloc] initWithBlockchainUserRegistrationTransactionVersion:1 username:self.username pubkeyHash:[privateKey.publicKeyData hash160] onChain:self.wallet.chain];
        [blockchainUserRegistrationTransaction signPayloadWithKey:privateKey];
        NSMutableData * opReturnScript = [NSMutableData data];
        [opReturnScript appendUInt8:OP_RETURN];
        [fundingAccount updateTransaction:blockchainUserRegistrationTransaction forAmounts:@[@(topupAmount)] toOutputScripts:@[opReturnScript] withFee:YES isInstant:NO];
        
        completion(blockchainUserRegistrationTransaction);
    }];
}

-(void)topupTransactionForTopupAmount:(uint64_t)topupAmount fundedByAccount:(DSAccount*)fundingAccount completion:(void (^ _Nullable)(DSBlockchainUserTopupTransaction * blockchainUserTopupTransaction))completion {
    NSString * question = [NSString stringWithFormat:DSLocalizedString(@"Are you sure you would like to topup %@ and spend %@ on credits?", nil),self.username,[[DSPriceManager sharedInstance] stringForAxeAmount:topupAmount]];
    [[DSAuthenticationManager sharedInstance] seedWithPrompt:question forWallet:self.wallet forAmount:topupAmount forceAuthentication:YES completion:^(NSData * _Nullable seed, BOOL cancelled) {
        if (!seed) {
            completion(nil);
            return;
        }
        DSBlockchainUserTopupTransaction * blockchainUserTopupTransaction = [[DSBlockchainUserTopupTransaction alloc] initWithBlockchainUserTopupTransactionVersion:1 registrationTransactionHash:self.registrationTransactionHash onChain:self.wallet.chain];
        
        NSMutableData * opReturnScript = [NSMutableData data];
        [opReturnScript appendUInt8:OP_RETURN];
        [fundingAccount updateTransaction:blockchainUserTopupTransaction forAmounts:@[@(topupAmount)] toOutputScripts:@[opReturnScript] withFee:YES isInstant:NO];

        completion(blockchainUserTopupTransaction);
    }];
    
}

-(void)resetTransactionUsingNewIndex:(uint32_t)index completion:(void (^ _Nullable)(DSBlockchainUserResetTransaction * blockchainUserResetTransaction))completion {
    NSString * question = DSLocalizedString(@"Are you sure you would like to reset this user?", nil);
    [[DSAuthenticationManager sharedInstance] seedWithPrompt:question forWallet:self.wallet forAmount:0 forceAuthentication:YES completion:^(NSData * _Nullable seed, BOOL cancelled) {
        if (!seed) {
            completion(nil);
            return;
        }
        DSAuthenticationKeysDerivationPath * derivationPath = [[DSDerivationPathFactory sharedInstance] blockchainUsersKeysDerivationPathForWallet:self.wallet];
        DSECDSAKey * oldPrivateKey = (DSECDSAKey *)[derivationPath privateKeyAtIndex:self.index fromSeed:seed];
        DSECDSAKey * privateKey = (DSECDSAKey *)[derivationPath privateKeyAtIndex:index fromSeed:seed];
        
        DSBlockchainUserResetTransaction * blockchainUserResetTransaction = [[DSBlockchainUserResetTransaction alloc] initWithBlockchainUserResetTransactionVersion:1 registrationTransactionHash:self.registrationTransactionHash previousBlockchainUserTransactionHash:self.lastBlockchainUserTransactionHash replacementPublicKeyHash:[privateKey.publicKeyData hash160] creditFee:1000 onChain:self.wallet.chain];
        [blockchainUserResetTransaction signPayloadWithKey:oldPrivateKey];
        DSDLog(@"%@",blockchainUserResetTransaction.toData);
        completion(blockchainUserResetTransaction);
    }];
}


@end
