//
//  DSAuthenticationManager.m
//  AxeSync
//
//  Created by Sam Westrich on 5/27/18.
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.


#import "DSAuthenticationManager.h"
#import "DSEventManager.h"
#import "DSAccount.h"
#import "DSWallet.h"
#import "DSChain.h"
#import "DSChainsManager.h"
#import "DSPriceManager.h"
#import "DSDerivationPath.h"
#import "DSBIP39Mnemonic.h"
#import "NSMutableData+Axe.h"
#import "DSVersionManager.h"
#import "NSData+Bitcoin.h"
#import <LocalAuthentication/LocalAuthentication.h>
#import "NSDate+Utils.h"
#import "UIWindow+DSUtils.h"

static NSString *sanitizeString(NSString *s)
{
    NSMutableString *sane = [NSMutableString stringWithString:(s) ? s : @""];
    
    CFStringTransform((CFMutableStringRef)sane, NULL, kCFStringTransformToUnicodeName, NO);
    return sane;
}

#define SECURE_TIME_KEY     @"SECURE_TIME"
#define PIN_KEY             @"pin"
#define PIN_FAIL_COUNT_KEY  @"pinfailcount"
#define PIN_FAIL_HEIGHT_KEY @"pinfailheight"
#define CIRCLE  @"\xE2\x97\x8C" // dotted circle (utf-8)
#define DOT     @"\xE2\x97\x8F" // black circle (utf-8)
#define LOCK    @"\xF0\x9F\x94\x92" // unicode lock symbol U+1F512 (utf-8)
#define REDX    @"\xE2\x9D\x8C"     // unicode cross mark U+274C, red x emoji (utf-8)

typedef BOOL (^PinVerificationBlock)(NSString * _Nonnull currentPin,DSAuthenticationManager * context);

@interface DSAuthenticationManager()

@property (nonatomic, strong) UITextField *pinField;
@property (nonatomic, strong) NSMutableSet *failedPins;
@property (nonatomic, copy) PinVerificationBlock pinVerificationBlock;
@property (nonatomic, strong) UIAlertController *pinAlertController;
@property (nonatomic, strong) UIAlertController *resetAlertController;
@property (nonatomic, strong) id keyboardObserver,backgroundObserver;

@end

@implementation DSAuthenticationManager

+ (instancetype)sharedInstance
{
    static id singleton = nil;
    static dispatch_once_t onceToken = 0;
    
    dispatch_once(&onceToken, ^{
        singleton = [self new];
    });
    
    return singleton;
}

- (instancetype)init
{
    if (! (self = [super init])) return nil;
    
    self.failedPins = [NSMutableSet set];
    self.usesAuthentication = YES;
    
    self.keyboardObserver = [[NSNotificationCenter defaultCenter] addObserverForName:UIKeyboardWillChangeFrameNotification object:nil queue:nil usingBlock:^(NSNotification * _Nonnull note) {
        if ([self pinAlertControllerIsVisible]) {
            CGFloat alertHeight = self.pinAlertController.view.frame.size.height;
            CGFloat keyboardHeight = [note.userInfo[UIKeyboardFrameEndUserInfoKey] CGRectValue].size.height;
            CGFloat difference = ([UIScreen mainScreen].bounds.size.height + alertHeight)/2.0 - ([UIScreen mainScreen].bounds.size.height - keyboardHeight) + 20;
            if (difference > 0) {
                [UIView animateWithDuration:0.2 animations:^{
                    self.pinAlertController.view.superview.center = CGPointMake([UIScreen mainScreen].bounds.size.width/2.0, [UIScreen mainScreen].bounds.size.height/2.0 - difference);
                }];
            }
        }
    }];
    
    self.backgroundObserver =
    [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidEnterBackgroundNotification object:nil
                                                       queue:nil usingBlock:^(NSNotification *note) {
                                                           // lockdown the app
                                                           self.didAuthenticate = NO;
                                                           [UIApplication sharedApplication].applicationIconBadgeNumber = 0; // reset app badge number
                                                           
                                                       }];
    
    return self;
}

- (void)dealloc
{
    if (self.keyboardObserver) [[NSNotificationCenter defaultCenter] removeObserver:self.keyboardObserver];
    [NSObject cancelPreviousPerformRequestsWithTarget:self];
}

// MARK: - Helpers

// last known time from an ssl server connection
- (NSTimeInterval)secureTime
{
    return [[NSUserDefaults standardUserDefaults] doubleForKey:SECURE_TIME_KEY];
}

- (void)updateSecureTime:(NSTimeInterval)secureTime {
    [[NSUserDefaults standardUserDefaults] setDouble:secureTime forKey:SECURE_TIME_KEY];
}

