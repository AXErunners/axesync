//
//  DSStandaloneDerivationPathKeyInputViewController.m
//  AxeSync_Example
//
//  Created by Sam Westrich on 6/10/18.
//  Copyright © 2018 Dash Core Group. All rights reserved.
//

#import "DSStandaloneDerivationPathKeyInputViewController.h"
#import <AxeSync/AxeSync.h>

@interface DSStandaloneDerivationPathKeyInputViewController ()

@property (strong, nonatomic) IBOutlet UITextView *inputKeyTextView;
@property (strong, nonatomic) IBOutlet UIBarButtonItem *saveButton;

@end

@implementation DSStandaloneDerivationPathKeyInputViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.saveButton.enabled = FALSE;
    // Do any additional setup after loading the view.
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

-(void)textViewDidChange:(UITextView *)textView {
    if ([textView.text isValidAxePrivateKeyOnChain:self.chain] || [textView.text isValidAxeExtendedPublicKeyOnChain:self.chain]) {
        self.saveButton.enabled = TRUE;
    } else {
        self.saveButton.enabled = FALSE;
    }
}

- (IBAction)createDerivationPath:(id)sender {
    if ([self.inputKeyTextView.text isValidAxeExtendedPublicKeyOnChain:self.chain]) {
        DSDerivationPath * derivationPath = [DSDerivationPath derivationPathWithSerializedExtendedPublicKey:self.inputKeyTextView.text onChain:self.chain];
        [self.chain registerStandaloneDerivationPath:derivationPath];
        [self.navigationController popViewControllerAnimated:TRUE];
    } else if ([self.inputKeyTextView.text isValidAxePrivateKeyOnChain:self.chain]) {
        DSDerivationPath * derivationPath = [DSDerivationPath derivationPathWithSerializedExtendedPublicKey:self.inputKeyTextView.text onChain:self.chain];
        [self.chain registerStandaloneDerivationPath:derivationPath];
        [self.navigationController popViewControllerAnimated:TRUE];
    }
}

@end
