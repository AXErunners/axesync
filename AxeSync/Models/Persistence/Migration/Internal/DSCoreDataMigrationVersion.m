//  
//  Created by Andrew Podkovyrin
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

#import "DSCoreDataMigrationVersion.h"

@implementation DSCoreDataMigrationVersion

+ (DSCoreDataMigrationVersionValue)current {
    return DSCoreDataMigrationVersionValue_8;
}

+ (NSString *)modelResourceForVersion:(DSCoreDataMigrationVersionValue)version {
    switch (version) {
        case DSCoreDataMigrationVersionValue_1: return @"AxeSync 1";
        case DSCoreDataMigrationVersionValue_2: return @"AxeSync 2";
        case DSCoreDataMigrationVersionValue_3: return @"AxeSync 3";
        case DSCoreDataMigrationVersionValue_4: return @"AxeSync 4";
        case DSCoreDataMigrationVersionValue_5: return @"AxeSync 5";
        case DSCoreDataMigrationVersionValue_6: return @"AxeSync 6";
        case DSCoreDataMigrationVersionValue_7: return @"AxeSync 7";
        case DSCoreDataMigrationVersionValue_8: return @"AxeSync 8";
        default:
            return [NSString stringWithFormat:@"AxeSync %ld",(long)version];
    }
}

+ (DSCoreDataMigrationVersionValue)nextVersionAfter:(DSCoreDataMigrationVersionValue)version {
    NSUInteger next = version + 1;
    if (next <= self.current) {
        return next;
    }
    return NSNotFound;
}

@end
