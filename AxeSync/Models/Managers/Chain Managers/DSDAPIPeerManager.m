//
//  DSDAPIPeerManager.m
//  AxeSync
//
//  Created by Sam Westrich on 9/12/18.
//  Copyright (c) 2018 Axe Core Group <contact@axe.org>
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

#import "DSDAPIPeerManager.h"
#import "AFJSONRPCClient.h"
#import "DSChain.h"
#import "DSDAPIProtocol.h"
#import "NSData+Bitcoin.h"
#import "NSString+Bitcoin.h"
#import "NSString+Axe.h"
#import "DSTransaction.h"
#import "DSMerkleBlock.h"
#import "DSPeerManager.h"

@interface DSDAPIPeerManager()
@property (nonatomic,readonly) AFJSONRPCClient * client;
@end

@implementation DSDAPIPeerManager

-(instancetype)initWithChainManager:(DSChainManager*)chainManager
{
    if (! (self = [super init])) return nil;
    _chainManager = chainManager;
    return self;
}

-(NSURL*)mainDAPINodeURL {
    NSString * hostString = @"http://54.169.131.115:3000";//[NSString stringWithFormat:@"http://%@:3000",self.chainPeerManager.downloadPeer.host];
    return [NSURL URLWithString:hostString];
}

-(AFJSONRPCClient*)client {
    return [AFJSONRPCClient clientWithEndpointURL:[self mainDAPINodeURL]];
}

// MARK:- Layer 1 General Calls

-(void)getBestBlockHeightWithSuccess:(void (^)(NSNumber *))success failure:(void (^)(NSError *))failure {
    [self.client invokeMethod:@"getBestBlockHeight" success:^(NSURLSessionDataTask *task, id responseObject) {
        success(responseObject);
    } failure:^(NSURLSessionDataTask *task, NSError *error) {
        failure(error);
    }];
}

-(void)getPeerDataSyncStatus:(void (^)(NSNumber *))success failure:(void (^)(NSError *))failure {
    [self.client invokeMethod:@"getPeerDataSyncStatus" success:^(NSURLSessionDataTask *task, id responseObject) {
        success(responseObject);
    } failure:^(NSURLSessionDataTask *task, NSError *error) {
        failure(error);
    }];
}

// MARK:- Layer 1 Bloom Filter Calls

-(void)loadBloomFilter:(NSString*)filter withSuccess:(void (^)(BOOL success))success failure:(void (^)(NSError *error))failure {
    [self.client invokeMethod:@"loadBloomFilter" withParameters:@{@"filter":filter} success:^(NSURLSessionDataTask *task, id responseObject) {
        success([responseObject boolValue]);
    } failure:^(NSURLSessionDataTask *task, NSError *error) {
        failure(error);
    }];
}

-(void)clearBloomFilter:(NSString*)filter withSuccess:(void (^)(BOOL success))success failure:(void (^)(NSError *error))failure {
    [self.client invokeMethod:@"clearBloomFilter" withParameters:@{@"filter":filter} success:^(NSURLSessionDataTask *task, id responseObject) {
        success([responseObject boolValue]);
    } failure:^(NSURLSessionDataTask *task, NSError *error) {
        failure(error);
    }];
}

// MARK:- Layer 1 Block Calls

-(void)getRawBlock:(UInt256)blockHash withSuccess:(void (^)(BOOL success))success failure:(void (^)(NSError *error))failure {
    [self.client invokeMethod:@"getRawBlock" withParameters:@{@"blockHash":[NSData dataWithUInt256:blockHash].hexString} success:^(NSURLSessionDataTask *task, id responseObject) {
        success([responseObject boolValue]);
    } failure:^(NSURLSessionDataTask *task, NSError *error) {
        failure(error);
    }];
}

-(void)getBlocksFromDate:(NSDate*)date limit:(NSUInteger)limit withSuccess:(void (^)(NSArray * blocks))success failure:(void (^)(NSError *error))failure {
    NSISO8601DateFormatter * formatter = [[NSISO8601DateFormatter alloc] init];
    [self.client invokeMethod:@"getBlocks" withParameters:@{@"limit":@(limit),@"blockDate":[formatter stringFromDate:date]} success:^(NSURLSessionDataTask *task, id responseObject) {
        success(responseObject);
    } failure:^(NSURLSessionDataTask *task, NSError *error) {
        failure(error);
    }];
}

// MARK:- Layer 1 Transaction Calls

-(void)sendRawTransaction:(NSString*)address withSuccess:(void (^)(UInt256 transactionHashId))success failure:(void (^)(NSError *error))failure {
    [self.client invokeMethod:@"sendRawTransaction" withParameters:@{@"address":address} success:^(NSURLSessionDataTask *task, id responseObject) {
        NSString * responseString = responseObject;
        success([responseString.hexToData UInt256]);
    } failure:^(NSURLSessionDataTask *task, NSError *error) {
        failure(error);
    }];
}