- (void)updateSecureTimeFromResponseIfNeeded:(NSHTTPURLResponse *)response {
    NSString *date = response.allHeaderFields[@"Date"];
    if (!date) {
        return;
    }
    NSDataDetector *dataDetector = [NSDataDetector dataDetectorWithTypes:NSTextCheckingTypeDate error:nil];
    NSTextCheckingResult *lastResult = [dataDetector matchesInString:date options:0 range:NSMakeRange(0, date.length)].lastObject;
    if (!lastResult) {
        return;
    }
    NSTimeInterval now = [lastResult date].timeIntervalSince1970;
    if (now > self.secureTime) {
        [self updateSecureTime:now];
    }
}

-(UIViewController *)presentingViewController {
    return [[[UIApplication sharedApplication] keyWindow] ds_presentingViewController];
}

// MARK: - Device

// true if touch id is enabled
- (BOOL)isTouchIdEnabled
{
    if (@available(iOS 11.0, *)) {
        if (![LAContext class]) return FALSE; //sanity check
        LAContext * context = [LAContext new];
        return ([context canEvaluatePolicy:LAPolicyDeviceOwnerAuthenticationWithBiometrics error:nil] && context.biometryType == LABiometryTypeTouchID);
    } else {
        return ([LAContext class] &&
                [[LAContext new] canEvaluatePolicy:LAPolicyDeviceOwnerAuthenticationWithBiometrics error:nil]) ? YES : NO;
    }
}

// true if touch id is enabled
- (BOOL)isFaceIdEnabled
{
    if (@available(iOS 11.0, *)) {
        if (![LAContext class]) return FALSE; //sanity check
        LAContext * context = [LAContext new];
        return ([context canEvaluatePolicy:LAPolicyDeviceOwnerAuthenticationWithBiometrics error:nil] && context.biometryType == LABiometryTypeFaceID);
    } else {
        return FALSE;
    }
}

// true if device passcode is enabled
- (BOOL)isPasscodeEnabled
{
    NSError *error = nil;
    
    if (! [LAContext class]) return YES; // we can only check for passcode on iOS 8 and above
    if ([[LAContext new] canEvaluatePolicy:LAPolicyDeviceOwnerAuthenticationWithBiometrics error:&error]) return YES;
    return (error && error.code == LAErrorPasscodeNotSet) ? NO : YES;
}

// MARK: - Prompts

// generate a description of a transaction so the user can review and decide whether to confirm or cancel
- (NSString *)promptForAmount:(uint64_t)amount
                          fee:(uint64_t)fee
                      address:(NSString *)address
                         name:(NSString *)name
                         memo:(NSString *)memo
                     isSecure:(BOOL)isSecure
                 errorMessage:(NSString*)errorMessage
                localCurrency:(NSString *)localCurrency
          localCurrencyAmount:(NSString *)localCurrencyAmount
{
    DSPriceManager *manager = [DSPriceManager sharedInstance];
    NSString *prompt = (isSecure && name.length > 0) ? LOCK @" " : @"";
    
    //BUG: XXX limit the length of name and memo to avoid having the amount clipped
    if (! isSecure && errorMessage.length > 0) prompt = [prompt stringByAppendingString:REDX @" "];
    if (name.length > 0) prompt = [prompt stringByAppendingString:sanitizeString(name)];
    if (! isSecure && prompt.length > 0) prompt = [prompt stringByAppendingString:@"\n"];
    if (! isSecure || prompt.length == 0) prompt = [prompt stringByAppendingString:address];
    if (memo.length > 0) prompt = [prompt stringByAppendingFormat:@"\n\n%@", sanitizeString(memo)];
    prompt = [prompt stringByAppendingFormat:DSLocalizedString(@"\n\n     amount %@ (%@)", nil),
              [manager stringForAxeAmount:amount - fee], [manager localCurrencyStringForAxeAmount:amount - fee]];
    
    if (localCurrency && localCurrencyAmount && ![localCurrency isEqualToString:manager.localCurrencyCode]) {
        NSNumberFormatter *numberFormatter = [[NSNumberFormatter alloc] init];
        numberFormatter.currencyCode = localCurrency;
        numberFormatter.numberStyle = NSNumberFormatterCurrencyStyle;
        NSNumber *localAmount = [NSDecimalNumber decimalNumberWithString:localCurrencyAmount];
        NSString *requestedAmount = [numberFormatter stringFromNumber:localAmount];
        prompt = [prompt stringByAppendingFormat:DSLocalizedString(@"\n(local requested amount: %@)", nil), requestedAmount];
    }
    
    if (fee > 0) {
        prompt = [prompt stringByAppendingFormat:DSLocalizedString(@"\nnetwork fee +%@ (%@)", nil),
                  [manager stringForAxeAmount:fee], [manager localCurrencyStringForAxeAmount:fee]];
        prompt = [prompt stringByAppendingFormat:DSLocalizedString(@"\n         total %@ (%@)", nil),
                  [manager stringForAxeAmount:amount], [manager localCurrencyStringForAxeAmount:amount]];
    }
    
    return prompt;
}

// MARK: - Pin

