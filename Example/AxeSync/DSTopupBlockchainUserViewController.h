//
//  DSTopupBlockchainUserViewController.h
//  AxeSync_Example
//
//  Created by Sam Westrich on 8/16/18.
//  Copyright © 2018 Axe Core Group. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "DSWalletChooserViewController.h"
#import "DSAccountChooserViewController.h"

@interface DSTopupBlockchainUserViewController : UITableViewController <DSWalletChooserDelegate,DSAccountChooserDelegate>

@property (nonatomic,strong) DSChainPeerManager * chainPeerManager;
@property (nonatomic,strong) DSBlockchainUser * blockchainUser;

@end
