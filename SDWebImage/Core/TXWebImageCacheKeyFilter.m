/*
 * This file is part of the SDWebImage package.
 * (c) Olivier Poitrey <rs@dailymotion.com>
 *
 * For the full copyright and license information, please view the LICENSE
 * file that was distributed with this source code.
 */

#import "TXWebImageCacheKeyFilter.h"

@interface TXWebImageCacheKeyFilter ()

@property (nonatomic, copy, nonnull) TXWebImageCacheKeyFilterBlock block;

@end

@implementation TXWebImageCacheKeyFilter

- (instancetype)initWithBlock:(TXWebImageCacheKeyFilterBlock)block {
    self = [super init];
    if (self) {
        self.block = block;
    }
    return self;
}

+ (instancetype)cacheKeyFilterWithBlock:(TXWebImageCacheKeyFilterBlock)block {
    TXWebImageCacheKeyFilter *cacheKeyFilter = [[TXWebImageCacheKeyFilter alloc] initWithBlock:block];
    return cacheKeyFilter;
}

- (NSString *)cacheKeyForURL:(NSURL *)url {
    if (!self.block) {
        return nil;
    }
    return self.block(url);
}

@end
