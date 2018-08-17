//
//  DSMasternodeViewController.h
//  AxeSync_Example
//
//  Created by Sam Westrich on 6/10/18.
//  Copyright © 2018 Axe Core Group. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <AxeSync/AxeSync.h>

@interface DSMasternodeViewController : UITableViewController<NSFetchedResultsControllerDelegate,UISearchBarDelegate>

@property (nonatomic,strong) DSChain * chain;

@end
