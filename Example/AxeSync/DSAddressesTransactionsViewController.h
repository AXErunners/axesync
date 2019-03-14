//
//  DSAddressesTransactionsViewController.h
//  AxeSync_Example
//
//  Created by Sam Westrich on 6/22/18.
//  Copyright © 2018 Dash Core Group. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <AxeSync/AxeSync.h>

@interface DSAddressesTransactionsViewController : UITableViewController <NSFetchedResultsControllerDelegate>

@property(nonatomic,strong) NSString * address;
@property(nonatomic,strong) DSWallet * wallet;

@end
