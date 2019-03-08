//
//  DSWalletDetailViewController.h
//  AxeSync_Example
//
//  Created by Sam Westrich on 3/6/19.
//  Copyright © 2019 Dash Core Group. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <AxeSync/AxeSync.h>

NS_ASSUME_NONNULL_BEGIN

@interface DSWalletDetailViewController : UITableViewController

@property (nonatomic, strong) DSWallet * wallet;

@end

NS_ASSUME_NONNULL_END
