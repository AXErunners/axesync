//
//  DSTransactionDetailViewController.h
//  AxeSync_Example
//
//  Created by Sam Westrich on 7/8/18.
//  Copyright © 2018 Axe Core Group. All rights reserved.
//

#import <UIKit/UIKit.h>

@class DSTransaction;

@interface DSTransactionDetailViewController : UITableViewController

@property (nonatomic, strong) DSTransaction *transaction;
@property (nonatomic, strong) NSString *txDateString;

@end