-(void)sendRawInstantSendTransaction:(NSString*)address withSuccess:(void (^)(UInt256 transactionHashId))success failure:(void (^)(NSError *error))failure {
    [self.client invokeMethod:@"sendRawIxTransaction" withParameters:@{@"address":address} success:^(NSURLSessionDataTask *task, id responseObject) {
        NSString * responseString = responseObject;
        success([responseString.hexToData UInt256]);
    } failure:^(NSURLSessionDataTask *task, NSError *error) {
        failure(error);
    }];
}

-(void)sendRawTransition:(NSData*)stateTransitionData transitionData:(NSData*)data withSuccess:(void (^)(UInt256 transitionHashId))success failure:(void (^)(NSError *error))failure {
    [self.client invokeMethod:@"sendRawTransition" withParameters:@{@"rawTransitionHeader":stateTransitionData.hexString,@"rawTransitionPacket":data.hexString} success:^(NSURLSessionDataTask *task, id responseObject) {
        NSString * responseString = responseObject;
        success([responseString.hexToData UInt256]);
    } failure:^(NSURLSessionDataTask *task, NSError *error) {
        failure(error);
    }];
}

-(void)getTransactionsByAddress:(NSString*)address withSuccess:(void (^)(NSArray * transactions))success failure:(void (^)(NSError *error))failure {
    [self.client invokeMethod:@"getTransactionsByAddress" withParameters:@{@"address":address} success:^(NSURLSessionDataTask *task, id responseObject) {
        success(responseObject);
    } failure:^(NSURLSessionDataTask *task, NSError *error) {
        failure(error);
    }];
}

-(void)getTransactionById:(UInt256)transactionId withSuccess:(void (^)(DSTransaction * transaction))success failure:(void (^)(NSError *error))failure {
    [self.client invokeMethod:@"getTransactionById" withParameters:@{@"txid":[NSData dataWithUInt256:transactionId].hexString} success:^(NSURLSessionDataTask *task, id responseObject) {
        success(responseObject);
    } failure:^(NSURLSessionDataTask *task, NSError *error) {
        failure(error);
    }];
}

-(void)getSpvData:(NSString*)filter withSuccess:(void (^)(BOOL success))success failure:(void (^)(NSError *error))failure {
    [self.client invokeMethod:@"getSpvData" withParameters:@{@"filter":filter} success:^(NSURLSessionDataTask *task, id responseObject) {
        success([responseObject boolValue]);
    } failure:^(NSURLSessionDataTask *task, NSError *error) {
        failure(error);
    }];
}

// MARK:- Layer 1 Address Calls

-(void)getAddressSummary:(NSString*)address withSuccess:(void (^)(NSDictionary *addressInfo))success failure:(void (^)(NSError *error))failure {
    [self.client invokeMethod:@"getAddressSummary" withParameters:@{@"address":address} success:^(NSURLSessionDataTask *task, id responseObject) {
        success(responseObject);
    } failure:^(NSURLSessionDataTask *task, NSError *error) {
        failure(error);
    }];
}

-(void)getAddressTotalReceived:(NSString*)address withSuccess:(void (^)(NSNumber *haks))success failure:(void (^)(NSError *error))failure {
    [self.client invokeMethod:@"getAddressTotalReceived" withParameters:@{@"address":address} success:^(NSURLSessionDataTask *task, id responseObject) {
        success(responseObject);
    } failure:^(NSURLSessionDataTask *task, NSError *error) {
        failure(error);
    }];
}

-(void)getAddressTotalSent:(NSString*)address withSuccess:(void (^)(NSNumber *haks))success failure:(void (^)(NSError *error))failure {
    [self.client invokeMethod:@"getAddressTotalSent" withParameters:@{@"address":address} success:^(NSURLSessionDataTask *task, id responseObject) {
        success(responseObject);
    } failure:^(NSURLSessionDataTask *task, NSError *error) {
        failure(error);
    }];
}

-(void)getAddressUnconfirmedBalance:(NSString*)address withSuccess:(void (^)(NSNumber *haks))success failure:(void (^)(NSError *error))failure {
    [self.client invokeMethod:@"getAddressUnconfirmedBalance" withParameters:@{@"address":address} success:^(NSURLSessionDataTask *task, id responseObject) {
        success(responseObject);
    } failure:^(NSURLSessionDataTask *task, NSError *error) {
        failure(error);
    }];
}

-(void)getAddressBalance:(NSString*)address withSuccess:(void (^)(NSNumber *haks))success failure:(void (^)(NSError *error))failure {
    [self.client invokeMethod:@"getBalance" withParameters:@{@"address":address} success:^(NSURLSessionDataTask *task, id responseObject) {
        success(responseObject);
    } failure:^(NSURLSessionDataTask *task, NSError *error) {
        failure(error);
    }];
}

-(void)getAddressUTXOs:(NSString*)address withSuccess:(void (^)(NSArray *addressUTXOs))success failure:(void (^)(NSError *error))failure {
    [self.client invokeMethod:@"getUTXO" withParameters:@{@"address":address} success:^(NSURLSessionDataTask *task, id responseObject) {
        success(responseObject);
    } failure:^(NSURLSessionDataTask *task, NSError *error) {
        failure(error);
    }];
}

