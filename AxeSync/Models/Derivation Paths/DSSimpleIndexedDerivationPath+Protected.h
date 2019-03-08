//
//  DSSimpleIndexedDerivationPath+Protected.h
//  AxeSync
//
//  Created by Sam Westrich on 2/20/19.
//

#import "DSSimpleIndexedDerivationPath.h"

NS_ASSUME_NONNULL_BEGIN

@interface DSSimpleIndexedDerivationPath ()

@property (nonatomic, strong) NSMutableArray *mOrderedAddresses;

- (NSArray *)registerAddressesWithGapLimit:(NSUInteger)gapLimit;

@end

NS_ASSUME_NONNULL_END
