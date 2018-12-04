//
//  DSAddDevnetViewController.m
//  AxeSync_Example
//
//  Created by Sam Westrich on 6/19/18.
//  Copyright © 2018 Andrew Podkovyrin. All rights reserved.
//

#import "DSAddDevnetViewController.h"
#import "DSKeyValueTableViewCell.h"
#import "DSAddDevnetIPAddressTableViewCell.h"
#import "DSAddDevnetAddIPAddressTableViewCell.h"
#import <AxeSync/AxeSync.h>

@interface DSAddDevnetViewController ()

@property (nonatomic,strong) NSMutableOrderedSet<NSString*> * insertedIPAddresses;
@property (nonatomic,strong) DSKeyValueTableViewCell * addDevnetNameTableViewCell;
@property (nonatomic,strong) DSKeyValueTableViewCell * sporkAddressTableViewCell;
@property (nonatomic,strong) DSKeyValueTableViewCell * sporkPrivateKeyTableViewCell;
@property (nonatomic,strong) DSKeyValueTableViewCell * protocolVersionTableViewCell;
@property (nonatomic,strong) DSKeyValueTableViewCell * minProtocolVersionTableViewCell;
@property (nonatomic,strong) DSKeyValueTableViewCell * dapiPortTableViewCell;
@property (nonatomic,strong) DSKeyValueTableViewCell * axedPortTableViewCell;

@property (nonatomic,strong) DSAddDevnetAddIPAddressTableViewCell * addDevnetAddIPAddressTableViewCell;
@property (nonatomic,strong) DSAddDevnetIPAddressTableViewCell * activeAddDevnetIPAddressTableViewCell;

@end

@implementation DSAddDevnetViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.addDevnetNameTableViewCell = [self.tableView dequeueReusableCellWithIdentifier:@"DevnetNameCellIdentifier"];
    self.addDevnetAddIPAddressTableViewCell = [self.tableView dequeueReusableCellWithIdentifier:@"DevnetAddIPCellIdentifier"];
    self.sporkAddressTableViewCell = [self.tableView dequeueReusableCellWithIdentifier:@"DevnetSporkAddressCellIdentifier"];
    self.sporkPrivateKeyTableViewCell = [self.tableView dequeueReusableCellWithIdentifier:@"DevnetSporkPrivateKeyCellIdentifier"];
    self.protocolVersionTableViewCell = [self.tableView dequeueReusableCellWithIdentifier:@"DevnetProtocolVersionCellIdentifier"];
    self.minProtocolVersionTableViewCell = [self.tableView dequeueReusableCellWithIdentifier:@"DevnetMinProtocolVersionCellIdentifier"];
    self.dapiPortTableViewCell = [self.tableView dequeueReusableCellWithIdentifier:@"DapiPortCellIdentifier"];
    self.axedPortTableViewCell = [self.tableView dequeueReusableCellWithIdentifier:@"AxedPortCellIdentifier"];
    if (!self.chain) {
        self.insertedIPAddresses = [NSMutableOrderedSet orderedSet];
    } else {
        DSPeerManager * peerManager = [[DSChainsManager sharedInstance] chainManagerForChain:self.chain].peerManager;
        self.insertedIPAddresses = [NSMutableOrderedSet orderedSetWithArray:peerManager.registeredDevnetPeerServices];
        self.addDevnetNameTableViewCell.valueTextField.text = self.chain.devnetIdentifier;
        self.protocolVersionTableViewCell.valueTextField.text = [NSString stringWithFormat:@"%u",self.chain.protocolVersion];
        self.minProtocolVersionTableViewCell.valueTextField.text = [NSString stringWithFormat:@"%u",self.chain.minProtocolVersion];
        self.sporkPrivateKeyTableViewCell.valueTextField.text = self.chain.sporkPrivateKey;
        self.sporkAddressTableViewCell.valueTextField.text = self.chain.sporkAddress;
        self.addDevnetNameTableViewCell.userInteractionEnabled = FALSE;
    }
    
    // Do any additional setup after loading the view.
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

