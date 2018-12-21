//
//  DSTransactionFactory.h
//  AxeSync
//
//  Created by Sam Westrich on 7/12/18.
//

#import <Foundation/Foundation.h>
#import "DSTransaction.h"
#import "DSCoinbaseTransaction.h"

//Special Transaction
typedef NS_ENUM(NSUInteger, DSTransactionType) {
    DSTransactionType_Classic = 0,
    DSTransactionType_ProviderRegistration = 1,
    DSTransactionType_ProviderUpdateService = 2,
    DSTransactionType_ProviderUpdateRegistrar = 3,
    DSTransactionType_ProviderUpdateRevocation = 4,
    DSTransactionType_Coinbase = 5,
    DSTransactionType_SubscriptionRegistration = 8,
    DSTransactionType_SubscriptionTopUp = 9,
    DSTransactionType_SubscriptionResetKey = 10,
    DSTransactionType_SubscriptionCloseAccount = 11,
    DSTransactionType_Transition = 12,
};

@interface DSTransactionFactory : NSObject

+(DSTransaction*)transactionWithMessage:(NSData*)data onChain:(DSChain*)chain;

@end
