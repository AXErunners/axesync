//
//  DSIncomingContactsTableViewController.h
//  AxeSync_Example
//
//  Created by Andrew Podkovyrin on 15/03/2019.
//  Copyright © 2019 Dash Core Group. All rights reserved.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@class DSContactsModel;

@interface DSIncomingContactsTableViewController : UITableViewController

@property (strong, nonatomic) DSContactsModel *model;

@end

NS_ASSUME_NONNULL_END
