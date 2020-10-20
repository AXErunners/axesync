//
//  Created by Andrew Podkovyrin
//  Copyright © 2019 Axe Core Group. All rights reserved.
//
//  Licensed under the MIT License (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//  https://opensource.org/licenses/MIT
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

#import "DSAxePlatform.h"
#import "DSChain.h"
#import "DPContract.h"
#import "DSDAPINetworkService.h"

@interface DSAxePlatform ()

@property (strong, nonatomic) DSChain *chain;
@property (strong, nonatomic, null_resettable) NSMutableDictionary* knownContracts;
@property (strong, nonatomic) DPContract *axePayContract;
@property (strong, nonatomic) DPContract *dpnsContract;

@end

@implementation DSAxePlatform

- (instancetype)initWithChain:(DSChain*)chain {

    self = [super init];
    if (self) {
        _chain = chain; //must come first
    }
    return self;
}

static NSMutableDictionary * _platformChainDictionary = nil;
static dispatch_once_t platformChainToken = 0;

+(instancetype)sharedInstanceForChain:(DSChain*)chain {
    
    NSParameterAssert(chain);
    
    dispatch_once(&platformChainToken, ^{
        _platformChainDictionary = [NSMutableDictionary dictionary];
    });
       DSAxePlatform * platformForChain = nil;
       @synchronized(self) {
           if (![_platformChainDictionary objectForKey:chain.uniqueID]) {
               platformForChain = [[DSAxePlatform alloc] initWithChain:chain];
               [_platformChainDictionary setObject:platformForChain forKey:chain.uniqueID];
           } else {
               platformForChain = [_platformChainDictionary objectForKey:chain.uniqueID];
           }
       }
    return platformForChain;
}

- (DPDocumentFactory*)documentFactoryForBlockchainIdentity:(DSBlockchainIdentity*)blockchainIdentity forContract:(DPContract*)contract {
    DPDocumentFactory * documentFactory = [[DPDocumentFactory alloc] initWithBlockchainIdentity:blockchainIdentity contract:contract onChain:self.chain];
    return documentFactory;
}

+ (NSString*)nameForContractWithIdentifier:(NSString*)identifier {
    if ([identifier hasPrefix:AXEPAY_CONTRACT]) {
        return @"AxePay";
    } else if ([identifier hasPrefix:DPNS_CONTRACT]) {
        return @"DPNS";
    }
    return @"Unnamed Contract";
}

-(NSMutableDictionary*)knownContracts {
    if (!_knownContracts) {
        _knownContracts = [NSMutableDictionary dictionaryWithObjects:@[[self axePayContract], [self dpnsContract]] forKeys:@[AXEPAY_CONTRACT,DPNS_CONTRACT]];
    }
    return _knownContracts;
}

-(DPContract*)axePayContract {
    if (!_axePayContract) {
        _axePayContract = [DPContract localAxepayContractForChain:self.chain];
    }
    return _axePayContract;
}

-(DPContract*)dpnsContract {
    if (!_dpnsContract) {
        _dpnsContract = [DPContract localDPNSContractForChain:self.chain];
    }
    return _dpnsContract;
}

@end

