//
//  DSBLSKey.m
//  AxeSync
//
//  Created by Sam Westrich on 11/3/18.
//

#import "DSBLSKey.h"
#import "NSMutableData+Axe.h"
#import "DSDerivationPath.h"
#import "NSIndexPath+Axe.h"
#import "DSChain.h"
#import "NSString+Axe.h"

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wconversion"
#pragma clang diagnostic ignored "-Wunused-function"
#pragma clang diagnostic ignored "-Wconditional-uninitialized"
#pragma clang diagnostic ignored "-Wdocumentation"
#pragma clang diagnostic ignored "-Wmacro-redefined"
#import <bls-signatures-pod/bls.hpp>
#pragma clang diagnostic pop

@interface DSBLSKey ()

@property (nonatomic, assign) UInt256 secretKey;
@property (nonatomic, assign) UInt384 publicKey;
@property (nonatomic, assign) UInt256 chainCode;
@property (nonatomic, strong) DSChain * chain;
@property (nonatomic, strong) NSData * extendedPrivateKeyData;
@property (nonatomic, strong) NSData * extendedPublicKeyData;

@end

@implementation DSBLSKey

//A little recursive magic since extended private keys can't be re-assigned in the library
+(bls::ExtendedPrivateKey)derive:(bls::ExtendedPrivateKey)extendedPrivateKey indexes:(NSIndexPath*)indexPath {
    if (!indexPath.length) return extendedPrivateKey;
    uint32_t topIndexPath = (uint32_t)[indexPath indexAtPosition:0];
    bls::ExtendedPrivateKey skChild = extendedPrivateKey.PrivateChild(topIndexPath);
    return [self derive:skChild indexes:[indexPath indexPathByRemovingFirstIndex]];
}

+(BOOL)canPublicDerive:(NSIndexPath*)indexPath {
    for (int i = 0; i < [indexPath length]; i++ ) {
        uint32_t index = (uint32_t)[indexPath indexAtPosition:0];
        if (index >> 31 == 1) return NO;
    }
    return YES;
}

+(bls::ExtendedPublicKey)publicDerive:(bls::ExtendedPublicKey)extendedPublicKey indexes:(NSIndexPath*)indexPath {
    if (!indexPath.length) return extendedPublicKey;
    uint32_t topIndexPath = (uint32_t)[indexPath indexAtPosition:0];
    NSAssert(topIndexPath >> 31 == 0, @"There should be no hardened derivation if you wish to derive extended public keys");
    bls::ExtendedPublicKey pkChild = extendedPublicKey.PublicChild(topIndexPath);
    return [self publicDerive:pkChild indexes:[indexPath indexPathByRemovingFirstIndex]];
}


+ (nullable instancetype)blsKeyWithPrivateKeyFromSeed:(NSData *)seed onChain:(DSChain*)chain {
    return [[DSBLSKey alloc] initWithPrivateKeyFromSeed:seed onChain:chain];
}

- (nullable instancetype)initWithPrivateKeyFromSeed:(NSData *)seed onChain:(DSChain*)chain {
    if (!(self = [super init])) return nil;
    
    bls::PrivateKey blsPrivateKey = bls::PrivateKey::FromSeed((uint8_t *)seed.bytes, seed.length);
    bls::PublicKey blsPublicKey = blsPrivateKey.GetPublicKey();
    UInt256 secret = UINT256_ZERO;
    blsPrivateKey.Serialize(secret.u8);
    self.secretKey = secret;
    UInt384 publicKey = UINT384_ZERO;
    blsPublicKey.Serialize(publicKey.u8);
    self.publicKey = publicKey;
    
    self.chain = chain;
    
    return self;
}

+ (nullable instancetype)blsKeyWithExtendedPrivateKeyFromSeed:(NSData *)seed onChain:(DSChain*)chain {
    return [[DSBLSKey alloc] initWithExtendedPrivateKeyFromSeed:seed onChain:chain];
}

+ (nullable instancetype)blsKeyWithPublicKey:(UInt384)publicKey onChain:(DSChain*)chain {
    return [[DSBLSKey alloc] initWithPublicKey:publicKey onChain:chain];
}

