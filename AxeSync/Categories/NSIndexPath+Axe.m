//
//  NSIndexPath+Axe.m
//  AFNetworking
//
//  Created by Sam Westrich on 11/3/18.
//

#import "NSIndexPath+Axe.h"

@implementation NSIndexPath (Axe)

-(NSIndexPath*)indexPathByRemovingFirstIndex {
    if (self.length == 1) return [[NSIndexPath alloc] init];
    NSUInteger indexes[[self length]];
    [self getIndexes:indexes range:NSMakeRange(1, [self length] - 1)];
    return [NSIndexPath indexPathWithIndexes:indexes length:self.length - 1];
}

@end
