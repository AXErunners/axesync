//
//  DSAuthenticationKeysDerivationPathsAddressesViewController.h
//  AxeSync_Example
//
//  Created by Sam Westrich on 3/11/19.
//  Copyright © 2019 Axe Core Group. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <AxeSync/AxeSync.h>
#import <CoreData/CoreData.h>

NS_ASSUME_NONNULL_BEGIN

@interface DSAuthenticationKeysDerivationPathsAddressesViewController : UITableViewController <NSFetchedResultsControllerDelegate,UISearchBarDelegate>

@property(nonatomic,strong) DSSimpleIndexedDerivationPath * derivationPath;

@end


NS_ASSUME_NONNULL_END