+ (nullable instancetype)blsKeyByAggregatingPublicKeys:(NSArray<DSBLSKey*>*)publicKeys onChain:(DSChain*)chain {
    bls::PublicKey blsPublicKey = [DSBLSKey aggregatePublicKeys:publicKeys];
    
    UInt384 publicKey = UINT384_ZERO;
    blsPublicKey.Serialize(publicKey.u8);
    
    return [[DSBLSKey alloc] initWithPublicKey:publicKey onChain:chain];
}

- (nullable instancetype)initWithPublicKey:(UInt384)publicKey onChain:(DSChain*)chain {
    if (!(self = [super init])) return nil;
    self.publicKey = publicKey;
    self.chain = chain;
    
    return self;
}

+ (nullable instancetype)blsKeyWithPrivateKey:(UInt256)secretKey onChain:(DSChain*)chain {
    return [[DSBLSKey alloc] initWithPrivateKey:secretKey onChain:chain];
}

- (nullable instancetype)initWithPrivateKey:(UInt256)secretKey onChain:(DSChain*)chain {
    if (!(self = [super init])) return nil;
    self.secretKey = secretKey;
    bls::PrivateKey blsPrivateKey = bls::PrivateKey::FromBytes((const uint8_t *)secretKey.u8);
    bls::PublicKey blsPublicKey = blsPrivateKey.GetPublicKey();
    UInt384 publicKey = UINT384_ZERO;
    blsPublicKey.Serialize(publicKey.u8);
    self.publicKey = publicKey;
    self.chain = chain;
    
    return self;
}

+ (nullable instancetype)blsKeyWithExtendedPublicKeyData:(NSData*)extendedPublicKey onChain:(DSChain*)chain {
    return [[DSBLSKey alloc] initWithExtendedPublicKeyData:extendedPublicKey onChain:chain];
}
- (nullable instancetype)initWithExtendedPublicKeyData:(NSData*)extendedPublicKey onChain:(DSChain*)chain {
    bls::ExtendedPublicKey extendedPublicBLSKey = bls::ExtendedPublicKey::FromBytes((const uint8_t *)extendedPublicKey.bytes);
    return [self initWithExtendedBLSPublicKey:extendedPublicBLSKey onChain:chain];
}

- (nullable instancetype)initWithExtendedPrivateKeyFromSeed:(NSData *)seed onChain:(DSChain*)chain {
    if (!(self = [super init])) return nil;
    
    bls::ExtendedPrivateKey blsExtendedPrivateKey = bls::ExtendedPrivateKey::FromSeed((uint8_t *)seed.bytes, seed.length);
    
    return [self initWithExtendedPrivateKey:blsExtendedPrivateKey onChain:chain];
}

- (nullable instancetype)initWithExtendedPrivateKey:(bls::ExtendedPrivateKey)blsExtendedPrivateKey onChain:(DSChain*)chain {
    if (!self || !(self = [super init])) return nil;
    
    uint8_t blsExtendedPrivateKeyBytes[bls::ExtendedPrivateKey::EXTENDED_PRIVATE_KEY_SIZE];
    
    blsExtendedPrivateKey.Serialize(blsExtendedPrivateKeyBytes);
    NSMutableData * blsExtendedPrivateKeyData = [NSMutableData secureDataWithCapacity:bls::ExtendedPrivateKey::EXTENDED_PRIVATE_KEY_SIZE];
    [blsExtendedPrivateKeyData appendBytes:blsExtendedPrivateKeyBytes length:bls::ExtendedPrivateKey::EXTENDED_PRIVATE_KEY_SIZE];
    self.extendedPrivateKeyData = blsExtendedPrivateKeyData;
    
    uint8_t blsExtendedPublicKeyBytes[bls::ExtendedPublicKey::EXTENDED_PUBLIC_KEY_SIZE];
    
    blsExtendedPrivateKey.GetExtendedPublicKey().Serialize(blsExtendedPublicKeyBytes);
    
    NSMutableData * blsExtendedPublicKeyData = [NSMutableData secureDataWithCapacity:bls::ExtendedPublicKey::EXTENDED_PUBLIC_KEY_SIZE];
    [blsExtendedPublicKeyData appendBytes:blsExtendedPublicKeyBytes length:bls::ExtendedPublicKey::EXTENDED_PUBLIC_KEY_SIZE];
    self.extendedPublicKeyData = blsExtendedPublicKeyData;
    
    UInt256 blsChainCode;
    blsExtendedPrivateKey.GetChainCode().Serialize(blsChainCode.u8);
    self.chainCode = blsChainCode;
    
    bls::PrivateKey blsPrivateKey = blsExtendedPrivateKey.GetPrivateKey();
    bls::PublicKey blsPublicKey = blsPrivateKey.GetPublicKey();
    UInt256 secret = UINT256_ZERO;
    blsPrivateKey.Serialize(secret.u8);
    self.secretKey = secret;
    UInt384 publicKey = UINT384_ZERO;
    blsPublicKey.Serialize(publicKey.u8);
    self.publicKey = publicKey;
    
    self.chain = chain;
    
    return self;
}

