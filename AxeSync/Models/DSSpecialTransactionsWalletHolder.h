//
//  DSSpecialTransactionsWalletHolder.h
//  AxeSync
//
//  Created by Sam Westrich on 3/5/19.
//

#import <Foundation/Foundation.h>
#import "BigIntTypes.h"

@class DSWallet, DSTransaction, DSBlockchainUserRegistrationTransaction, DSBlockchainUserResetTransaction;

NS_ASSUME_NONNULL_BEGIN

@interface DSSpecialTransactionsWalletHolder : NSObject

@property (nonatomic,readonly) NSArray * allTransactions;

-(instancetype)initWithWallet:(DSWallet*)wallet inContext:(NSManagedObjectContext* _Nullable)managedObjectContext;

-(DSTransaction*)transactionForHash:(UInt256)transactionHash;

- (void)registerTransaction:(DSTransaction*)transaction saveImmediately:(BOOL)saveImmediately;

- (void)removeAllTransactions;

// This gets a blockchain user registration transaction that has a specific public key hash (will change to BLS pub key)
- (DSBlockchainUserRegistrationTransaction*)blockchainUserRegistrationTransactionForPublicKeyHash:(UInt160)publicKeyHash;

// This gets a blockchain user reset transaction that has a specific public key hash (will change to BLS pub key)
- (DSBlockchainUserResetTransaction*)blockchainUserResetTransactionForPublicKeyHash:(UInt160)publicKeyHash;

- (NSArray*)subscriptionTransactionsForRegistrationTransactionHash:(UInt256)blockchainUserRegistrationTransactionHash;

- (UInt256)lastSubscriptionTransactionHashForRegistrationTransactionHash:(UInt256)blockchainUserRegistrationTransactionHash;

// this is used to save transactions atomically with the block, needs to be called before switching threads to save the block
- (void)prepareForIncomingTransactionPersistenceForBlockSaveWithNumber:(uint32_t)blockNumber;

// this is used to save transactions atomically with the block
- (void)persistIncomingTransactionsAttributesForBlockSaveWithNumber:(uint32_t)blockNumber inContext:(NSManagedObjectContext*)context;

@end

NS_ASSUME_NONNULL_END
