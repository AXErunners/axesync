//
//  DSReclaimMasternodeViewController.h
//  AxeSync_Example
//
//  Created by Sam Westrich on 2/28/19.
//  Copyright © 2019 Axe Core Group. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "DSAccountChooserViewController.h"

NS_ASSUME_NONNULL_BEGIN

@class DSLocalMasternode;

@interface DSReclaimMasternodeViewController : UITableViewController

@property (nonatomic,strong) DSLocalMasternode * localMasternode;

@end

NS_ASSUME_NONNULL_END
