//
//  DSAccountsDerivationPathsViewController.m
//  AxeSync_Example
//
//  Created by Sam Westrich on 6/3/18.
//  Copyright © 2018 Axe Core Group. All rights reserved.
//

#import "DSAccountsDerivationPathsViewController.h"
#import "DSDerivationPathTableViewCell.h"
#import "DSDerivationPathsAddressesViewController.h"
#import "DSSendAmountViewController.h"

@interface DSAccountsDerivationPathsViewController ()

@end

@implementation DSAccountsDerivationPathsViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    // Uncomment the following line to preserve selection between presentations.
    // self.clearsSelectionOnViewWillAppear = NO;
    
    // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
    // self.navigationItem.rightBarButtonItem = self.editButtonItem;
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {

    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {

    return [self.account.derivationPaths count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    DSDerivationPathTableViewCell *cell = (DSDerivationPathTableViewCell *)[tableView dequeueReusableCellWithIdentifier:@"DerivationPathCellIdentifier" forIndexPath:indexPath];
    
    // Configure the cell...
    [self configureCell:cell atIndexPath:indexPath];
    return cell;
}


-(void)configureCell:(DSDerivationPathTableViewCell*)cell atIndexPath:(NSIndexPath *)indexPath {
    DSDerivationPath * derivationPath = [self.account.derivationPaths objectAtIndex:indexPath.row];
    cell.xPublicKeyLabel.text = derivationPath.serializedExtendedPublicKey;
    cell.derivationPathLabel.text = derivationPath.stringRepresentation;
    cell.balanceLabel.text = [[DSPriceManager sharedInstance] stringForAxeAmount:derivationPath.balance];
}


/*
// Override to support conditional editing of the table view.
- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    // Return NO if you do not want the specified item to be editable.
    return YES;
}
*/

/*
// Override to support editing the table view.
- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        // Delete the row from the data source
        [tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
    } else if (editingStyle == UITableViewCellEditingStyleInsert) {
        // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view
    }   
}
*/

/*
// Override to support rearranging the table view.
- (void)tableView:(UITableView *)tableView moveRowAtIndexPath:(NSIndexPath *)fromIndexPath toIndexPath:(NSIndexPath *)toIndexPath {
}
*/

/*
// Override to support conditional rearranging of the table view.
- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath {
    // Return NO if you do not want the item to be re-orderable.
    return YES;
}
*/

-(void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if ([segue.identifier isEqualToString:@"ViewAddressesSegue"]) {
        NSIndexPath *indexPath = [self.tableView indexPathForCell:sender];
        DSDerivationPathsAddressesViewController * derivationPathsAddressesViewController = (DSDerivationPathsAddressesViewController*)segue.destinationViewController;
        derivationPathsAddressesViewController.derivationPath = [self.account.derivationPaths objectAtIndex:indexPath.row];
    } else if ([segue.identifier isEqualToString:@"SendAmountSegue"]) {
        DSSendAmountViewController * sendAmountViewController = (DSSendAmountViewController*)(((UINavigationController*)segue.destinationViewController).topViewController);
        sendAmountViewController.account = self.account;
    }
}


@end
