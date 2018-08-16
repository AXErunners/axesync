//
//  DSBloomFilterTests.m
//  AxeSync_Tests
//
//  Created by Andrew Podkovyrin on 20/06/2018.
//  Copyright © 2018 Axe Core Group. All rights reserved.
//

#import <XCTest/XCTest.h>

#import "DSBloomFilter.h"
#import "NSString+Bitcoin.h"
#import "DSMerkleBlock.h"
#import "DSChain.h"
#import "NSData+Bitcoin.h"

@interface DSBloomFilterTests : XCTestCase

@property (strong, nonatomic) DSChain *chain;

@end

@implementation DSBloomFilterTests

- (void)setUp
{
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
    
    // the chain to test on
    self.chain = [DSChain mainnet];
}

// MARK: - testBloomFilter

- (void)testBloomFilter
{
    DSBloomFilter *f = [[DSBloomFilter alloc] initWithFalsePositiveRate:.01 forElementCount:3 tweak:0
                                                                  flags:BLOOM_UPDATE_ALL];
    
    [f insertData:@"99108ad8ed9bb6274d3980bab5a85c048f0950c8".hexToData];
    NSLog(@"fpRate = %.5f",f.falsePositiveRate);
    XCTAssertTrue([f containsData:@"99108ad8ed9bb6274d3980bab5a85c048f0950c8".hexToData],
                  @"[DSBloomFilter containsData:]");
    
    // one bit difference
    XCTAssertFalse([f containsData:@"19108ad8ed9bb6274d3980bab5a85c048f0950c8".hexToData],
                   @"[DSBloomFilter containsData:]");
    
    [f insertData:@"b5a2c786d9ef4658287ced5914b37a1b4aa32eee".hexToData];
    NSLog(@"fpRate = %.5f",f.falsePositiveRate);
    XCTAssertTrue([f containsData:@"b5a2c786d9ef4658287ced5914b37a1b4aa32eee".hexToData],
                  @"[DSBloomFilter containsData:]");
    
    [f insertData:@"b9300670b4c5366e95b2699e8b18bc75e5f729c5".hexToData];
    NSLog(@"fpRate = %.5f",f.falsePositiveRate);
    XCTAssertTrue([f containsData:@"b9300670b4c5366e95b2699e8b18bc75e5f729c5".hexToData],
                  @"[DSBloomFilter containsData:]");
    
    // check against satoshi client output
    XCTAssertEqualObjects(@"03614e9b050000000000000001".hexToData, f.data, @"[DSBloomFilter data:]");
}

- (void)testBloomFilterWithTweak
{
    DSBloomFilter *f = [[DSBloomFilter alloc] initWithFalsePositiveRate:.01 forElementCount:3 tweak:2147483649
                                                                  flags:BLOOM_UPDATE_P2PUBKEY_ONLY];
    
    [f insertData:@"99108ad8ed9bb6274d3980bab5a85c048f0950c8".hexToData];
    
    XCTAssertTrue([f containsData:@"99108ad8ed9bb6274d3980bab5a85c048f0950c8".hexToData],
                  @"[DSBloomFilter containsData:]");
    
    // one bit difference
    XCTAssertFalse([f containsData:@"19108ad8ed9bb6274d3980bab5a85c048f0950c8".hexToData],
                   @"[DSBloomFilter containsData:]");
    
    [f insertData:@"b5a2c786d9ef4658287ced5914b37a1b4aa32eee".hexToData];
    
    XCTAssertTrue([f containsData:@"b5a2c786d9ef4658287ced5914b37a1b4aa32eee".hexToData],
                  @"[DSBloomFilter containsData:]");
    
    [f insertData:@"b9300670b4c5366e95b2699e8b18bc75e5f729c5".hexToData];
    
    XCTAssertTrue([f containsData:@"b9300670b4c5366e95b2699e8b18bc75e5f729c5".hexToData],
                  @"[DSBloomFilter containsData:]");
    
    // check against satoshi client output
    XCTAssertEqualObjects(@"03ce4299050000000100008002".hexToData, f.data, @"[DSBloomFilter data:]");
}

- (void)testMerkleBlock
{
    /*
     
     // -> block 745465 in all it's glory <-
     
     {
     "hash": "0000000000000197df9123a822ae2ff2b1108b37d641b2a8c976ba949a78ca51",
     "confirmations": 4383,
     "size": 953,
     "height": 745465,
     "version": 536870912,
     "merkleroot": "d5d706130205b588d88977de7438399d8106a7446c4b300c7f902a0f3c16ad2a",
     "tx": [
     "e975d526d29ef6967249539493a34aa63d14f701dfbab83ba7188e93599f9e27",
     "f68abb43a46d00b993f6c0f2df2a9dc377bb0ffbe0583f65d5186b92be403255",
     "2f5709c4d50c2574e8717d1efd9bc9a0a90da3f04dff46660cb54dba2ecb2555",
     "c24891989f089f671967d363df3c184520f4961f16037600478b18503d2c319b"
     ],
     "time": 1506710174,
     "mediantime": 1506709673,
     "nonce": 125766022,
     "bits": "1a023d68",
     "difficulty": 7490155.121260014,
     "chainwork": "000000000000000000000000000000000000000000000010796b646d372a9997",
     "previousblockhash": "00000000000000a4570dff221ace766642e7f7cd59bbedf12dd2c3ff884e5d1d",
     "nextblockhash": "0000000000000021850b1e5d87bd92aa0e52a6f0de2e9363cd7336f22a479b02"
     }
     */
    //this block is bloom filtered to only have the first transaction
    NSData *block = @"000000201d5d4e88ffc3d22df1edbb59cdf7e7426676ce1a22ff0d57a4000000000000002aad163c0f2a907f0c304b6c44a706819d393874de7789d888b505021306d7d59e92ce59683d021a86097f070400000003279e9f59938e18a73bb8badf01f7143da64aa3939453497296f69ed226d575e9553240be926b18d5653f58e0fb0fbb77c39d2adff2c0f693b9006da443bb8af609491f56436c3e6a6ca83cb5a21782059559f6ee91abde67f9d4c6f0caa67e3e0107".hexToData;
    DSMerkleBlock *b = [DSMerkleBlock blockWithMessage:block onChain:self.chain];
    UInt256 hash;
    
    hash = *(UInt256 *)@"0000000000000197df9123a822ae2ff2b1108b37d641b2a8c976ba949a78ca51".hexToData.reverse.bytes;
    XCTAssertTrue(uint256_eq(b.blockHash, hash), @"[DSMerkleBlock blockHash]");
    
    XCTAssertEqualObjects(block, b.data, @"[DSMerkleBlock toData]");
    
    XCTAssertTrue(b.valid, @"[DSMerkleBlock isValid]");
    
    hash = *(UInt256 *)@"e975d526d29ef6967249539493a34aa63d14f701dfbab83ba7188e93599f9e27".hexToData.reverse.bytes;
    XCTAssertTrue([b containsTxHash:hash], @"[DSMerkleBlock containsTxHash:]");
    
    XCTAssertEqual(b.totalTransactions,4, @"[DSMerkleBlock txHashes]");
    
    hash = *(UInt256 *)@"e975d526d29ef6967249539493a34aa63d14f701dfbab83ba7188e93599f9e27".hexToData.reverse.bytes;
    XCTAssertEqualObjects(b.txHashes[0], uint256_obj(hash), @"[DSMerkleBlock txHashes]");
    
    //TODO: test a block with an odd number of tree rows both at the tx level and merkle node level
    
    //TODO:XXXX test verifyDifficultyFromPreviousBlock
}

@end
