//
//  DSWalletTableViewCell.m
//  AxeSync_Example
//
//  Created by Sam Westrich on 4/20/18.
//  Copyright © 2018 Axe Core Group. All rights reserved.
//

#import "DSWalletTableViewCell.h"

@implementation DSWalletTableViewCell

- (void)awakeFromNib {
    [super awakeFromNib];
    // Initialization code
}

- (void)setSelected:(BOOL)selected animated:(BOOL)animated {
    [super setSelected:selected animated:animated];

    // Configure the view for the selected state
}

- (IBAction)showPassphrase:(id)sender {
    [self.actionDelegate walletTableViewCellDidForAuthentication:self];
}
@end
