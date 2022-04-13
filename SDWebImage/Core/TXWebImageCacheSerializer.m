/*
 * This file is part of the SDWebImage package.
 * (c) Olivier Poitrey <rs@dailymotion.com>
 *
 * For the full copyright and license information, please view the LICENSE
 * file that was distributed with this source code.
 */

#import "TXWebImageCacheSerializer.h"

@interface TXWebImageCacheSerializer ()

@property (nonatomic, copy, nonnull) TXWebImageCacheSerializerBlock block;

@end

@implementation TXWebImageCacheSerializer

- (instancetype)initWithBlock:(TXWebImageCacheSerializerBlock)block {
    self = [super init];
    if (self) {
        self.block = block;
    }
    return self;
}

+ (instancetype)cacheSerializerWithBlock:(TXWebImageCacheSerializerBlock)block {
    TXWebImageCacheSerializer *cacheSerializer = [[TXWebImageCacheSerializer alloc] initWithBlock:block];
    return cacheSerializer;
}

- (NSData *)cacheDataWithImage:(UIImage *)image originalData:(NSData *)data imageURL:(nullable NSURL *)imageURL {
    if (!self.block) {
        return nil;
    }
    return self.block(image, data, imageURL);
}

@end
