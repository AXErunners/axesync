//
//  DSTransaction+Protected.h
//  AxeSync
//
//  Created by Sam Westrich on 4/9/19.
//

#import "DSTransaction.h"

NS_ASSUME_NONNULL_BEGIN

@interface DSTransaction ()

@property (nonatomic, assign) BOOL saved; //don't trust this
@property (nonatomic, readonly) DSTransactionEntity * transactionEntity;

@end

NS_ASSUME_NONNULL_END