- (UITextField *)pinField
{
    if (_pinField) return _pinField;
    _pinField = [UITextField new];
    _pinField.alpha = 0.0;
    _pinField.font = [UIFont systemFontOfSize:0.1];
    _pinField.keyboardType = UIKeyboardTypeNumberPad;
    _pinField.secureTextEntry = YES;
    _pinField.delegate = self;
    return _pinField;
}

-(void)shakeEffectWithCompletion:(void (^ _Nullable)(void))completion {
    // walking the view hierarchy is prone to breaking, but it's still functional even if the animation doesn't work
    UIView *v = [self pinTitleView].superview;
    CGPoint p = v.center;
    
    [UIView animateWithDuration:0.05 delay:0.1 options:UIViewAnimationOptionCurveEaseInOut animations:^{ // shake
        v.center = CGPointMake(p.x + 30.0, p.y);
    } completion:^(BOOL finished) {
        [UIView animateWithDuration:0.5 delay:0.0 usingSpringWithDamping:0.2 initialSpringVelocity:0.0 options:0
                         animations:^{ v.center = p; } completion:^(BOOL finished) {
                             completion();
                         }];
    }];
    
}

-(NSTimeInterval)lockoutWaitTime {
    NSError * error = nil;
    uint64_t failHeight = getKeychainInt(PIN_FAIL_HEIGHT_KEY, &error);
    if (error) {
        return NSIntegerMax;
    }
    uint64_t failCount = getKeychainInt(PIN_FAIL_COUNT_KEY, &error);
    if (error) {
        return NSIntegerMax;
    }
    NSTimeInterval wait = failHeight + pow(6, failCount - 3)*60.0 - self.secureTime;
    return wait;
}

-(void)showResetWalletWithCancelHandler:(ResetCancelHandlerBlock)resetCancelHandlerBlock {
    UIAlertController * alertController = [UIAlertController alertControllerWithTitle:DSLocalizedString(@"recovery phrase", nil) message:nil
                                                                       preferredStyle:UIAlertControllerStyleAlert];
    [alertController addTextFieldWithConfigurationHandler:^(UITextField * _Nonnull textField) {
        textField.autocapitalizationType = UITextAutocapitalizationTypeNone;
        textField.returnKeyType = UIReturnKeyDone;
        textField.font = [UIFont systemFontOfSize:15.0];
        textField.delegate = self;
    }];
    UIAlertAction* cancelButton = [UIAlertAction
                                   actionWithTitle:DSLocalizedString(@"cancel", nil)
                                   style:UIAlertActionStyleCancel
                                   handler:^(UIAlertAction * action) {
                                       if (resetCancelHandlerBlock) {
                                           resetCancelHandlerBlock();
                                       }
                                   }];
    [alertController addAction:cancelButton];
    [self presentAlertController:alertController animated:YES completion:nil];
    self.resetAlertController = alertController;
}

-(void)presentAlertController:(UIAlertController*)alertController animated:(BOOL)animated completion:(void (^ __nullable)(void))completion {
    [[self presentingViewController] presentViewController:alertController animated:animated completion:completion];
}

-(BOOL)pinAlertControllerIsVisible {
    if ([[[self presentingViewController] presentedViewController] isKindOfClass:[UIAlertController class]]) {
        // UIAlertController is presenting.Here
        return TRUE;
    }
    return FALSE;
}

// prompts the user to set or change their wallet pin and returns true if the pin was successfully set
- (void)setBrandNewPinWithCompletion:(void (^ _Nullable)(BOOL success))completion {
    NSString *title = [NSString stringWithFormat:CIRCLE @"\t" CIRCLE @"\t" CIRCLE @"\t" CIRCLE @"\n%@",
                       [NSString stringWithFormat:DSLocalizedString(@"choose passcode for %@", nil), DISPLAY_NAME]];
    if (!self.pinAlertController) {
        self.pinAlertController = [UIAlertController
                                   alertControllerWithTitle:title
                                   message:nil
                                   preferredStyle:UIAlertControllerStyleAlert];
        if (_pinField) self.pinField = nil; // reset pinField so a new one is created
        [self.pinAlertController.view addSubview:self.pinField];
        [self presentAlertController:self.pinAlertController animated:YES completion:^{
            [self->_pinField becomeFirstResponder];
        }];
    } else {
        self.pinField.delegate = nil;
        self.pinField.text = @"";
        self.pinField.delegate = self;
        self.pinAlertController.title = title;
    }
    self.pinVerificationBlock = ^BOOL(NSString * currentPin,DSAuthenticationManager * context) {
        [context setVerifyPin:currentPin withCompletion:completion];
        return TRUE;
    };
}

