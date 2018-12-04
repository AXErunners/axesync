//
//  DSTransactionsViewController.h
//  AxeSync_Example
//
//  Created by Sam Westrich on 7/8/18.
//  Copyright © 2018 Dash Core Group. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <AxeSync/AxeSync.h>

@interface DSTransactionsViewController : UITableViewController <NSFetchedResultsControllerDelegate>

@property (nonatomic,strong) DSChainManager * chainManager;

@end