// MARK:- Layer 2 Calls

-(void)searchUsers:(NSString*)pattern limit:(NSUInteger)limit offset:(NSUInteger)offset withSuccess:(void (^)(NSArray *users))success failure:(void (^)(NSError *error))failure {
    [self.client invokeMethod:@"searchUsers" withParameters:@{@"pattern":pattern,@"limit":@(limit),@"offset":@(offset)} success:^(NSURLSessionDataTask *task, id responseObject) {
        success(responseObject);
    } failure:^(NSURLSessionDataTask *task, NSError *error) {
        failure(error);
    }];
}

-(void)getUserByUsername:(NSString*)username withSuccess:(void (^)(NSDictionary *userInfo))success failure:(void (^)(NSError *error))failure {
    [self.client invokeMethod:@"getUser" withParameters:@{@"username":username} success:^(NSURLSessionDataTask *task, id responseObject) {
        success(responseObject);
    } failure:^(NSURLSessionDataTask *task, NSError *error) {
        failure(error);
    }];
}

-(void)getUserByRegistrationTransactionId:(UInt256)registrationTransactionId withSuccess:(void (^)(NSDictionary *userInfo))success failure:(void (^)(NSError *error))failure {
    [self.client invokeMethod:@"getUser" withParameters:@{@"regTxId":[NSData dataWithUInt256:registrationTransactionId].hexString} success:^(NSURLSessionDataTask *task, id responseObject) {
        success(responseObject);
    } failure:^(NSURLSessionDataTask *task, NSError *error) {
        failure(error);
    }];
}

-(void)getDAPsMatching:(NSString*)matching withSuccess:(void (^)(NSDictionary *userInfo))success failure:(void (^)(NSError *error))failure {
    [self.client invokeMethod:@"searchDapContracts" withParameters:@{@"pattern":matching} success:^(NSURLSessionDataTask *task, id responseObject) {
        success(responseObject);
    } failure:^(NSURLSessionDataTask *task, NSError *error) {
        failure(error);
    }];
}

-(void)getDAPsWithSuccess:(void (^)(NSDictionary *userInfo))success failure:(void (^)(NSError *error))failure {
    [self.client invokeMethod:@"searchDapContracts" withParameters:@{@"pattern":@"*"} success:^(NSURLSessionDataTask *task, id responseObject) {
        success(responseObject);
    } failure:^(NSURLSessionDataTask *task, NSError *error) {
        failure(error);
    }];
}

- (void)fetchDapContract:(void (^)(NSDictionary *))success failure:(void (^)(NSError *))failure {
    // TODO: implement
    NSAssert(NO, @"Not implemented");
}

-(void)getUserDapSpaceForUser:(NSString*)userId forDap:(NSString*)dapId withSuccess:(void (^)(NSDictionary *userInfo))success failure:(void (^)(NSError *error))failure {
    [self.client invokeMethod:@"getUserDapSpace" withParameters:@{@"userId":userId,@"dapId":dapId} success:^(NSURLSessionDataTask *task, id responseObject) {
        success(responseObject);
    } failure:^(NSURLSessionDataTask *task, NSError *error) {
        failure(error);
    }];
}

-(void)getUserDapContextForUser:(NSString*)userId forDap:(NSString*)dapId withSuccess:(void (^)(NSDictionary *userInfo))success failure:(void (^)(NSError *error))failure {
    [self.client invokeMethod:@"getUserDapContext" withParameters:@{@"userId":userId,@"dapId":dapId} success:^(NSURLSessionDataTask *task, id responseObject) {
        success(responseObject);
    } failure:^(NSURLSessionDataTask *task, NSError *error) {
        failure(error);
    }];
}


-(void)getDapContractsWithSuccess:(void (^)(NSDictionary *userInfo))success failure:(void (^)(NSError *error))failure {
    [self.client invokeMethod:@"searchDapContracts" withParameters:@{@"pattern":@"*"} success:^(NSURLSessionDataTask *task, id responseObject) {
        success(responseObject);
    } failure:^(NSURLSessionDataTask *task, NSError *error) {
        failure(error);
    }];
}

-(void)fetchDapContractForDap:(NSString*)dapId withSuccess:(void (^)(NSDictionary *dapInfo))success failure:(void (^)(NSError *error))failure {
    [self.client invokeMethod:@"fetchDapContract" withParameters:@{@"dapId":dapId} success:^(NSURLSessionDataTask *task, id responseObject) {
        success(responseObject);
    } failure:^(NSURLSessionDataTask *task, NSError *error) {
        failure(error);
    }];
}


-(void)registerDapContract:(NSData*)dapContractData withStateTransitionData:(NSData*)stateTransitionData withSuccess:(void (^)(NSDictionary *userInfo))success failure:(void (^)(NSError *error))failure {
    [self sendRawTransition:stateTransitionData transitionData:dapContractData withSuccess:^(UInt256 transitionHashId) {
        success(@{});
    } failure:failure];
}

// MARK:- MetaData Calls

@end