- (void)setVerifyPin:(NSString*)previousPin withCompletion:(void (^ _Nullable)(BOOL success))completion {
    self.pinField.text = nil;
    
    UIView *v = [self pinTitleView].superview;
    CGPoint p = v.center;
    
    [UIView animateWithDuration:0.1 delay:0.1 options:UIViewAnimationOptionCurveEaseIn animations:^{ // verify pin
        v.center = CGPointMake(p.x - v.bounds.size.width, p.y);
    } completion:^(BOOL finished) {
        self.pinAlertController.title = [NSString stringWithFormat:CIRCLE @"\t" CIRCLE @"\t" CIRCLE @"\t" CIRCLE @"\n%@",
                                         DSLocalizedString(@"verify passcode", nil)];
        v.center = CGPointMake(p.x + v.bounds.size.width*2, p.y);
        [self textField:self.pinField shouldChangeCharactersInRange:NSMakeRange(0, 0) replacementString:@""];
        [UIView animateWithDuration:0.3 delay:0.0 usingSpringWithDamping:0.8 initialSpringVelocity:0 options:0
                         animations:^{ v.center = p; } completion:nil];
    }];
    
    self.pinVerificationBlock = ^BOOL(NSString * currentPin,DSAuthenticationManager * context) {
        if ([currentPin isEqual:previousPin]) {
            context.pinField.text = nil;
            setKeychainString(previousPin, PIN_KEY, NO);
            [[NSUserDefaults standardUserDefaults] setDouble:[NSDate timeIntervalSince1970]
                                                      forKey:PIN_UNLOCK_TIME_KEY];
            [context.pinField resignFirstResponder];
            [context.pinAlertController dismissViewControllerAnimated:TRUE completion:^{
                if (completion) completion(YES);
            }];
            return TRUE;
        }
        
        [context shakeEffectWithCompletion:^{
            [context setBrandNewPinWithCompletion:completion];
        }];
        return FALSE;
    };
}

-(UIView*)getSubviewForView:(UIView*)view withText:(NSString*)text {
    for (UIView * subView in view.subviews) {
        if ([subView isKindOfClass:[UILabel class]] && [((UILabel*)subView).text isEqualToString:text]) return subView;
        UIView * foundView = [self getSubviewForView:subView withText:text];
        if (foundView != nil) return foundView;
    }
    return nil;
}

-(UIView*)pinTitleView {
    return [self getSubviewForView:self.pinAlertController.view withText:self.pinAlertController.title];
}

// prompts the user to set or change their wallet pin and returns true if the pin was successfully set
- (void)setPinWithCompletion:(void (^ _Nullable)(BOOL success))completion
{
    NSError *error = nil;
    NSString *pin = getKeychainString(PIN_KEY, &error);
    
    if (error) {
        if (completion) completion(NO);
        return; // error reading existing pin from keychain
    }
    
    [DSEventManager saveEvent:@"wallet_manager:set_pin"];
    
    if (pin.length == 4) { //already had a pin, replacing it
        [self authenticatePinWithTitle:DSLocalizedString(@"enter old passcode", nil) message:nil alertIfLockout:YES completion:^(BOOL authenticated,BOOL cancelled) {
            if (authenticated) {
                self.didAuthenticate = FALSE;
                UIView *v = [self pinTitleView].superview;
                CGPoint p = v.center;
                
                [UIView animateWithDuration:0.1 delay:0.1 options:UIViewAnimationOptionCurveEaseIn animations:^{
                    v.center = CGPointMake(p.x - v.bounds.size.width, p.y);
                } completion:^(BOOL finished) {
                    self.pinAlertController.title = [NSString stringWithFormat:CIRCLE @"\t" CIRCLE @"\t" CIRCLE @"\t" CIRCLE @"\n%@",
                                                     [NSString stringWithFormat:DSLocalizedString(@"choose passcode for %@", nil), DISPLAY_NAME]];
                    self.pinAlertController.message = nil;
                    v.center = CGPointMake(p.x + v.bounds.size.width*2, p.y);
                    [UIView animateWithDuration:0.3 delay:0.0 usingSpringWithDamping:0.8 initialSpringVelocity:0 options:0
                                     animations:^{ v.center = p; } completion:nil];
                }];
                [self setBrandNewPinWithCompletion:completion];
            } else {
                if (completion) completion(NO);
            }
        }];
    }
    else { //didn't have a pin yet
        [self setBrandNewPinWithCompletion:completion];
    }
}

// MARK: - UITextFieldDelegate

- (BOOL)textField:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range
replacementString:(NSString *)string
{
    if (textField == self.pinField) {
        NSString * currentPin = [textField.text stringByReplacingCharactersInRange:range withString:string];
        NSUInteger l = currentPin.length;
        
        self.pinAlertController.title = [NSString stringWithFormat:@"%@\t%@\t%@\t%@%@", (l > 0 ? DOT : CIRCLE),
                                         (l > 1 ? DOT : CIRCLE), (l > 2 ? DOT : CIRCLE), (l > 3 ? DOT : CIRCLE),
                                         [self.pinAlertController.title substringFromIndex:7]];
        
        if (currentPin.length == 4) {
            
            BOOL verified = self.pinVerificationBlock(currentPin,self);
            self.pinField.delegate = nil;
            self.pinField.text = @"";
            self.pinField.delegate = self;
            if (verified) {
                return NO;
            } else {
                self.pinAlertController.title = [NSString stringWithFormat:CIRCLE @"\t" CIRCLE @"\t" CIRCLE @"\t" CIRCLE @"%@",
                                                 [self.pinAlertController.title substringFromIndex:7]];
            }
        }
    }
    return YES;
}

