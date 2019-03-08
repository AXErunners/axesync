//
//  DSLocalMasternode.m
//  AxeSync
//
//  Created by Sam Westrich on 2/9/19.
//

#import "DSLocalMasternode.h"
#import "DSProviderRegistrationTransaction.h"
#import "DSProviderUpdateServiceTransaction.h"
#import "DSProviderUpdateRegistrarTransaction.h"
#import "DSAuthenticationManager.h"
#import "DSWallet.h"
#import "DSAccount.h"
#import "DSMasternodeManager.h"
#import "DSMasternodeHoldingsDerivationPath.h"
#import "DSAuthenticationKeysDerivationPath.h"
#import "DSLocalMasternodeEntity+CoreDataClass.h"
#import "DSChainEntity+CoreDataProperties.h"
#import "NSData+Bitcoin.h"
#import "NSMutableData+Axe.h"
#import "NSManagedObject+Sugar.h"
#import "DSProviderRegistrationTransactionEntity+CoreDataClass.h"
#import "DSProviderUpdateServiceTransactionEntity+CoreDataClass.h"
#import "DSProviderUpdateRegistrarTransactionEntity+CoreDataClass.h"
#import "DSProviderUpdateRevocationTransactionEntity+CoreDataClass.h"
#import "DSTransactionHashEntity+CoreDataClass.h"
#import "DSECDSAKey.h"
#include <arpa/inet.h>

@interface DSLocalMasternode()

@property(nonatomic,assign) UInt128 ipAddress;
@property(nonatomic,assign) uint16_t port;
@property(nonatomic,strong) DSWallet * operatorKeysWallet; //only if this is contained in the wallet.
@property(nonatomic,strong) DSWallet * holdingKeysWallet; //only if this is contained in the wallet.
@property(nonatomic,strong) DSWallet * ownerKeysWallet; //only if this is contained in the wallet.
@property(nonatomic,strong) DSWallet * votingKeysWallet; //only if this is contained in the wallet.
@property(nonatomic,assign) uint32_t operatorWalletIndex; //the derivation path index of keys
@property(nonatomic,assign) uint32_t ownerWalletIndex;
@property(nonatomic,assign) uint32_t votingWalletIndex;
@property(nonatomic,assign) uint32_t holdingWalletIndex;
@property(nonatomic,assign) DSLocalMasternodeStatus status;
@property(nonatomic,strong) DSProviderRegistrationTransaction * providerRegistrationTransaction;
@property(nonatomic,strong) NSMutableArray <DSProviderUpdateRegistrarTransaction*>* providerUpdateRegistrarTransactions;
@property(nonatomic,strong) NSMutableArray <DSProviderUpdateServiceTransaction*>* providerUpdateServiceTransactions;
@property(nonatomic,strong) NSMutableArray <DSProviderUpdateRevocationTransaction*>* providerUpdateRevocationTransactions;

@end

@implementation DSLocalMasternode

-(instancetype)initWithIPAddress:(UInt128)ipAddress onPort:(uint32_t)port inWallet:(DSWallet*)wallet {
    if (!(self = [super init])) return nil;
    
    return [self initWithIPAddress:ipAddress onPort:port inFundsWallet:wallet inOperatorWallet:wallet inOwnerWallet:wallet
                    inVotingWallet:wallet];
}
-(instancetype)initWithIPAddress:(UInt128)ipAddress onPort:(uint32_t)port inFundsWallet:(DSWallet*)fundsWallet inOperatorWallet:(DSWallet*)operatorWallet inOwnerWallet:(DSWallet*)ownerWallet inVotingWallet:(DSWallet*)votingWallet {
    if (!(self = [super init])) return nil;
    self.operatorKeysWallet = operatorWallet;
    self.holdingKeysWallet = fundsWallet;
    self.ownerKeysWallet = ownerWallet;
    self.votingKeysWallet = votingWallet;
    self.ipAddress = ipAddress;
    self.port = port;
    self.providerUpdateRegistrarTransactions = [NSMutableArray array];
    self.providerUpdateServiceTransactions = [NSMutableArray array];
    self.providerUpdateRevocationTransactions = [NSMutableArray array];
    return self;
}

