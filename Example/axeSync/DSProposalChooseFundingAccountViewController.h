//
//  DSProposalChooseFundingAccountViewController.h
//  AxeSync_Example
//
//  Created by Sam Westrich on 7/5/18.
//  Copyright © 2018 Axe Core Group. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <AxeSync/AxeSync.h>
#import "DSProposalCreatorViewController.h"

@interface DSProposalChooseFundingAccountViewController : UITableViewController

@property (nonatomic,strong) DSChain * chain;
@property (nonatomic,weak) id<DSAccountChooserDelegate> delegate;

@end
