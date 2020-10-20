//
//  DSFundsDerivationPathsAddressesViewController.h
//  AxeSync_Example
//
//  Created by Sam Westrich on 6/3/18.
//  Copyright © 2018 Dash Core Group. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <AxeSync/AxeSync.h>
#import <CoreData/CoreData.h>

@interface DSDoubleDerivationPathsAddressesViewController : UITableViewController <NSFetchedResultsControllerDelegate,UISearchBarDelegate>

@property(nonatomic,strong) DSFundsDerivationPath * derivationPath;

@end