-(instancetype)initWithIPAddress:(UInt128)ipAddress onPort:(uint32_t)port inFundsWallet:(DSWallet* _Nullable)fundsWallet fundsWalletIndex:(uint32_t)fundsWalletIndex inOperatorWallet:(DSWallet* _Nullable)operatorWallet operatorWalletIndex:(uint32_t)operatorWalletIndex inOwnerWallet:(DSWallet* _Nullable)ownerWallet ownerWalletIndex:(uint32_t)ownerWalletIndex inVotingWallet:(DSWallet* _Nullable)votingWallet votingWalletIndex:(uint32_t)votingWalletIndex {
    if (!(self = [super init])) return nil;
    self.operatorKeysWallet = operatorWallet;
    self.holdingKeysWallet = fundsWallet;
    self.ownerKeysWallet = ownerWallet;
    self.votingKeysWallet = votingWallet;
    self.ownerWalletIndex = ownerWalletIndex;
    self.operatorWalletIndex = operatorWalletIndex;
    self.votingWalletIndex = votingWalletIndex;
    self.holdingWalletIndex = fundsWalletIndex;
    self.ipAddress = ipAddress;
    self.port = port;
    self.providerUpdateRegistrarTransactions = [NSMutableArray array];
    self.providerUpdateServiceTransactions = [NSMutableArray array];
    self.providerUpdateRevocationTransactions = [NSMutableArray array];
    return self;
}

-(instancetype)initWithProviderTransactionRegistration:(DSProviderRegistrationTransaction*)providerRegistrationTransaction {
    if (!(self = [super init])) return nil;
    uint32_t ownerAddressIndex;
    uint32_t votingAddressIndex;
    uint32_t operatorAddressIndex;
    uint32_t holdingAddressIndex;
    DSWallet * ownerWallet = [providerRegistrationTransaction.chain walletHavingProviderOwnerAuthenticationHash:providerRegistrationTransaction.ownerKeyHash foundAtIndex:&ownerAddressIndex];
    DSWallet * votingWallet = [providerRegistrationTransaction.chain walletHavingProviderVotingAuthenticationHash:providerRegistrationTransaction.votingKeyHash foundAtIndex:&votingAddressIndex];
    DSWallet * operatorWallet = [providerRegistrationTransaction.chain walletHavingProviderOperatorAuthenticationKey:providerRegistrationTransaction.operatorKey foundAtIndex:&operatorAddressIndex];
    DSWallet * holdingWallet = [providerRegistrationTransaction.chain walletContainingMasternodeHoldingAddressForProviderRegistrationTransaction:providerRegistrationTransaction foundAtIndex:&holdingAddressIndex];
    self.operatorKeysWallet = operatorWallet;
    self.holdingKeysWallet = holdingWallet;
    self.ownerKeysWallet = ownerWallet;
    self.votingKeysWallet = votingWallet;
    self.ownerWalletIndex = ownerAddressIndex;
    self.operatorWalletIndex = operatorAddressIndex;
    self.votingWalletIndex = votingAddressIndex;
    self.holdingWalletIndex = holdingAddressIndex;
    self.ipAddress = providerRegistrationTransaction.ipAddress;
    self.port = providerRegistrationTransaction.port;
    self.providerRegistrationTransaction = providerRegistrationTransaction;
    self.providerUpdateRegistrarTransactions = [NSMutableArray array];
    self.providerUpdateServiceTransactions = [NSMutableArray array];
    self.providerUpdateRevocationTransactions = [NSMutableArray array];
    self.status = DSLocalMasternodeStatus_Registered; //because it comes from a transaction already
    return self;
}

-(void)registerInAssociatedWallets {
    [self.operatorKeysWallet registerMasternodeOperator:self];
    [self.ownerKeysWallet registerMasternodeOwner:self];
    [self.votingKeysWallet registerMasternodeVoter:self];
}

-(BOOL)noLocalWallet {
    return !(self.operatorKeysWallet || self.holdingKeysWallet || self.ownerKeysWallet || self.votingKeysWallet);
}

-(UInt128)ipAddress {
    if ([self.providerUpdateServiceTransactions count]) {
        return [self.providerUpdateServiceTransactions lastObject].ipAddress;
    }
    if (self.providerRegistrationTransaction) {
        return self.providerRegistrationTransaction.ipAddress;
    }
    return _ipAddress;
}

-(uint16_t)port {
    if ([self.providerUpdateServiceTransactions count]) {
        return [self.providerUpdateServiceTransactions lastObject].port;
    }
    if (self.providerRegistrationTransaction) {
        return self.providerRegistrationTransaction.port;
    }
    return _port;
}

