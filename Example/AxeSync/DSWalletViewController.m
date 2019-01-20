//
//  DSWalletViewController.m
//  AxeSync_Example
//
//  Created by Sam Westrich on 4/20/18.
//  Copyright © 2018 Dash Core Group. All rights reserved.
//

#import "DSWalletViewController.h"
#import "NSManagedObject+Sugar.h"
#import "DSWalletTableViewCell.h"
#import <AxeSync/AxeSync.h>
#import "DSWalletInputPhraseViewController.h"
#import "DSAccountsViewController.h"

@interface DSWalletViewController ()

@property (nonatomic,strong) id<NSObject> chainWalletObserver;

@end

@implementation DSWalletViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.chainWalletObserver =
    [[NSNotificationCenter defaultCenter] addObserverForName:DSChainWalletsDidChangeNotification object:nil
                                                       queue:nil usingBlock:^(NSNotification *note) {
                                                           [self.tableView reloadData];
                                                       }];
    
    // Do any additional setup after loading the view.
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

-(NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [self.chain.wallets count];
}

-(NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

-(UITableViewCell*)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    DSWalletTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"WalletCellIdentifier"];
    
    // Set up the cell...
    [self configureCell:cell atIndexPath:indexPath];
    return cell;
}

-(void)configureCell:(DSWalletTableViewCell*)walletCell atIndexPath:(NSIndexPath *)indexPath {
    @autoreleasepool {
        DSWallet * wallet = [[self.chain wallets] objectAtIndex:indexPath.row];
        NSString * passphrase = [wallet seedPhraseIfAuthenticated];
        NSArray * components = [passphrase componentsSeparatedByString:@" "];
        NSMutableArray * lines = [NSMutableArray array];
        for (int i = 0;i<[components count];i+=4) {
            [lines addObject:[[components subarrayWithRange:NSMakeRange(i, 4)] componentsJoinedByString:@" "]];
        }
        
        walletCell.passphraseLabel.text = [lines componentsJoinedByString:@"\n"];
        DSAccount * account0 = [wallet accountWithNumber:0];
        walletCell.xPublicKeyLabel.text = [[account0 bip44DerivationPath] serializedExtendedPublicKey];
        walletCell.showPassphraseButton.hidden = [[DSAuthenticationManager sharedInstance] didAuthenticate];
        walletCell.actionDelegate = self;
    }
}

-(CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section == 0) return 200;
    return 50;
}

-(BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    return TRUE;
}

-(void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        [self.tableView beginUpdates];
        [self.chain unregisterWallet:[self.chain.wallets objectAtIndex:indexPath.row]];
        [self.tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
        [self.tableView endUpdates];
    }
}

-(void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if ([segue.identifier isEqualToString:@"AddWalletSegue"]) {
        DSWalletInputPhraseViewController * walletInputViewController = (DSWalletInputPhraseViewController*)segue.destinationViewController;
        walletInputViewController.chain = self.chain;
    } else if ([segue.identifier isEqualToString:@"ViewAccountsSegue"]) {
        NSIndexPath *indexPath = [self.tableView indexPathForCell:sender];
        DSAccountsViewController * accountsViewController = (DSAccountsViewController*)segue.destinationViewController;
        accountsViewController.wallet = [self.chain.wallets objectAtIndex:indexPath.row];
    }
}

-(void)walletTableViewCellDidRequestAuthentication:(DSWalletTableViewCell*)cell {
    [[DSAuthenticationManager sharedInstance] authenticateWithPrompt:@"" andTouchId:FALSE alertIfLockout:FALSE completion:^(BOOL authenticatedOrSuccess, BOOL cancelled) {
        if (authenticatedOrSuccess) {
            [self.tableView reloadData];
        }
    }];
}

@end