- (nullable instancetype)initWithExtendedBLSPublicKey:(bls::ExtendedPublicKey)blsExtendedPublicKey onChain:(DSChain*)chain {
    if (!self || !(self = [super init])) return nil;
    
    uint8_t blsExtendedPublicKeyBytes[bls::ExtendedPublicKey::EXTENDED_PUBLIC_KEY_SIZE];
    
    blsExtendedPublicKey.Serialize(blsExtendedPublicKeyBytes);
    NSMutableData * blsExtendedPublicKeyData = [NSMutableData secureDataWithCapacity:bls::ExtendedPublicKey::EXTENDED_PUBLIC_KEY_SIZE];
    [blsExtendedPublicKeyData appendBytes:blsExtendedPublicKeyBytes length:bls::ExtendedPublicKey::EXTENDED_PUBLIC_KEY_SIZE];
    self.extendedPublicKeyData = blsExtendedPublicKeyData;
    
    UInt256 blsChainCode;
    blsExtendedPublicKey.GetChainCode().Serialize(blsChainCode.u8);
    self.chainCode = blsChainCode;
    
    self.secretKey = UINT256_ZERO;
    
    bls::PublicKey blsPublicKey = blsExtendedPublicKey.GetPublicKey();
    
    UInt384 publicKey = UINT384_ZERO;
    blsPublicKey.Serialize(publicKey.u8);
    self.publicKey = publicKey;
    
    self.chain = chain;
    
    return self;
}

-(uint32_t)publicKeyFingerprint {
    bls::PublicKey blsPublicKey = bls::PublicKey::FromBytes(self.publicKey.u8);
    return blsPublicKey.GetFingerprint();
}

-(NSData*)publicKeyData {
    return [NSData dataWithUInt384:self.publicKey];
}

-(NSData*)secretKeyData {
    if (uint256_is_zero(self.secretKey)) return nil;
    return [NSData dataWithUInt256:self.secretKey];
}

-(NSString*)secretKeyString {
    if (uint256_is_zero(self.secretKey)) return @"";
    return [NSData dataWithUInt256:self.secretKey].hexString;
}

- (NSString *)privateKeyStringForChain:(DSChain*)chain
{
    if (uint256_is_zero(self.secretKey)) return nil;
    
    NSMutableData *d = [NSMutableData secureDataWithCapacity:sizeof(UInt256) + 2];
    uint8_t version;
    if ([chain isMainnet]) {
        version = AXE_PRIVKEY;
    } else {
        version = AXE_PRIVKEY_TEST;
    }
    
    [d appendBytes:&version length:1];
    [d appendUInt256:self.secretKey];
    [d appendBytes:"\x02" length:1];
    return [NSString base58checkWithData:d];
}

// MARK: - Derivation