-(NSString*)payoutAddress {
    if ([self.providerUpdateRegistrarTransactions count]) {
        return [NSString addressWithScriptPubKey:[self.providerUpdateRegistrarTransactions lastObject].scriptPayout onChain:self.providerRegistrationTransaction.chain];
    }
    if (self.providerRegistrationTransaction) {
        return [NSString addressWithScriptPubKey:self.providerRegistrationTransaction.scriptPayout onChain:self.providerRegistrationTransaction.chain];
    }
    return nil;
}

-(DSBLSKey*)operatorKeyFromSeed:(NSData*)seed {
    DSAuthenticationKeysDerivationPath * providerOperatorKeysDerivationPath = [DSAuthenticationKeysDerivationPath providerOperatorKeysDerivationPathForWallet:self.operatorKeysWallet];
    
    return (DSBLSKey *)[providerOperatorKeysDerivationPath privateKeyForHash160:[[NSData dataWithUInt384:self.providerRegistrationTransaction.operatorKey] hash160] fromSeed:seed];
}

-(NSString*)operatorKeyStringFromSeed:(NSData*)seed {
    DSBLSKey * blsKey = [self operatorKeyFromSeed:seed];
    return [blsKey secretKeyString];
}

-(DSECDSAKey*)ownerKeyFromSeed:(NSData*)seed {
    DSAuthenticationKeysDerivationPath * providerOwnerKeysDerivationPath = [DSAuthenticationKeysDerivationPath providerOwnerKeysDerivationPathForWallet:self.ownerKeysWallet];
    
    return (DSECDSAKey *)[providerOwnerKeysDerivationPath privateKeyForHash160:self.providerRegistrationTransaction.ownerKeyHash fromSeed:seed];
}

-(NSString*)ownerKeyStringFromSeed:(NSData*)seed {
    DSECDSAKey * ecdsaKey = [self ownerKeyFromSeed:seed];
    return [ecdsaKey secretKeyString];
}

-(DSECDSAKey*)votingKeyFromSeed:(NSData*)seed {
    DSAuthenticationKeysDerivationPath * providerVotingKeysDerivationPath = [DSAuthenticationKeysDerivationPath providerVotingKeysDerivationPathForWallet:self.votingKeysWallet];
    
    return (DSECDSAKey *)[providerVotingKeysDerivationPath privateKeyForHash160:self.providerRegistrationTransaction.votingKeyHash fromSeed:seed];
}

-(NSString*)votingKeyStringFromSeed:(NSData*)seed {
    DSECDSAKey * ecdsaKey = [self votingKeyFromSeed:seed];
    return [ecdsaKey secretKeyString];
}



// MARK: - Generating Transactions


