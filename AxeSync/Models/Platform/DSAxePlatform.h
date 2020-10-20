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

#import <Foundation/Foundation.h>
#import "DPDocumentFactory.h"

#define DPNS_CONTRACT @"DPNS_CONTRACT"
#define AXEPAY_CONTRACT @"AXEPAY_CONTRACT"

NS_ASSUME_NONNULL_BEGIN

@class DSChain,DPContract;

@interface DSAxePlatform : NSObject

@property (readonly, strong, nonatomic) DPContract *axePayContract;
@property (readonly, strong, nonatomic) DPContract *dpnsContract;
@property (readonly, strong, nonatomic) NSMutableDictionary* knownContracts;

@property (readonly, strong, nonatomic) DSChain *chain;

- (instancetype)init NS_UNAVAILABLE;

- (DPDocumentFactory*)documentFactoryForBlockchainIdentity:(DSBlockchainIdentity*)blockchainIdentity forContract:(DPContract*)contract;

+ (NSString*)nameForContractWithIdentifier:(NSString*)identifier;

+ (instancetype)sharedInstanceForChain:(DSChain*)chain;

@end

NS_ASSUME_NONNULL_END
