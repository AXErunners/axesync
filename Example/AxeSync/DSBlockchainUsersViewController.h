//
//  DSBlockchainUsersViewController.h
//  AxeSync_Example
//
//  Created by Sam Westrich on 7/26/18.
//  Copyright © 2018 Axe Core Group. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <AxeSync/AxeSync.h>

@interface DSBlockchainUsersViewController : UITableViewController

@property (nonatomic,strong) DSChainPeerManager * chainPeerManager;

@end