-(BOOL)textFieldShouldReturn:(UITextField *)textField
{
    if (!textField.secureTextEntry) { //not the pin
        @autoreleasepool { // @autoreleasepool ensures sensitive data will be dealocated immediately
            NSString *phrase = [[DSBIP39Mnemonic sharedInstance] cleanupPhrase:textField.text];
            
            if (! [phrase isEqual:textField.text]) textField.text = phrase;
            NSData * oldData = getKeychainData(EXTENDED_0_PUBKEY_KEY_BIP44_V0, nil);
            NSData * seed = [[DSBIP39Mnemonic sharedInstance] deriveKeyFromPhrase:[[DSBIP39Mnemonic sharedInstance]
                                                                                   normalizePhrase:phrase] withPassphrase:nil];
            DSWallet * wallet = [DSWallet standardWalletWithSeedPhrase:phrase setCreationDate:[NSDate timeIntervalSince1970] forChain:[DSChain mainnet] storeSeedPhrase:NO];
            DSAccount * account = [wallet accountWithNumber:0];
            DSDerivationPath * derivationPath = [account bip44DerivationPath];
            NSData * extendedPublicKey = derivationPath.extendedPublicKey;
            if (extendedPublicKey && ![extendedPublicKey isEqual:oldData]) {
                self.resetAlertController.title = DSLocalizedString(@"recovery phrase doesn't match", nil);
                [self.resetAlertController performSelector:@selector(setTitle:)
                                                withObject:DSLocalizedString(@"recovery phrase", nil) afterDelay:3.0];
            } else if (extendedPublicKey && ![[derivationPath deprecatedIncorrectExtendedPublicKeyFromSeed:seed] isEqual:extendedPublicKey]) {
                self.resetAlertController.title = DSLocalizedString(@"recovery phrase doesn't match", nil);
                [self.resetAlertController performSelector:@selector(setTitle:)
                                                withObject:DSLocalizedString(@"recovery phrase", nil) afterDelay:3.0];
            }
            else {
                if (oldData) {
                    [[DSVersionManager sharedInstance] clearKeychainWalletData];
                }
                setKeychainData(nil, SPEND_LIMIT_KEY, NO);
                setKeychainData(nil, PIN_KEY, NO);
                setKeychainData(nil, PIN_FAIL_COUNT_KEY, NO);
                setKeychainData(nil, PIN_FAIL_HEIGHT_KEY, NO);
                [self.resetAlertController dismissViewControllerAnimated:TRUE completion:^{
                    self.pinAlertController = nil;
                    [self setBrandNewPinWithCompletion:nil];
                }];
            }
        }
    }
    return TRUE;
}

// MARK: - Authentication

- (void)seedWithPrompt:(NSString * _Nullable)authprompt forWallet:(DSWallet* _Nonnull)wallet forAmount:(uint64_t)amount forceAuthentication:(BOOL)forceAuthentication completion:(_Nullable SeedCompletionBlock)completion {
    if (forceAuthentication) {
        [wallet seedWithPrompt:authprompt forAmount:amount completion:completion];
    } else {
        @autoreleasepool {
            NSString * seedPhrase = [wallet seedPhraseIfAuthenticated];
            if (seedPhrase) {
                completion([[DSBIP39Mnemonic sharedInstance] deriveKeyFromPhrase:seedPhrase withPassphrase:nil]);
            } else {
                [wallet seedWithPrompt:authprompt forAmount:amount completion:completion];
            }
        }
    }
}

