//
//  DSBlockchainIdentityTableViewCell.h
//  AxeSync_Example
//
//  Created by Sam Westrich on 7/26/18.
//  Copyright © 2018 Dash Core Group. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "BRCopyLabel.h"

@interface DSBlockchainIdentityTableViewCell : UITableViewCell
@property (strong, nonatomic) IBOutlet UILabel *usernameLabel;
@property (strong, nonatomic) IBOutlet UILabel *creditBalanceLabel;
@property (strong, nonatomic) IBOutlet UILabel *confirmationsLabel;
@property (strong, nonatomic) IBOutlet UILabel *registrationL2StatusLabel;
@property (strong, nonatomic) IBOutlet UILabel *publicKeysLabel;

@end
