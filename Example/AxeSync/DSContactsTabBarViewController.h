//
//  DSContactsTabBarViewController.h
//  AxeSync_Example
//
//  Created by Andrew Podkovyrin on 08/03/2019.
//  Copyright © 2019 Axe Core Group. All rights reserved.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@class DSChainManager, DSBlockchainIdentity;


@interface DSContactsTabBarViewController : UITabBarController

@property (nonatomic,strong) DSChainManager * chainManager;
@property (nonatomic,strong) DSBlockchainIdentity * blockchainIdentity;

@end

NS_ASSUME_NONNULL_END