-(void)registrationTransactionFundedByAccount:(DSAccount*)fundingAccount completion:(void (^ _Nullable)(DSProviderRegistrationTransaction * providerRegistrationTransaction))completion {
    if (self.status != DSLocalMasternodeStatus_New) return;
    char s[INET6_ADDRSTRLEN];
    NSString * ipAddressString = @(inet_ntop(AF_INET, &self.ipAddress.u32[3], s, sizeof(s)));
    NSString * question = [NSString stringWithFormat:DSLocalizedString(@"Are you sure you would like to register a masternode at %@:%d?", nil),ipAddressString,self.port];
    [[DSAuthenticationManager sharedInstance] seedWithPrompt:question forWallet:fundingAccount.wallet forAmount:MASTERNODE_COST forceAuthentication:YES completion:^(NSData * _Nullable seed, BOOL cancelled) {
        if (!seed) {
            completion(nil);
            return;
        }
        DSMasternodeHoldingsDerivationPath * providerFundsDerivationPath = [DSMasternodeHoldingsDerivationPath providerFundsDerivationPathForWallet:self.holdingKeysWallet];
        if (!providerFundsDerivationPath.hasExtendedPublicKey) {
            [providerFundsDerivationPath generateExtendedPublicKeyFromSeed:seed storeUnderWalletUniqueId:self.holdingKeysWallet.uniqueID];
        }
        DSAuthenticationKeysDerivationPath * providerOwnerKeysDerivationPath = [DSAuthenticationKeysDerivationPath providerOwnerKeysDerivationPathForWallet:self.ownerKeysWallet];
        if (!providerOwnerKeysDerivationPath.hasExtendedPublicKey) {
            [providerOwnerKeysDerivationPath generateExtendedPublicKeyFromSeed:seed storeUnderWalletUniqueId:self.ownerKeysWallet.uniqueID];
        }
        DSAuthenticationKeysDerivationPath * providerOperatorKeysDerivationPath = [DSAuthenticationKeysDerivationPath providerOperatorKeysDerivationPathForWallet:self.operatorKeysWallet];
        if (!providerOperatorKeysDerivationPath.hasExtendedPublicKey) {
            [providerOperatorKeysDerivationPath generateExtendedPublicKeyFromSeed:seed storeUnderWalletUniqueId:self.operatorKeysWallet.uniqueID];
        }
        DSAuthenticationKeysDerivationPath * providerVotingKeysDerivationPath = [DSAuthenticationKeysDerivationPath providerVotingKeysDerivationPathForWallet:self.votingKeysWallet];
        if (!providerVotingKeysDerivationPath.hasExtendedPublicKey) {
            [providerVotingKeysDerivationPath generateExtendedPublicKeyFromSeed:seed storeUnderWalletUniqueId:self.votingKeysWallet.uniqueID];
        }
        
        NSString * holdingAddress = [providerFundsDerivationPath receiveAddress];
        NSMutableData * scriptPayout = [NSMutableData data];
        [scriptPayout appendScriptPubKeyForAddress:holdingAddress forChain:self.holdingKeysWallet.chain];
        
        DSECDSAKey * ownerKey = (DSECDSAKey *)[providerOwnerKeysDerivationPath firstUnusedPrivateKeyFromSeed:seed];
        UInt160 votingKeyHash = providerVotingKeysDerivationPath.firstUnusedPublicKey.hash160;
        UInt384 operatorKey = providerOperatorKeysDerivationPath.firstUnusedPublicKey.UInt384;
        DSProviderRegistrationTransaction * providerRegistrationTransaction = [[DSProviderRegistrationTransaction alloc] initWithProviderRegistrationTransactionVersion:1 type:0 mode:0 ipAddress:self.ipAddress port:self.port ownerKeyHash:ownerKey.publicKeyData.hash160 operatorKey:operatorKey votingKeyHash:votingKeyHash operatorReward:0 scriptPayout:scriptPayout onChain:fundingAccount.wallet.chain];
        
        NSMutableData *script = [NSMutableData data];
        
        [script appendScriptPubKeyForAddress:holdingAddress forChain:fundingAccount.wallet.chain];
        [fundingAccount updateTransaction:providerRegistrationTransaction forAmounts:@[@(MASTERNODE_COST)] toOutputScripts:@[script] withFee:YES isInstant:NO];
        
        [providerRegistrationTransaction updateInputsHash];
        
        //there is no need to sign the payload here.
        
        self.status = DSLocalMasternodeStatus_Created;
        
        completion(providerRegistrationTransaction);
    }];
}

-(void)updateTransactionFundedByAccount:(DSAccount*)fundingAccount toIPAddress:(UInt128)ipAddress port:(uint32_t)port payoutAddress:(NSString*)payoutAddress completion:(void (^ _Nullable)(DSProviderUpdateServiceTransaction * providerRegistrationTransaction))completion {
    if (self.status != DSLocalMasternodeStatus_Registered) return;
    char s[INET6_ADDRSTRLEN];
    NSString * ipAddressString = @(inet_ntop(AF_INET, &self.ipAddress.u32[3], s, sizeof(s)));
    NSString * question = [NSString stringWithFormat:DSLocalizedString(@"Are you sure you would like to update this masternode to %@:%d?", nil),ipAddressString,self.port];
    [[DSAuthenticationManager sharedInstance] seedWithPrompt:question forWallet:fundingAccount.wallet forAmount:0 forceAuthentication:YES completion:^(NSData * _Nullable seed, BOOL cancelled) {
        if (!seed) {
            completion(nil);
            return;
        }
        NSData * scriptPayout;
        if (payoutAddress == nil) {
            scriptPayout = [NSData data];
        } else {
            NSMutableData * mScriptPayout = [NSMutableData data];
            [mScriptPayout appendScriptPubKeyForAddress:payoutAddress forChain:fundingAccount.wallet.chain];
            scriptPayout = mScriptPayout;
        }
        
        DSAuthenticationKeysDerivationPath * providerOperatorKeysDerivationPath = [DSAuthenticationKeysDerivationPath providerOperatorKeysDerivationPathForWallet:self.operatorKeysWallet];
        
        NSAssert(self.providerRegistrationTransaction,@"There must be a providerRegistrationTransaction linked here");
        DSBLSKey * operatorKey = (DSBLSKey *)[providerOperatorKeysDerivationPath privateKeyForHash160:[[NSData dataWithUInt384:self.providerRegistrationTransaction.operatorKey] hash160] fromSeed:seed];
        
        DSProviderUpdateServiceTransaction * providerUpdateServiceTransaction = [[DSProviderUpdateServiceTransaction alloc] initWithProviderUpdateServiceTransactionVersion:1 providerTransactionHash:self.providerRegistrationTransaction.txHash ipAddress:ipAddress port:port scriptPayout:scriptPayout onChain:fundingAccount.wallet.chain];
        
        
        [fundingAccount updateTransaction:providerUpdateServiceTransaction forAmounts:@[] toOutputScripts:@[] withFee:YES isInstant:NO];
        
        [providerUpdateServiceTransaction signPayloadWithKey:operatorKey];
        
        //there is no need to sign the payload here.
        
        completion(providerUpdateServiceTransaction);
    }];
}