-(DSBLSKey*)deriveToPath:(NSIndexPath*)derivationPath {
    bls::ExtendedPrivateKey blsExtendedPrivateKey = bls::ExtendedPrivateKey::FromBytes((const uint8_t *)self.extendedPrivateKeyData.bytes);
    bls::ExtendedPrivateKey derivedExtendedPrivateKey = [DSBLSKey derive:blsExtendedPrivateKey indexes:derivationPath];
    return [[DSBLSKey alloc] initWithExtendedPrivateKey:derivedExtendedPrivateKey onChain:self.chain];
}

-(DSBLSKey*)publicDeriveToPath:(NSIndexPath*)derivationPath {
    if (!self.extendedPublicKeyData.length && !self.extendedPrivateKeyData.length) return nil;
    bls::ExtendedPublicKey blsExtendedPublicKey = [self blsExtendedPublicKey];

    bls::ExtendedPublicKey derivedExtendedPublicKey = [DSBLSKey publicDerive:blsExtendedPublicKey indexes:derivationPath];
    return [[DSBLSKey alloc] initWithExtendedBLSPublicKey:derivedExtendedPublicKey onChain:self.chain];
}

-(bls::ExtendedPublicKey)blsExtendedPublicKey {
    if (self.extendedPublicKeyData.length) {
        bls::ExtendedPublicKey blsExtendedPublicKey = bls::ExtendedPublicKey::FromBytes((const uint8_t *)self.extendedPublicKeyData.bytes);
        
        return blsExtendedPublicKey;
    } else if (self.extendedPrivateKeyData.length) {
        bls::ExtendedPrivateKey blsExtendedPrivateKey = bls::ExtendedPrivateKey::FromBytes((const uint8_t *)self.extendedPrivateKeyData.bytes);
        
        return blsExtendedPrivateKey.GetExtendedPublicKey();
    } else {
        uint8_t bytes[] = {};
        return bls::ExtendedPublicKey::FromBytes(bytes);
    }
}

-(bls::PrivateKey)blsPrivateKey {
    if (!uint256_is_zero(self.secretKey)) {
        bls::PrivateKey blsPrivateKey = bls::PrivateKey::FromBytes(self.secretKey.u8);
        
        return blsPrivateKey;
    } else if (self.extendedPrivateKeyData.length) {
        bls::ExtendedPrivateKey blsExtendedPrivateKey = bls::ExtendedPrivateKey::FromBytes((const uint8_t *)self.extendedPrivateKeyData.bytes);
        return blsExtendedPrivateKey.GetPrivateKey();
    } else {
        bls::PrivateKey blsPrivateKey = bls::PrivateKey::FromBytes(self.secretKey.u8);
        return blsPrivateKey;
    }
}

-(bls::PublicKey)blsPublicKey {
    if (!uint384_is_zero(self.publicKey)) {
        bls::PublicKey blsPublicKey = bls::PublicKey::FromBytes(self.publicKey.u8);
        
        return blsPublicKey;
    } else {
        bls::PrivateKey blsPrivateKey = [self blsPrivateKey];
        bls::PublicKey blsPublicKey = blsPrivateKey.GetPublicKey();
        return blsPublicKey;
    }
}

// MARK: - Signing

- (UInt768)signData:(NSData *)data {
    if (uint256_is_zero(self.secretKey) && !self.extendedPrivateKeyData.length) return UINT768_ZERO;
    bls::PrivateKey blsPrivateKey = [self blsPrivateKey];
    UInt256 hash = [data SHA256_2];
    bls::InsecureSignature blsSignature = blsPrivateKey.SignInsecurePrehashed(hash.u8);
    UInt768 signature = UINT768_ZERO;
    blsSignature.Serialize(signature.u8);
    return signature;
}

- (UInt768)signDataSingleSHA256:(NSData *)data {
    if (uint256_is_zero(self.secretKey) && !self.extendedPrivateKeyData.length) return UINT768_ZERO;
    bls::PrivateKey blsPrivateKey = [self blsPrivateKey];
    UInt256 hash = [data SHA256];
    bls::InsecureSignature blsSignature = blsPrivateKey.SignInsecurePrehashed(hash.u8);
    UInt768 signature = UINT768_ZERO;
    blsSignature.Serialize(signature.u8);
    return signature;
}