// prompts user to authenticate with touch id or passcode
- (void)authenticateWithPrompt:(NSString *)authprompt andTouchId:(BOOL)touchId alertIfLockout:(BOOL)alertIfLockout completion:(PinCompletionBlock)completion;
{
    if (!self.usesAuthentication) { //if we don't have authentication
        completion(YES,NO);
        return;
    }
    if (touchId) {
        NSTimeInterval pinUnlockTime = [[NSUserDefaults standardUserDefaults] doubleForKey:PIN_UNLOCK_TIME_KEY];
        LAContext *context = [[LAContext alloc] init];
        NSError *error = nil;
        if ([context canEvaluatePolicy:LAPolicyDeviceOwnerAuthenticationWithBiometrics error:&error] &&
            pinUnlockTime + 7*24*60*60 > [NSDate timeIntervalSince1970] &&
            getKeychainInt(PIN_FAIL_COUNT_KEY, nil) == 0 && getKeychainInt(SPEND_LIMIT_KEY, nil) > 0) {
            
            void(^localAuthBlock)(void) = ^{
                [self performLocalAuthenticationSynchronously:context
                                                       prompt:authprompt
                                                   completion:^(BOOL authenticated, BOOL shouldTryAnotherMethod) {
                                                       if (shouldTryAnotherMethod) {
                                                           [self authenticateWithPrompt:authprompt
                                                                             andTouchId:NO
                                                                         alertIfLockout:alertIfLockout
                                                                             completion:completion];
                                                       }
                                                       else {
                                                           completion(authenticated, NO);
                                                       }
                                                   }];
            };
            
            BOOL shouldPreprompt = NO;
            if (@available(iOS 11.0, *)) {
                if (context.biometryType == LABiometryTypeFaceID) {
                    shouldPreprompt = YES;
                }
            }
            if (authprompt && shouldPreprompt) {
                UIAlertController *alert = [UIAlertController alertControllerWithTitle:DSLocalizedString(@"confirm", nil)
                                                                               message:authprompt
                                                                        preferredStyle:UIAlertControllerStyleAlert];
                UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:DSLocalizedString(@"cancel", nil)
                                                                       style:UIAlertActionStyleCancel
                                                                     handler:^(UIAlertAction * action) {
                                                                         completion(NO, YES);
                                                                     }];
                [alert addAction:cancelAction];
                UIAlertAction *okAction = [UIAlertAction actionWithTitle:DSLocalizedString(@"ok", nil)
                                                                   style:UIAlertActionStyleDefault
                                                                 handler:^(UIAlertAction * action) {
                                                                     localAuthBlock();
                                                                 }];
                [alert addAction:okAction];
                [self presentAlertController:alert animated:YES completion:nil];
            }
            else {
                localAuthBlock();
            }
        }
        else {
            NSLog(@"[LAContext canEvaluatePolicy:] %@", error.localizedDescription);
            
            [self authenticateWithPrompt:authprompt
                              andTouchId:NO
                          alertIfLockout:alertIfLockout
                              completion:completion];
        }
    }
    else {
        // TODO explain reason when touch id is disabled after 30 days without pin unlock
        [self authenticatePinWithTitle:[NSString stringWithFormat:DSLocalizedString(@"passcode for %@", nil),
                                        DISPLAY_NAME] message:authprompt alertIfLockout:alertIfLockout completion:^(BOOL authenticated, BOOL cancelled) {
            if (authenticated) {
                [self.pinAlertController dismissViewControllerAnimated:TRUE completion:^{
                    completion(YES,NO);
                }];
            } else {
                completion(NO,cancelled);
            }
        }];
    }
}

- (void)performLocalAuthenticationSynchronously:(LAContext *)context
                                         prompt:(NSString *)prompt
                                     completion:(void(^)(BOOL authenticated, BOOL shouldTryAnotherMethod))completion {
    [DSEventManager saveEvent:@"wallet_manager:touchid_auth"];
    
    __block NSInteger result = 0;
    context.localizedFallbackTitle = DSLocalizedString(@"passcode", nil);
    [context evaluatePolicy:LAPolicyDeviceOwnerAuthenticationWithBiometrics
            localizedReason:(prompt.length > 0 ? prompt : @" ")
                      reply:^(BOOL success, NSError *error) {
                          result = success ? 1 : error.code;
                      }];
    
    while (result == 0) {
        [[NSRunLoop mainRunLoop] runMode:NSDefaultRunLoopMode
                              beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.1]];
    }
    
    if (result == LAErrorAuthenticationFailed) {
        setKeychainInt(0, SPEND_LIMIT_KEY, NO); // require pin entry for next spend
    }
    else if (result == 1) {
        self.didAuthenticate = YES;
        completion(YES, NO);
        return;
    }
    else if (result == LAErrorUserCancel || result == LAErrorSystemCancel) {
        completion(NO, NO);
        return;
    }
    
    completion(NO, YES);
}

-(void)userLockedOut {
    NSError * error = nil;
    __unused uint64_t failHeight = getKeychainInt(PIN_FAIL_HEIGHT_KEY, &error);
    if (error) {
        return;
    }
    uint64_t failCount = getKeychainInt(PIN_FAIL_COUNT_KEY, &error);
    if (error) {
        return;
    }
    NSTimeInterval wait = [self lockoutWaitTime];
    NSString *unit = DSLocalizedString(@"minutes", nil);
    
    if (wait > pow(6, failCount - 3)) wait = pow(6, failCount - 3); // we don't have secureTime yet
    if (wait < 2.0) wait = 1.0, unit = DSLocalizedString(@"minute", nil);
    
    if (wait >= 60.0) {
        wait /= 60.0;
        unit = (wait < 2.0) ? DSLocalizedString(@"hour", nil) : DSLocalizedString(@"hours", nil);
    }
    UIAlertController * alertController = [UIAlertController
                                           alertControllerWithTitle:DSLocalizedString(@"wallet disabled", nil)
                                           message:[NSString stringWithFormat:DSLocalizedString(@"\ntry again in %d %@", nil),
                                                    (int)wait, unit]
                                           preferredStyle:UIAlertControllerStyleAlert];
    UIAlertAction* resetButton = [UIAlertAction
                                  actionWithTitle:DSLocalizedString(@"reset", nil)
                                  style:UIAlertActionStyleDefault
                                  handler:^(UIAlertAction * action) {
                                      [self showResetWalletWithCancelHandler:nil];
                                  }];
    UIAlertAction* okButton = [UIAlertAction
                               actionWithTitle:DSLocalizedString(@"ok", nil)
                               style:UIAlertActionStyleCancel
                               handler:^(UIAlertAction * action) {
                                   
                               }];
    [alertController addAction:resetButton];
    [alertController addAction:okButton]; //ok button should be on the right side as per Apple guidelines, as reset is the less desireable option
    
    if ([self pinAlertControllerIsVisible]) {
        [_pinField resignFirstResponder];
        [self.pinAlertController dismissViewControllerAnimated:TRUE completion:^{
            [self presentAlertController:alertController animated:YES completion:nil];
        }];
    } else {
        [self presentAlertController:alertController animated:YES completion:nil];
    }
}

