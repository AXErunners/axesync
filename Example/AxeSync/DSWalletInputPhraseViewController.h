//
//  DSWalletInputPhraseViewController.h
//  AxeSync_Example
//
//  Created by Sam Westrich on 5/18/18.
//  Copyright © 2018 Axe Core Group. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <AxeSync/AxeSync.h>

@interface DSWalletInputPhraseViewController : UIViewController <UITextViewDelegate>

@property (nonatomic, strong) DSChain * chain;

@end
