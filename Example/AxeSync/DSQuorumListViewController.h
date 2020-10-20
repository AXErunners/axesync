//
//  DSQuorumListViewController.h
//  AxeSync_Example
//
//  Created by Sam Westrich on 5/15/19.
//  Copyright © 2019 Axe Core Group. All rights reserved.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@class DSChain;

@interface DSQuorumListViewController : UITableViewController<NSFetchedResultsControllerDelegate,UISearchBarDelegate>

@property (nonatomic,strong) DSChain * chain;

@end

NS_ASSUME_NONNULL_END