- (UInt768)signDigest:(UInt256)md {
    if (uint256_is_zero(self.secretKey) && !self.extendedPrivateKeyData.length) return UINT768_ZERO;
    bls::PrivateKey blsPrivateKey = [self blsPrivateKey];
    bls::InsecureSignature blsSignature = blsPrivateKey.SignInsecurePrehashed(md.u8);
    UInt768 signature = UINT768_ZERO;
    blsSignature.Serialize(signature.u8);
    return signature;
}

// MARK: - Verification

- (BOOL)verify:(UInt256)messageDigest signature:(UInt768)signature {
    bls::PublicKey blsPublicKey = [self blsPublicKey];
    bls::AggregationInfo aggregationInfo = bls::AggregationInfo::FromMsgHash(blsPublicKey, messageDigest.u8);
    bls::Signature blsSignature = bls::Signature::FromBytes(signature.u8, aggregationInfo);
    return blsSignature.Verify();
}


+ (BOOL)verify:(UInt256)messageDigest signature:(UInt768)signature withPublicKey:(UInt384)publicKey {
    bls::PublicKey blsPublicKey = [[[DSBLSKey alloc] initWithPublicKey:publicKey onChain:[DSChain mainnet]] blsPublicKey]; //chain won't matter
    bls::AggregationInfo aggregationInfo = bls::AggregationInfo::FromMsgHash(blsPublicKey, messageDigest.u8);
    bls::Signature blsSignature = bls::Signature::FromBytes(signature.u8, aggregationInfo);
    return blsSignature.Verify();
}

+(BOOL)verifySecureAggregated:(UInt256)messageDigest signature:(UInt768)signature withPublicKeys:(NSArray*)publicKeys
{
    std::vector<bls::AggregationInfo> infos;
    for (DSBLSKey * key in publicKeys) {
        bls::AggregationInfo aggregationInfo = bls::AggregationInfo::FromMsgHash([key blsPublicKey], messageDigest.u8);
        infos.push_back(aggregationInfo);
    }
    
    bls::AggregationInfo aggregationInfo = bls::AggregationInfo::MergeInfos(infos);
    bls::Signature blsSignature = bls::Signature::FromBytes(signature.u8, aggregationInfo);
    
    return blsSignature.Verify();
}

// MARK: - Public Key Aggregation

+ (bls::PublicKey)aggregatePublicKeys:(NSArray*)publicKeys {
    __block std::vector<bls::PublicKey> vectorList;
    [publicKeys enumerateObjectsUsingBlock:^(DSBLSKey * _Nonnull key, NSUInteger idx, BOOL * _Nonnull stop) {
        vectorList.push_back([key blsPublicKey]);
    }];
    bls::PublicKey blsPublicKey = bls::PublicKey::Aggregate(vectorList);
    return blsPublicKey;
}

// MARK: - Signature Aggregation

+ (UInt768)aggregateSignatures:(NSArray*)signatures withPublicKeys:(NSArray*)publicKeys withMessages:(NSArray*)messages {
    std::vector<bls::Signature> blsSignatures = {};
    for (int i = 0; i < [signatures count];i++) {
        NSData * signatureData = signatures[i];
        NSData * publicKeyData = publicKeys[i];
        NSData * messageData = messages[i];
        UInt768 signature = [signatureData UInt768];
        UInt384 publickey = [publicKeyData UInt384];
        bls::PublicKey blsPublicKey = bls::PublicKey::FromBytes(publickey.u8);
        bls::AggregationInfo aggregationInfo = bls::AggregationInfo::FromMsg(blsPublicKey,(const uint8_t*)messageData.bytes,messageData.length);
        bls::Signature blsSignature = bls::Signature::FromBytes(signature.u8,aggregationInfo);
        blsSignatures.push_back(blsSignature);
    }
    bls::Signature blsAggregateSignature = bls::Signature::AggregateSigs(blsSignatures);
    UInt768 signature = UINT768_ZERO;
    blsAggregateSignature.Serialize(signature.u8);
    return signature;
}

@end
