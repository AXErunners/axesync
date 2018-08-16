//
//  DSDerivationPathTableViewCell.h
//  AxeSync_Example
//
//  Created by Sam Westrich on 6/3/18.
//  Copyright © 2018 Axe Core Group. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface DSDerivationPathTableViewCell : UITableViewCell

@property (strong, nonatomic) IBOutlet UILabel *xPublicKeyLabel;
@property (strong, nonatomic) IBOutlet UILabel *balanceLabel;
@property (strong, nonatomic) IBOutlet UILabel *derivationPathLabel;
@property (strong, nonatomic) IBOutlet UILabel *transactionsCountLabel;

@end
