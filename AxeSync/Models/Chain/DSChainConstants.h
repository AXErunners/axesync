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

#define MAINNET_STANDARD_PORT 9937
#define TESTNET_STANDARD_PORT 19937
#define DEVNET_STANDARD_PORT 20001

#define MAINNET_DEFAULT_HEADERS_MAX_AMOUNT 2000
#define TESTNET_DEFAULT_HEADERS_MAX_AMOUNT 2000
#define DEVNET_DEFAULT_HEADERS_MAX_AMOUNT 2000

#define MAINNET_DAPI_JRPC_STANDARD_PORT 3000
#define TESTNET_DAPI_JRPC_STANDARD_PORT 3000
#define DEVNET_DAPI_JRPC_STANDARD_PORT 3000

#define MAINNET_DAPI_GRPC_STANDARD_PORT 3010
#define TESTNET_DAPI_GRPC_STANDARD_PORT 3010
#define DEVNET_DAPI_GRPC_STANDARD_PORT 3010

#define PROTOCOL_VERSION_MAINNET   70218
#define DEFAULT_MIN_PROTOCOL_VERSION_MAINNET  70216

#define PROTOCOL_VERSION_TESTNET   70218
#define DEFAULT_MIN_PROTOCOL_VERSION_TESTNET  70218

#define PROTOCOL_VERSION_DEVNET   70216
#define DEFAULT_MIN_PROTOCOL_VERSION_DEVNET  70215

#define MAX_VALID_MIN_PROTOCOL_VERSION 70218
#define MIN_VALID_MIN_PROTOCOL_VERSION 70215

#define AXE_MAGIC_NUMBER_TESTNET 0xf1cae2ce
#define AXE_MAGIC_NUMBER_MAINNET 0x046bceb5
#define AXE_MAGIC_NUMBER_DEVNET 0xceffcae2

#define MAX_TARGET_PROOF_OF_WORK_MAINNET 0x1e0fffffu   // highest value for difficulty target (higher values are less difficult)
#define MAX_TARGET_PROOF_OF_WORK_TESTNET 0x1e0fffffu
#define MAX_TARGET_PROOF_OF_WORK_DEVNET 0x207fffffu

#define MAX_PROOF_OF_WORK_MAINNET @"00000fffffffffffffffffffffffffffffffffffffffffffffffffffffffffff".hexToData.reverse.UInt256  // highest value for difficulty target (higher values are less difficult)
#define MAX_PROOF_OF_WORK_TESTNET @"00000fffffffffffffffffffffffffffffffffffffffffffffffffffffffffff".hexToData.reverse.UInt256
#define MAX_PROOF_OF_WORK_DEVNET @"7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff".hexToData.reverse.UInt256

#define SPORK_PUBLIC_KEY_MAINNET @"0"

#define SPORK_PUBLIC_KEY_TESTNET @"0"


#define SPORK_ADDRESS_MAINNET @"PR8VqUyRm1Dm9tii6uv9D7gidWyA56SvqZ"
#define SPORK_ADDRESS_TESTNET @"yc6v3PwpAQmKq4jw5JV35XpifUhxNe2JDp"

#define MAINNET_AXEPAY_CONTRACT_ID @""
#define MAINNET_DPNS_CONTRACT_ID @""

#define TESTNET_AXEPAY_CONTRACT_ID @""
#define TESTNET_DPNS_CONTRACT_ID @""


#define DEFAULT_FEE_PER_B TX_FEE_PER_B
#define MIN_FEE_PER_B     TX_FEE_PER_B // minimum relay fee on a 191byte tx
#define MAX_FEE_PER_B     1000 // slightly higher than a 1000bit fee on a 191byte tx

#define HEADER_WINDOW_BUFFER_TIME (WEEK_TIME_INTERVAL/2) //This is about the time if we consider a block every 10 mins (for 500 blocks)
