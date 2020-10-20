//  
//  Created by Sam Westrich
//  Copyright © 2020 Axe Core Group. All rights reserved.
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

#import "DSDAPIGRPCResponseHandler.h"
#import <DAPI-GRPC/Platform.pbrpc.h>
#import <DAPI-GRPC/Platform.pbobjc.h>
#import "NSData+DSCborDecoding.h"
#import "DPContract.h"

@interface DSDAPIGRPCResponseHandler()

@property(nonatomic,strong) id responseObject;
@property(nonatomic,strong) NSError * decodingError;

@end

@implementation DSDAPIGRPCResponseHandler

- (void)didReceiveInitialMetadata:(nullable NSDictionary *)initialMetadata {
    DSDLog(@"didReceiveInitialMetadata");
}

- (void)didReceiveProtoMessage:(nullable GPBMessage *)message {
    if ([message isMemberOfClass:[GetIdentityResponse class]]) {
        GetIdentityResponse * identityResponse = (GetIdentityResponse*)message;
        NSError * error = nil;
        self.responseObject = [[identityResponse identity] ds_decodeCborError:&error];
        if (error) {
            self.decodingError = error;
        }
    } else if ([message isMemberOfClass:[GetDocumentsResponse class]]) {
        GetDocumentsResponse * documentsResponse = (GetDocumentsResponse*)message;
        NSError * error = nil;
        NSMutableArray * mArray = [NSMutableArray array];
        for (NSData * cborData in [documentsResponse documentsArray]) {
            [mArray addObject:[cborData ds_decodeCborError:&error]];
            if (error) break;
        }
        self.responseObject = [mArray copy];
        if (error) {
            self.decodingError = error;
        }
    } else if ([message isMemberOfClass:[GetDataContractResponse class]]) {
        GetDataContractResponse * contractResponse = (GetDataContractResponse*)message;
        NSError * error = nil;
        self.responseObject = [[contractResponse dataContract] ds_decodeCborError:&error];
        if (error) {
            self.decodingError = error;
        }
    }
    DSDLog(@"didReceiveProtoMessage");
}

- (void)didCloseWithTrailingMetadata:(nullable NSDictionary *)trailingMetadata
                               error:(nullable NSError *)error {
    if (!error && self.decodingError) {
        error = self.decodingError;
    }
    if (error) {
        if (self.errorHandler) {
            self.errorHandler(error);
        }
        DSDLog(@"error in didCloseWithTrailingMetadata %@",error);
        if (self.request) {
            DSDLog(@"request contract ID was %@",self.request.contract.base58ContractId);
        }
        
    } else {
        self.successHandler(self.responseObject);
    }
    DSDLog(@"didCloseWithTrailingMetadata");
}

-(void)didWriteMessage {
    DSDLog(@"didWriteMessage");
}


@end