- (void)authenticatePinWithTitle:(NSString *)title message:(NSString *)message alertIfLockout:(BOOL)alertIfLockout completion:(PinCompletionBlock)completion
{
    
    //authentication logic is as follows
    //you have 3 failed attempts initially
    //after that you get locked out once immediately with a message saying
    //then you have 4 attempts with exponentially increasing intervals to get your password right
    
    [DSEventManager saveEvent:@"wallet_manager:pin_auth"];
    
    NSError *error = nil;
    NSString *pin = getKeychainString(PIN_KEY, &error);
    
    if (error) {
        completion(NO,NO); // error reading pin from keychain
        return;
    }
    if (pin.length != 4) {
        [self setPinWithCompletion:^(BOOL success) {
            completion(success,NO);
        }];
        return;
    }
    
    uint64_t failCount = getKeychainInt(PIN_FAIL_COUNT_KEY, &error);
    
    if (error) {
        completion(NO,NO);
        return; // error reading failCount from keychain
    }
    
    //// Logic explanation
    
    //  If we have failed 3 or more times
    if (failCount >= 3) {
        
        // When was the last time we failed?
        uint64_t failHeight = getKeychainInt(PIN_FAIL_HEIGHT_KEY, &error);
        
        if (error) {
            completion(NO,NO);
            return; // error reading failHeight from keychain
        }
        NSLog(@"locked out for %f more seconds",failHeight + pow(6, failCount - 3)*60.0 - self.secureTime);
        if (self.secureTime < failHeight + pow(6, failCount - 3)*60.0) { // locked out
            if (alertIfLockout) {
                [self userLockedOut];
            }
            completion(NO,NO);
            return;
        } else {
            //no longer locked out, give the user a try
            message = [(failCount >= 7 ? DSLocalizedString(@"\n1 attempt remaining\n", nil) :
                        [NSString stringWithFormat:DSLocalizedString(@"\n%d attempts remaining\n", nil), 8 - failCount])
                       stringByAppendingString:(message) ? message : @""];
        }
    }
    
    UIAlertController * alert = [UIAlertController
                                 alertControllerWithTitle:[NSString stringWithFormat:CIRCLE @"\t" CIRCLE @"\t" CIRCLE @"\t" CIRCLE @"\n%@",
                                                           (title) ? title : @""]
                                 message:message
                                 preferredStyle:UIAlertControllerStyleAlert];
    self.pinAlertController = alert;
    self.pinField = nil; // reset pinField so a new one is created
    [self.pinAlertController.view addSubview:self.pinField];
    UIAlertAction* cancelButton = [UIAlertAction
                                   actionWithTitle:DSLocalizedString(@"cancel", nil)
                                   style:UIAlertActionStyleCancel
                                   handler:^(UIAlertAction * action) {
                                       completion(NO,YES);
                                   }];
    [self.pinAlertController addAction:cancelButton];
    
    __weak __typeof__(self) weakSelf = self;
    self.pinVerificationBlock = ^BOOL(NSString * currentPin,DSAuthenticationManager * context) {
        __strong __typeof__(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) {
            return NO;
        }

        NSError * error = nil;
        uint64_t failCount = getKeychainInt(PIN_FAIL_COUNT_KEY, &error);
        
        if (error) {
            completion(NO,NO); // error reading failCount from keychain
            [alert dismissViewControllerAnimated:TRUE completion:nil];
            return FALSE;
        }
        
        NSString *pin = getKeychainString(PIN_KEY, &error);
        
        if (error) {
            completion(NO,NO); // error reading pin from keychain
            [alert dismissViewControllerAnimated:TRUE completion:nil];
            return FALSE;
        }
        // count unique attempts before checking success
        if (! [context.failedPins containsObject:currentPin]) setKeychainInt(++failCount, PIN_FAIL_COUNT_KEY, NO);
        
        if ([currentPin isEqual:pin]) { // successful pin attempt
            [context.failedPins removeAllObjects];
            context.didAuthenticate = YES;
            setKeychainInt(0, PIN_FAIL_COUNT_KEY, NO);
            setKeychainInt(0, PIN_FAIL_HEIGHT_KEY, NO);
            
            [[DSChainsManager sharedInstance] resetSpendingLimitsIfAuthenticated];
            [[NSUserDefaults standardUserDefaults] setDouble:[NSDate timeIntervalSince1970]
                                                      forKey:PIN_UNLOCK_TIME_KEY];
            if (completion) completion(YES,NO);
            return TRUE;
        }
        
        if (! [context.failedPins containsObject:currentPin]) {
            [context.failedPins addObject:currentPin];
            
            if (failCount >= 8) { // wipe wallet after 8 failed pin attempts and 24+ hours of lockout
                [[DSVersionManager sharedInstance] clearKeychainWalletData];
                
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_SEC/10), dispatch_get_main_queue(), ^{
                    exit(0);
                });
                if (completion) completion(NO,NO);
                return FALSE;
            }
            
            if (strongSelf.secureTime > getKeychainInt(PIN_FAIL_HEIGHT_KEY, nil)) {
                setKeychainInt(strongSelf.secureTime, PIN_FAIL_HEIGHT_KEY, NO);
            }
            
            if (failCount >= 3) {
                [context.pinAlertController dismissViewControllerAnimated:TRUE completion:^{
                    if (alertIfLockout) {
                        [context userLockedOut]; // wallet disabled
                    }
                    completion(NO,NO);
                }];
                return FALSE;
            }
        }
        [context shakeEffectWithCompletion:^{
            context.pinField.text = @"";
        }];
        return FALSE;
    };
    
    [self presentAlertController:self.pinAlertController animated:YES completion:^{
        if (self->_pinField && ! self->_pinField.isFirstResponder) [self->_pinField becomeFirstResponder];
    }];
}

