//
//  DSDerivationPath+Protected.h
//  AxeSync
//
//  Created by Sam Westrich on 2/10/19.
//

#import "DSDerivationPath.h"
#import "DSAccount.h"
#import "DSWallet.h"
#import "DSECDSAKey.h"
#import "DSAddressEntity+CoreDataClass.h"
#import "DSChain.h"
#import "DSTransaction.h"
#import "DSTransactionEntity+CoreDataClass.h"
#import "DSTxInputEntity+CoreDataClass.h"
#import "DSTxOutputEntity+CoreDataClass.h"
#import "DSDerivationPathEntity+CoreDataClass.h"
#import "DSPeerManager.h"
#import "DSKeySequence.h"
#import "NSData+Bitcoin.h"
#import "NSMutableData+Axe.h"
#import "NSManagedObject+Sugar.h"
#import "DSPriceManager.h"
#import "NSString+Bitcoin.h"
#import "NSString+Axe.h"
#import "NSData+Bitcoin.h"
#import "DSBlockchainIdentity.h"
#import "DSBLSKey.h"

NS_ASSUME_NONNULL_BEGIN

@interface DSDerivationPath ()

@property (nonatomic, assign) BOOL addressesLoaded;
@property (nonatomic, strong) NSManagedObjectContext * managedObjectContext;
@property (nonatomic, strong) NSMutableSet *mAllAddresses, *mUsedAddresses;
@property (nonatomic, strong) DSKey * extendedPublicKey;//master public key used to generate wallet addresses
@property (nonatomic, strong) NSString * standaloneExtendedPublicKeyUniqueID;
@property (nonatomic, weak) DSWallet * wallet;
@property (nonatomic, nullable, readonly) NSString * standaloneExtendedPublicKeyLocationString;
@property (nonatomic, readonly) DSDerivationPathEntity * derivationPathEntity;

-(DSDerivationPathEntity*)derivationPathEntityInContext:(NSManagedObjectContext*)context;


@end

NS_ASSUME_NONNULL_END
