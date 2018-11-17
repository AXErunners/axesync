//
//  DSDAPICallsViewController.h
//  AxeSync_Example
//
//  Created by Sam Westrich on 9/13/18.
//  Copyright © 2018 Axe Core Group. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <AxeSync/AxeSync.h>

@interface DSDAPICallsViewController : UITableViewController

@property (nonatomic,strong) DSChainPeerManager * chainPeerManager;

@end