// MARK:- Table View Data Source

-(NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 3;
}

-(NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    switch (section) {
        case 0:
            return 5;
            break;
        case 1:
            return 2;
            break;
        default:
            return 2 + _insertedIPAddresses.count;
            break;
    }
}

-(DSAddDevnetIPAddressTableViewCell*)IPAddressCellAtIndex:(NSUInteger)index {
    static NSString * CellIdentifier = @"DevnetIPCellIdentifier";
    DSAddDevnetIPAddressTableViewCell * addDevnetIPAddressTableViewCell = [self.tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (index < _insertedIPAddresses.count) {
        addDevnetIPAddressTableViewCell.IPAddressTextField.text = [_insertedIPAddresses objectAtIndex:index];
    } else {
        addDevnetIPAddressTableViewCell.IPAddressTextField.text = @"";
    }
    addDevnetIPAddressTableViewCell.IPAddressTextField.delegate = self;
    return addDevnetIPAddressTableViewCell;
}

-(UITableViewCell*)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    switch (indexPath.section) {
        case 0:
        {
            switch (indexPath.row) {
                case 0:
                    return self.addDevnetNameTableViewCell;
                case 1:
                    return self.protocolVersionTableViewCell;
                case 2:
                    return self.minProtocolVersionTableViewCell;
                case 3:
                    return self.axedPortTableViewCell;
                case 4:
                    return self.dapiPortTableViewCell;
                default:
                    NSAssert(NO, @"Unknown cell");
                    return [[UITableViewCell alloc] init];
            }
        }
        case 1:
            switch (indexPath.row) {
                case 0:
                    return self.sporkAddressTableViewCell;
                case 1:
                    return self.sporkPrivateKeyTableViewCell;
                default:
                    NSAssert(NO, @"Unknown cell");
                    return [[UITableViewCell alloc] init];
            }
        case 2:
        {    if (indexPath.row == _insertedIPAddresses.count + 1) return self.addDevnetAddIPAddressTableViewCell;
            return [self IPAddressCellAtIndex:indexPath.row];
            
        }
    }
    NSAssert(NO, @"Unknown cell");
    return [[UITableViewCell alloc] init];

}

// MARK:- Table View Data Delegate

-(void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section == 2 && indexPath.row == _insertedIPAddresses.count + 1) {
        if (self.activeAddDevnetIPAddressTableViewCell) {
            NSIndexPath * activeIndexPath = [self.tableView indexPathForCell:self.activeAddDevnetIPAddressTableViewCell];
            if (activeIndexPath.row == indexPath.row - 1) {
                if (![self.insertedIPAddresses containsObject:self.activeAddDevnetIPAddressTableViewCell.IPAddressTextField.text]) {
                [self.tableView beginUpdates];
                [self.activeAddDevnetIPAddressTableViewCell.IPAddressTextField resignFirstResponder];
//                [self.insertedIPAddresses addObject:self.activeAddDevnetIPAddressTableViewCell.IPAddressTextField.text];
                [self.tableView insertRowsAtIndexPaths:@[[NSIndexPath indexPathForRow:_insertedIPAddresses.count inSection:1]] withRowAnimation:UITableViewRowAnimationTop];
                [self.tableView endUpdates];
                }
            }
        }
    }
}

// MARK:- Text Field Delegate

-(void)textFieldDidBeginEditing:(UITextField *)textField {
    for (UITableViewCell * tableViewCell in self.tableView.visibleCells) {
        if ([tableViewCell isMemberOfClass:[DSAddDevnetIPAddressTableViewCell class]]) {
            DSAddDevnetIPAddressTableViewCell * addDevnetIPAddressTableViewCell = (DSAddDevnetIPAddressTableViewCell *)tableViewCell;
            if (addDevnetIPAddressTableViewCell.IPAddressTextField == textField) {
                self.activeAddDevnetIPAddressTableViewCell = addDevnetIPAddressTableViewCell;
            }
        }
    }
}

