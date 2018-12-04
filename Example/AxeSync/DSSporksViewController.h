//
//  DSSporksViewController.h
//  AxeSync_Example
//
//  Created by Sam Westrich on 5/29/18.
//  Copyright © 2018 Dash Core Group. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <AxeSync/AxeSync.h>

@interface DSSporksViewController : UITableViewController

@property(nonatomic,strong) DSChain * chain;
@property(nonatomic,strong) NSMutableArray * sporksArray;

@end
