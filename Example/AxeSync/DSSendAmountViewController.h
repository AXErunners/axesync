//
//  DSSendAmountViewController.h
//  AxeSync_Example
//
//  Created by Sam Westrich on 6/23/18.
//  Copyright © 2018 Axe Core Group. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <AxeSync/AxeSync.h>

@interface DSSendAmountViewController : UIViewController <UITextFieldDelegate>

@property (nonatomic,strong) DSAccount * account;

@end