-(BOOL)textFieldShouldReturn:(UITextField *)textField {
    [self.tableView beginUpdates];
    if ([self.activeAddDevnetIPAddressTableViewCell.IPAddressTextField.text isEqualToString:@""]) {
        NSIndexPath * indexPath = [self.tableView indexPathForCell:self.activeAddDevnetIPAddressTableViewCell];
        [self.insertedIPAddresses removeObjectAtIndex:indexPath.row];
        [self.tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
    }
    [self.activeAddDevnetIPAddressTableViewCell.IPAddressTextField resignFirstResponder];
    [self.tableView endUpdates];
    return NO;
}

-(void)textFieldDidEndEditing:(UITextField *)textField reason:(UITextFieldDidEndEditingReason)reason {
    if (![self.activeAddDevnetIPAddressTableViewCell.IPAddressTextField.text isEqualToString:@""]) {
    if (![self.insertedIPAddresses containsObject:self.activeAddDevnetIPAddressTableViewCell.IPAddressTextField.text]) {
        [self.insertedIPAddresses addObject:self.activeAddDevnetIPAddressTableViewCell.IPAddressTextField.text];
    } else {
        self.activeAddDevnetIPAddressTableViewCell.IPAddressTextField.text = @"";
    }
    }
    self.activeAddDevnetIPAddressTableViewCell = nil;
}


// MARK:- Navigation

-(void)showError:(NSString*)errorMessage {
    
}

-(IBAction)save {
    [self.activeAddDevnetIPAddressTableViewCell.IPAddressTextField resignFirstResponder];
    uint32_t protocolVersion = [self.protocolVersionTableViewCell.valueTextField.text intValue];
    uint32_t minProtocolVersion = [self.minProtocolVersionTableViewCell.valueTextField.text intValue];
    NSString * sporkAddress = [self.sporkAddressTableViewCell.valueTextField.text isEqualToString:@""]?nil:self.sporkAddressTableViewCell.valueTextField.text;
    NSString * sporkPrivateKey = [self.sporkPrivateKeyTableViewCell.valueTextField.text isEqualToString:@""]?nil:self.sporkPrivateKeyTableViewCell.valueTextField.text;
    uint32_t axedPort = [self.axedPortTableViewCell.valueTextField.text isEqualToString:@""]?DEVNET_STANDARD_PORT:[self.axedPortTableViewCell.valueTextField.text intValue];
    uint32_t dapiPort = [self.dapiPortTableViewCell.valueTextField.text isEqualToString:@""]?DEVNET_DAPI_STANDARD_PORT:[self.dapiPortTableViewCell.valueTextField.text intValue];
    if (![sporkAddress isValidAxeDevnetAddress]) {
        sporkAddress = nil;
    }
    if (![sporkPrivateKey isValidAxeDevnetPrivateKey]) {
        sporkPrivateKey = nil;
    }
    if (self.chain) {
        [[DSChainsManager sharedInstance] updateDevnetChain:self.chain forServiceLocations:self.insertedIPAddresses standardPort:axedPort dapiPort:dapiPort protocolVersion:protocolVersion minProtocolVersion:minProtocolVersion sporkAddress:sporkAddress sporkPrivateKey:sporkPrivateKey];
    } else {
        NSString * identifier = self.addDevnetNameTableViewCell.valueTextField.text;
        [[DSChainsManager sharedInstance] registerDevnetChainWithIdentifier:identifier forServiceLocations:self.insertedIPAddresses standardPort:axedPort dapiPort:dapiPort protocolVersion:protocolVersion minProtocolVersion:minProtocolVersion sporkAddress:sporkAddress sporkPrivateKey:sporkPrivateKey];
    }
    [self.presentingViewController dismissViewControllerAnimated:TRUE completion:nil];
}

-(IBAction)cancel {
    [self.presentingViewController dismissViewControllerAnimated:TRUE completion:nil];
}

@end
