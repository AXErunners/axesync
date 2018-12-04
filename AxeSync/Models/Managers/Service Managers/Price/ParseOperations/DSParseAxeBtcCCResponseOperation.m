//
//  Created by Andrew Podkovyrin
//  Copyright © 2018 Dash Core Group. All rights reserved.
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

#import "DSParseAxeBtcCCResponseOperation.h"

NS_ASSUME_NONNULL_BEGIN

@interface DSParseAxeBtcCCResponseOperation ()

@property (strong, nonatomic, nullable) NSNumber *axeBtcPrice;

@end

@implementation DSParseAxeBtcCCResponseOperation

- (void)execute {
    NSParameterAssert(self.responseToParse);

    NSDictionary *response = (NSDictionary *)self.responseToParse;
    if (![response isKindOfClass:NSDictionary.class]) {
        [self cancelWithError:[self.class invalidResponseErrorWithUserInfo:@{NSDebugDescriptionErrorKey : response}]];

        return;
    }

    NSDictionary *raw = response[@"RAW"];
    if (![raw isKindOfClass:NSDictionary.class]) {
        [self cancelWithError:[self.class invalidResponseErrorWithUserInfo:@{NSDebugDescriptionErrorKey : response}]];

        return;
    }

    NSNumber *axeBtcPrice = raw[@"PRICE"];
    if (![axeBtcPrice isKindOfClass:NSNumber.class]) {
        [self cancelWithError:[self.class invalidResponseErrorWithUserInfo:@{NSDebugDescriptionErrorKey : response}]];

        return;
    }

    self.axeBtcPrice = axeBtcPrice;

    [self finish];
}

@end

NS_ASSUME_NONNULL_END