-(void)requestKeyPasswordForSweepCompletion:(void (^_Nonnull)(DSTransaction *tx, uint64_t fee, NSError *error))sweepCompletion userInfo:(NSDictionary*)userInfo completion:(void (^_Nonnull)(void (^sweepCompletion)(DSTransaction *tx, uint64_t fee, NSError *error),NSDictionary * userInfo, NSString * password))completion cancel:(void (^_Nonnull)(void))cancel {
    
    UIAlertController * alert = [UIAlertController alertControllerWithTitle:DSLocalizedString(@"password protected key", nil) message:nil preferredStyle:UIAlertControllerStyleAlert];
    [alert addTextFieldWithConfigurationHandler:^(UITextField * _Nonnull textField) {
        textField.secureTextEntry = true;
        textField.returnKeyType = UIReturnKeyDone;
        textField.placeholder = DSLocalizedString(@"password", nil);
    }];
    UIAlertAction* cancelButton = [UIAlertAction
                                   actionWithTitle:DSLocalizedString(@"cancel", nil)
                                   style:UIAlertActionStyleCancel
                                   handler:^(UIAlertAction * action) {
                                       cancel();
                                   }];
    UIAlertAction* okButton = [UIAlertAction
                               actionWithTitle:DSLocalizedString(@"ok", nil)
                               style:UIAlertActionStyleDefault
                               handler:^(UIAlertAction * action) {
                                   NSString *password = alert.textFields[0].text;
                                   completion(sweepCompletion,userInfo,password);
                               }];
    [alert addAction:cancelButton];
    [alert addAction:okButton];
    [[self presentingViewController] presentViewController:alert animated:YES completion:nil];
    
}


-(void)badKeyPasswordForSweepCompletion:(void (^_Nonnull)(void))completion cancel:(void (^_Nonnull)(void))cancel {
    
    UIAlertController * alert = [UIAlertController
                                 alertControllerWithTitle:DSLocalizedString(@"password protected key", nil)
                                 message:DSLocalizedString(@"bad password, try again", nil)
                                 preferredStyle:UIAlertControllerStyleAlert];
    UIAlertAction* cancelButton = [UIAlertAction
                                   actionWithTitle:DSLocalizedString(@"cancel", nil)
                                   style:UIAlertActionStyleCancel
                                   handler:^(UIAlertAction * action) {
                                       if (cancel) completion();
                                       
                                   }];
    UIAlertAction* okButton = [UIAlertAction
                               actionWithTitle:DSLocalizedString(@"ok", nil)
                               style:UIAlertActionStyleDefault
                               handler:^(UIAlertAction * action) {
                                   if (completion) completion();
                               }];
    [alert addTextFieldWithConfigurationHandler:^(UITextField *textField) {
        textField.secureTextEntry = true;
        textField.placeholder = @"password";
        textField.clearButtonMode = UITextFieldViewModeWhileEditing;
        textField.borderStyle = UITextBorderStyleRoundedRect;
        textField.returnKeyType = UIReturnKeyDone;
    }];
    [alert addAction:okButton];
    [alert addAction:cancelButton];
    [[self presentingViewController] presentViewController:alert animated:YES completion:^{
        if (self->_pinField && ! self->_pinField.isFirstResponder) [self->_pinField becomeFirstResponder];
    }];
}

@end
