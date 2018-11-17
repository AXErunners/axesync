//
//  DSProposalCreatorViewController.h
//  AxeSync_Example
//
//  Created by Sam Westrich on 7/5/18.
//  Copyright © 2018 Axe Core Group. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <AxeSync/AxeSync.h>
#import "DSAccountChooserViewController.h"

@interface DSProposalCreatorViewController : UITableViewController <UITextFieldDelegate,DSAccountChooserDelegate>

@property (nonatomic,strong) DSChainPeerManager * chainPeerManager;

@end