-(void)updateTransactionFundedByAccount:(DSAccount*)fundingAccount changeOperator:(UInt384)operatorKey changeVotingKeyHash:(UInt160)votingKeyHash changePayoutAddress:(NSString* _Nullable)payoutAddress completion:(void (^ _Nullable)(DSProviderUpdateRegistrarTransaction * providerUpdateRegistrarTransaction))completion {
    if (self.status != DSLocalMasternodeStatus_Registered) return;
    NSString * question = [NSString stringWithFormat:DSLocalizedString(@"Are you sure you would like to update this masternode to pay to %@?", nil),payoutAddress];
    [[DSAuthenticationManager sharedInstance] seedWithPrompt:question forWallet:fundingAccount.wallet forAmount:0 forceAuthentication:YES completion:^(NSData * _Nullable seed, BOOL cancelled) {
        if (!seed) {
            completion(nil);
            return;
        }
        NSData * scriptPayout;
        if (payoutAddress == nil) {
            scriptPayout = [NSData data];
        } else {
            NSMutableData * mScriptPayout = [NSMutableData data];
            [mScriptPayout appendScriptPubKeyForAddress:payoutAddress forChain:fundingAccount.wallet.chain];
            scriptPayout = mScriptPayout;
        }
        
        DSAuthenticationKeysDerivationPath * providerOwnerKeysDerivationPath = [DSAuthenticationKeysDerivationPath providerOwnerKeysDerivationPathForWallet:self.ownerKeysWallet];
        
        NSAssert(self.providerRegistrationTransaction,@"There must be a providerRegistrationTransaction linked here");
        DSECDSAKey * ownerKey = (DSECDSAKey *)[providerOwnerKeysDerivationPath privateKeyForHash160:self.providerRegistrationTransaction.ownerKeyHash fromSeed:seed];
        
        DSProviderUpdateRegistrarTransaction * providerUpdateRegistrarTransaction = [[DSProviderUpdateRegistrarTransaction alloc] initWithProviderUpdateRegistrarTransactionVersion:1 providerTransactionHash:self.providerRegistrationTransaction.txHash mode:0 operatorKey:operatorKey votingKeyHash:votingKeyHash scriptPayout:scriptPayout onChain:fundingAccount.wallet.chain];
        
        
        [fundingAccount updateTransaction:providerUpdateRegistrarTransaction forAmounts:@[] toOutputScripts:@[] withFee:YES isInstant:NO];
        
        [providerUpdateRegistrarTransaction signPayloadWithKey:ownerKey];
        
        //there is no need to sign the payload here.
        
        completion(providerUpdateRegistrarTransaction);
    }];
}

// MARK: - Update from Transaction

