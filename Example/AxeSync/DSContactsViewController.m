//
//  DSContactsViewController.m
//  AxeSync_Example
//
//  Created by Andrew Podkovyrin on 08/03/2019.
//  Copyright © 2019 Axe Core Group. All rights reserved.
//

#import "DSContactsViewController.h"
#import "DSContactTableViewCell.h"
#import "DSContactReceivedTransactionsTableViewController.h"
#import "DSContactSentTransactionsTableViewController.h"
#import "DSContactSendAxeViewController.h"
#import "DSContactRelationshipInfoViewController.h"
#import "DSContactRelationshipActionsViewController.h"

static NSString * const CellId = @"CellId";

@interface DSContactsViewController ()

@end

@implementation DSContactsViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
}

- (void)setBlockchainIdentity:(DSBlockchainIdentity *)blockchainIdentity {
    _blockchainIdentity = blockchainIdentity;
    
    self.title = blockchainIdentity.currentAxepayUsername;
}

- (IBAction)refreshAction:(id)sender {
    [self.refreshControl beginRefreshing];
    __weak typeof(self) weakSelf = self;
    [self.blockchainIdentity fetchContactRequests:^(BOOL success, NSArray<NSError *> *errors) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) {
            return;
        }
        if (!success && errors.count) {
            [self showAlertTitle:[errors[0] localizedDescription] result:NO];
        }
        [strongSelf.refreshControl endRefreshing];
        
    }];
}

- (NSString *)entityName {
    return @"DSAxepayUserEntity";
}

-(NSPredicate*)predicate {
    return [NSPredicate predicateWithFormat:@"ANY friends == %@",[self.blockchainIdentity matchingAxepayUserInContext:self.context]];
}

- (NSArray<NSSortDescriptor *> *)sortDescriptors {
    NSSortDescriptor *usernameSortDescriptor = [[NSSortDescriptor alloc] initWithKey:@"associatedBlockchainIdentity.axepayUsername.stringValue" ascending:YES];
    return @[usernameSortDescriptor];
}

#pragma mark - Table view data source

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    DSContactTableViewCell *cell = (DSContactTableViewCell *)[tableView dequeueReusableCellWithIdentifier:@"ContactCellIdentifier" forIndexPath:indexPath];
    
    // Configure the cell...
    [self configureCell:cell atIndexPath:indexPath];
    return cell;
}

-(void)configureCell:(DSContactTableViewCell*)cell atIndexPath:(NSIndexPath *)indexPath {
    DSAxepayUserEntity * friend = [self.fetchedResultsController objectAtIndexPath:indexPath];
    cell.textLabel.text = friend.username;
}

#pragma mark - Private

- (void)showAlertTitle:(NSString *)title result:(BOOL)result {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:title message:result ? @"✅ success" : @"❌ failure" preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

-(void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    NSIndexPath * selectedIndex = self.tableView.indexPathForSelectedRow;
    DSAxepayUserEntity * axepayFriend = [self.fetchedResultsController objectAtIndexPath:selectedIndex];
    DSAxepayUserEntity * me = [self.blockchainIdentity matchingAxepayUserInContext:self.context];
    DSFriendRequestEntity * meToFriend = [[me.outgoingRequests filteredSetUsingPredicate:[NSPredicate predicateWithFormat:@"destinationContact == %@",axepayFriend]] anyObject];
    DSFriendRequestEntity * friendToMe = [[me.incomingRequests filteredSetUsingPredicate:[NSPredicate predicateWithFormat:@"sourceContact == %@",axepayFriend]] anyObject];
    NSAssert(meToFriend, @"We are friends after all - us to them");
    NSAssert(friendToMe, @"We are friends after all - them to us");
    if ([segue.identifier isEqualToString:@"ContactTransactionsSegue"]) {
        UITabBarController * tabBarController = segue.destinationViewController;
        tabBarController.title = axepayFriend.username;
        for (UIViewController * controller in tabBarController.viewControllers) {
            if ([controller isKindOfClass:[DSContactReceivedTransactionsTableViewController class]]) {
                DSContactReceivedTransactionsTableViewController *receivedTransactionsController = (DSContactReceivedTransactionsTableViewController *)controller;
                receivedTransactionsController.chainManager = self.chainManager;
                receivedTransactionsController.blockchainIdentity = self.blockchainIdentity;
                receivedTransactionsController.friendRequest = meToFriend;
            } else if ([controller isKindOfClass:[DSContactSentTransactionsTableViewController class]]) {
                DSContactSentTransactionsTableViewController *sentTransactionsController = (DSContactSentTransactionsTableViewController *)controller;
                sentTransactionsController.chainManager = self.chainManager;
                sentTransactionsController.blockchainIdentity = self.blockchainIdentity;
                sentTransactionsController.friendRequest = friendToMe;
            } else if ([controller isKindOfClass:[DSContactSendAxeViewController class]]) {
                ((DSContactSendAxeViewController*)controller).blockchainIdentity = self.blockchainIdentity;
                ((DSContactSendAxeViewController*)controller).contact = axepayFriend;
            } else if ([controller isKindOfClass:[DSContactRelationshipInfoViewController class]]) {
                ((DSContactRelationshipInfoViewController*)controller).blockchainIdentity = self.blockchainIdentity;
                ((DSContactRelationshipInfoViewController*)controller).incomingFriendRequest = friendToMe;
                ((DSContactRelationshipInfoViewController*)controller).outgoingFriendRequest = meToFriend;
            }  else if ([controller isKindOfClass:[DSContactRelationshipActionsViewController class]]) {
                ((DSContactRelationshipInfoViewController*)controller).blockchainIdentity = self.blockchainIdentity;
                ((DSContactRelationshipInfoViewController*)controller).incomingFriendRequest = friendToMe;
                ((DSContactRelationshipInfoViewController*)controller).outgoingFriendRequest = meToFriend;
            }
        }
    }
}


@end
