//
//  DSGovernanceObjectListViewController.h
//  AxeSync_Example
//
//  Created by Sam Westrich on 6/15/18.
//  Copyright © 2018 Axe Core Group. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <AxeSync/AxeSync.h>

@interface DSGovernanceObjectListViewController : UITableViewController<NSFetchedResultsControllerDelegate,UISearchBarDelegate>

@property (nonatomic,strong) DSChainPeerManager * chainPeerManager;

@end