-(void)reclaimTransactionToAccount:(DSAccount*)fundingAccount completion:(void (^ _Nullable)(DSTransaction * reclaimTransaction))completion {
    if (self.status != DSLocalMasternodeStatus_Registered) return;
    NSString * question = DSLocalizedString(@"Are you sure you would like to reclaim this masternode?", nil);
    [[DSAuthenticationManager sharedInstance] seedWithPrompt:question forWallet:fundingAccount.wallet forAmount:0 forceAuthentication:YES completion:^(NSData * _Nullable seed, BOOL cancelled) {
        if (!seed) {
            completion(nil);
            return;
        }
        
        NSInteger index = [self.providerRegistrationTransaction.outputAmounts indexOfObject:@(MASTERNODE_COST)];
        
        if (index == NSNotFound) {
            completion(nil);
            return;
        }
        
        NSMutableData *script = [NSMutableData data];
        
        [script appendScriptPubKeyForAddress:self.providerRegistrationTransaction.outputAddresses[index] forChain:self.providerRegistrationTransaction.chain];
        uint64_t fee = [self.providerRegistrationTransaction.chain feeForTxSize:194 isInstant:NO inputCount:1]; // assume we will add a change output

        DSTransaction * reclaimTransaction = [[DSTransaction alloc] initWithInputHashes:@[uint256_obj(self.providerRegistrationTransaction.txHash)] inputIndexes:@[@(index)] inputScripts:@[script] outputAddresses:@[fundingAccount.changeAddress] outputAmounts:@[@(MASTERNODE_COST - fee)] onChain:self.providerRegistrationTransaction.chain];
        
        //there is no need to sign the payload here.
        completion(reclaimTransaction);
    }];
}


-(void)updateWithUpdateRegistrarTransaction:(DSProviderUpdateRegistrarTransaction*)providerUpdateRegistrarTransaction save:(BOOL)save {
    if (![_providerUpdateRegistrarTransactions containsObject:providerUpdateRegistrarTransaction]) {
        [_providerUpdateRegistrarTransactions addObject:providerUpdateRegistrarTransaction];
        if (save) {
            [self save];
        }
    }
}

-(void)updateWithUpdateRevocationTransaction:(DSProviderUpdateRevocationTransaction*)providerUpdateRevocationTransaction save:(BOOL)save {
    if (![_providerUpdateRevocationTransactions containsObject:providerUpdateRevocationTransaction]) {
        [_providerUpdateRevocationTransactions addObject:providerUpdateRevocationTransaction];
        if (save) {
            [self save];
        }
    }
}

-(void)updateWithUpdateServiceTransaction:(DSProviderUpdateServiceTransaction*)providerUpdateServiceTransaction save:(BOOL)save {
    if (![_providerUpdateServiceTransactions containsObject:providerUpdateServiceTransaction]) {
        [_providerUpdateServiceTransactions addObject:providerUpdateServiceTransaction];
        self.ipAddress = providerUpdateServiceTransaction.ipAddress;
        self.port = providerUpdateServiceTransaction.port;
        if (save) {
            [self save];
        }
    }
}

// MARK: - Persistence

-(void)save {
    NSManagedObjectContext * context = [DSTransactionEntity context];
    [context performBlockAndWait:^{ // add the transaction to core data
        [DSChainEntity setContext:context];
        [DSLocalMasternodeEntity setContext:context];
        [DSTransactionHashEntity setContext:context];
        [DSProviderRegistrationTransactionEntity setContext:context];
        [DSProviderUpdateServiceTransactionEntity setContext:context];
        [DSProviderUpdateRegistrarTransactionEntity setContext:context];
        [DSProviderUpdateRevocationTransactionEntity setContext:context];
        if ([DSLocalMasternodeEntity
             countObjectsMatching:@"providerRegistrationTransaction.transactionHash.txHash == %@", uint256_data(self.providerRegistrationTransaction.txHash)] == 0) {
            DSProviderRegistrationTransactionEntity * providerRegistrationTransactionEntity = [DSProviderRegistrationTransactionEntity anyObjectMatching:@"transactionHash.txHash == %@", uint256_data(self.providerRegistrationTransaction.txHash)];
            if (!providerRegistrationTransactionEntity) {
                providerRegistrationTransactionEntity = (DSProviderRegistrationTransactionEntity *)[self.providerRegistrationTransaction save];
            }
            DSLocalMasternodeEntity * localMasternode = [DSLocalMasternodeEntity managedObject];
            [localMasternode setAttributesFromLocalMasternode:self];
            [DSLocalMasternodeEntity saveContext];
        } else {
            DSLocalMasternodeEntity * localMasternode = [DSLocalMasternodeEntity anyObjectMatching:@"providerRegistrationTransaction.transactionHash.txHash == %@", uint256_data(self.providerRegistrationTransaction.txHash)];
            [localMasternode setAttributesFromLocalMasternode:self];
            [DSLocalMasternodeEntity saveContext];
        }
    }];
}

@end