/*
 * This file is part of the SDWebImage package.
 * (c) Olivier Poitrey <rs@dailymotion.com>
 *
 * For the full copyright and license information, please view the LICENSE
 * file that was distributed with this source code.
 */

#import "TXImageCachesManager.h"
#import "TXImageCachesManagerOperation.h"
#import "TXImageCache.h"
#import "TXInternalMacros.h"

@interface TXImageCachesManager ()

@property (nonatomic, strong, nonnull) NSMutableArray<id<TXImageCache>> *imageCaches;

@end

@implementation TXImageCachesManager {
    SD_LOCK_DECLARE(_cachesLock);
}

+ (TXImageCachesManager *)sharedManager {
    static dispatch_once_t onceToken;
    static TXImageCachesManager *manager;
    dispatch_once(&onceToken, ^{
        manager = [[TXImageCachesManager alloc] init];
    });
    return manager;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        self.queryOperationPolicy = TXImageCachesManagerOperationPolicySerial;
        self.storeOperationPolicy = TXImageCachesManagerOperationPolicyHighestOnly;
        self.removeOperationPolicy = TXImageCachesManagerOperationPolicyConcurrent;
        self.containsOperationPolicy = TXImageCachesManagerOperationPolicySerial;
        self.clearOperationPolicy = TXImageCachesManagerOperationPolicyConcurrent;
        // initialize with default image caches
        _imageCaches = [NSMutableArray arrayWithObject:[TXImageCache sharedImageCache]];
        SD_LOCK_INIT(_cachesLock);
    }
    return self;
}

- (NSArray<id<TXImageCache>> *)caches {
    SD_LOCK(_cachesLock);
    NSArray<id<TXImageCache>> *caches = [_imageCaches copy];
    SD_UNLOCK(_cachesLock);
    return caches;
}

- (void)setCaches:(NSArray<id<TXImageCache>> *)caches {
    SD_LOCK(_cachesLock);
    [_imageCaches removeAllObjects];
    if (caches.count) {
        [_imageCaches addObjectsFromArray:caches];
    }
    SD_UNLOCK(_cachesLock);
}

#pragma mark - Cache IO operations

- (void)addCache:(id<TXImageCache>)cache {
    if (![cache conformsToProtocol:@protocol(TXImageCache)]) {
        return;
    }
    SD_LOCK(_cachesLock);
    [_imageCaches addObject:cache];
    SD_UNLOCK(_cachesLock);
}

- (void)removeCache:(id<TXImageCache>)cache {
    if (![cache conformsToProtocol:@protocol(TXImageCache)]) {
        return;
    }
    SD_LOCK(_cachesLock);
    [_imageCaches removeObject:cache];
    SD_UNLOCK(_cachesLock);
}

#pragma mark - TXImageCache

- (id<TXWebImageOperation>)queryImageForKey:(NSString *)key options:(SDWebImageOptions)options context:(SDWebImageContext *)context completion:(TXImageCacheQueryCompletionBlock)completionBlock {
    return [self queryImageForKey:key options:options context:context cacheType:TXImageCacheTypeAll completion:completionBlock];
}

- (id<TXWebImageOperation>)queryImageForKey:(NSString *)key options:(SDWebImageOptions)options context:(SDWebImageContext *)context cacheType:(TXImageCacheType)cacheType completion:(TXImageCacheQueryCompletionBlock)completionBlock {
    if (!key) {
        return nil;
    }
    NSArray<id<TXImageCache>> *caches = self.caches;
    NSUInteger count = caches.count;
    if (count == 0) {
        return nil;
    } else if (count == 1) {
        return [caches.firstObject queryImageForKey:key options:options context:context cacheType:cacheType completion:completionBlock];
    }
    switch (self.queryOperationPolicy) {
        case TXImageCachesManagerOperationPolicyHighestOnly: {
            id<TXImageCache> cache = caches.lastObject;
            return [cache queryImageForKey:key options:options context:context cacheType:cacheType completion:completionBlock];
        }
            break;
        case TXImageCachesManagerOperationPolicyLowestOnly: {
            id<TXImageCache> cache = caches.firstObject;
            return [cache queryImageForKey:key options:options context:context cacheType:cacheType completion:completionBlock];
        }
            break;
        case TXImageCachesManagerOperationPolicyConcurrent: {
            TXImageCachesManagerOperation *operation = [TXImageCachesManagerOperation new];
            [operation beginWithTotalCount:caches.count];
            [self concurrentQueryImageForKey:key options:options context:context cacheType:cacheType completion:completionBlock enumerator:caches.reverseObjectEnumerator operation:operation];
            return operation;
        }
            break;
        case TXImageCachesManagerOperationPolicySerial: {
            TXImageCachesManagerOperation *operation = [TXImageCachesManagerOperation new];
            [operation beginWithTotalCount:caches.count];
            [self serialQueryImageForKey:key options:options context:context cacheType:cacheType completion:completionBlock enumerator:caches.reverseObjectEnumerator operation:operation];
            return operation;
        }
            break;
        default:
            return nil;
            break;
    }
}

- (void)storeImage:(UIImage *)image imageData:(NSData *)imageData forKey:(NSString *)key cacheType:(TXImageCacheType)cacheType completion:(SDWebImageNoParamsBlock)completionBlock {
    if (!key) {
        return;
    }
    NSArray<id<TXImageCache>> *caches = self.caches;
    NSUInteger count = caches.count;
    if (count == 0) {
        return;
    } else if (count == 1) {
        [caches.firstObject storeImage:image imageData:imageData forKey:key cacheType:cacheType completion:completionBlock];
        return;
    }
    switch (self.storeOperationPolicy) {
        case TXImageCachesManagerOperationPolicyHighestOnly: {
            id<TXImageCache> cache = caches.lastObject;
            [cache storeImage:image imageData:imageData forKey:key cacheType:cacheType completion:completionBlock];
        }
            break;
        case TXImageCachesManagerOperationPolicyLowestOnly: {
            id<TXImageCache> cache = caches.firstObject;
            [cache storeImage:image imageData:imageData forKey:key cacheType:cacheType completion:completionBlock];
        }
            break;
        case TXImageCachesManagerOperationPolicyConcurrent: {
            TXImageCachesManagerOperation *operation = [TXImageCachesManagerOperation new];
            [operation beginWithTotalCount:caches.count];
            [self concurrentStoreImage:image imageData:imageData forKey:key cacheType:cacheType completion:completionBlock enumerator:caches.reverseObjectEnumerator operation:operation];
        }
            break;
        case TXImageCachesManagerOperationPolicySerial: {
            [self serialStoreImage:image imageData:imageData forKey:key cacheType:cacheType completion:completionBlock enumerator:caches.reverseObjectEnumerator];
        }
            break;
        default:
            break;
    }
}

- (void)removeImageForKey:(NSString *)key cacheType:(TXImageCacheType)cacheType completion:(SDWebImageNoParamsBlock)completionBlock {
    if (!key) {
        return;
    }
    NSArray<id<TXImageCache>> *caches = self.caches;
    NSUInteger count = caches.count;
    if (count == 0) {
        return;
    } else if (count == 1) {
        [caches.firstObject removeImageForKey:key cacheType:cacheType completion:completionBlock];
        return;
    }
    switch (self.removeOperationPolicy) {
        case TXImageCachesManagerOperationPolicyHighestOnly: {
            id<TXImageCache> cache = caches.lastObject;
            [cache removeImageForKey:key cacheType:cacheType completion:completionBlock];
        }
            break;
        case TXImageCachesManagerOperationPolicyLowestOnly: {
            id<TXImageCache> cache = caches.firstObject;
            [cache removeImageForKey:key cacheType:cacheType completion:completionBlock];
        }
            break;
        case TXImageCachesManagerOperationPolicyConcurrent: {
            TXImageCachesManagerOperation *operation = [TXImageCachesManagerOperation new];
            [operation beginWithTotalCount:caches.count];
            [self concurrentRemoveImageForKey:key cacheType:cacheType completion:completionBlock enumerator:caches.reverseObjectEnumerator operation:operation];
        }
            break;
        case TXImageCachesManagerOperationPolicySerial: {
            [self serialRemoveImageForKey:key cacheType:cacheType completion:completionBlock enumerator:caches.reverseObjectEnumerator];
        }
            break;
        default:
            break;
    }
}

- (void)containsImageForKey:(NSString *)key cacheType:(TXImageCacheType)cacheType completion:(TXImageCacheContainsCompletionBlock)completionBlock {
    if (!key) {
        return;
    }
    NSArray<id<TXImageCache>> *caches = self.caches;
    NSUInteger count = caches.count;
    if (count == 0) {
        return;
    } else if (count == 1) {
        [caches.firstObject containsImageForKey:key cacheType:cacheType completion:completionBlock];
        return;
    }
    switch (self.clearOperationPolicy) {
        case TXImageCachesManagerOperationPolicyHighestOnly: {
            id<TXImageCache> cache = caches.lastObject;
            [cache containsImageForKey:key cacheType:cacheType completion:completionBlock];
        }
            break;
        case TXImageCachesManagerOperationPolicyLowestOnly: {
            id<TXImageCache> cache = caches.firstObject;
            [cache containsImageForKey:key cacheType:cacheType completion:completionBlock];
        }
            break;
        case TXImageCachesManagerOperationPolicyConcurrent: {
            TXImageCachesManagerOperation *operation = [TXImageCachesManagerOperation new];
            [operation beginWithTotalCount:caches.count];
            [self concurrentContainsImageForKey:key cacheType:cacheType completion:completionBlock enumerator:caches.reverseObjectEnumerator operation:operation];
        }
            break;
        case TXImageCachesManagerOperationPolicySerial: {
            TXImageCachesManagerOperation *operation = [TXImageCachesManagerOperation new];
            [operation beginWithTotalCount:caches.count];
            [self serialContainsImageForKey:key cacheType:cacheType completion:completionBlock enumerator:caches.reverseObjectEnumerator operation:operation];
        }
            break;
        default:
            break;
    }
}

- (void)clearWithCacheType:(TXImageCacheType)cacheType completion:(SDWebImageNoParamsBlock)completionBlock {
    NSArray<id<TXImageCache>> *caches = self.caches;
    NSUInteger count = caches.count;
    if (count == 0) {
        return;
    } else if (count == 1) {
        [caches.firstObject clearWithCacheType:cacheType completion:completionBlock];
        return;
    }
    switch (self.clearOperationPolicy) {
        case TXImageCachesManagerOperationPolicyHighestOnly: {
            id<TXImageCache> cache = caches.lastObject;
            [cache clearWithCacheType:cacheType completion:completionBlock];
        }
            break;
        case TXImageCachesManagerOperationPolicyLowestOnly: {
            id<TXImageCache> cache = caches.firstObject;
            [cache clearWithCacheType:cacheType completion:completionBlock];
        }
            break;
        case TXImageCachesManagerOperationPolicyConcurrent: {
            TXImageCachesManagerOperation *operation = [TXImageCachesManagerOperation new];
            [operation beginWithTotalCount:caches.count];
            [self concurrentClearWithCacheType:cacheType completion:completionBlock enumerator:caches.reverseObjectEnumerator operation:operation];
        }
            break;
        case TXImageCachesManagerOperationPolicySerial: {
            [self serialClearWithCacheType:cacheType completion:completionBlock enumerator:caches.reverseObjectEnumerator];
        }
            break;
        default:
            break;
    }
}

#pragma mark - Concurrent Operation

- (void)concurrentQueryImageForKey:(NSString *)key options:(SDWebImageOptions)options context:(SDWebImageContext *)context cacheType:(TXImageCacheType)queryCacheType completion:(TXImageCacheQueryCompletionBlock)completionBlock enumerator:(NSEnumerator<id<TXImageCache>> *)enumerator operation:(TXImageCachesManagerOperation *)operation {
    NSParameterAssert(enumerator);
    NSParameterAssert(operation);
    for (id<TXImageCache> cache in enumerator) {
        [cache queryImageForKey:key options:options context:context cacheType:queryCacheType completion:^(UIImage * _Nullable image, NSData * _Nullable data, TXImageCacheType cacheType) {
            if (operation.isCancelled) {
                // Cancelled
                return;
            }
            if (operation.isFinished) {
                // Finished
                return;
            }
            [operation completeOne];
            if (image) {
                // Success
                [operation done];
                if (completionBlock) {
                    completionBlock(image, data, cacheType);
                }
                return;
            }
            if (operation.pendingCount == 0) {
                // Complete
                [operation done];
                if (completionBlock) {
                    completionBlock(nil, nil, TXImageCacheTypeNone);
                }
            }
        }];
    }
}

- (void)concurrentStoreImage:(UIImage *)image imageData:(NSData *)imageData forKey:(NSString *)key cacheType:(TXImageCacheType)cacheType completion:(SDWebImageNoParamsBlock)completionBlock enumerator:(NSEnumerator<id<TXImageCache>> *)enumerator operation:(TXImageCachesManagerOperation *)operation {
    NSParameterAssert(enumerator);
    NSParameterAssert(operation);
    for (id<TXImageCache> cache in enumerator) {
        [cache storeImage:image imageData:imageData forKey:key cacheType:cacheType completion:^{
            if (operation.isCancelled) {
                // Cancelled
                return;
            }
            if (operation.isFinished) {
                // Finished
                return;
            }
            [operation completeOne];
            if (operation.pendingCount == 0) {
                // Complete
                [operation done];
                if (completionBlock) {
                    completionBlock();
                }
            }
        }];
    }
}

- (void)concurrentRemoveImageForKey:(NSString *)key cacheType:(TXImageCacheType)cacheType completion:(SDWebImageNoParamsBlock)completionBlock enumerator:(NSEnumerator<id<TXImageCache>> *)enumerator operation:(TXImageCachesManagerOperation *)operation {
    NSParameterAssert(enumerator);
    NSParameterAssert(operation);
    for (id<TXImageCache> cache in enumerator) {
        [cache removeImageForKey:key cacheType:cacheType completion:^{
            if (operation.isCancelled) {
                // Cancelled
                return;
            }
            if (operation.isFinished) {
                // Finished
                return;
            }
            [operation completeOne];
            if (operation.pendingCount == 0) {
                // Complete
                [operation done];
                if (completionBlock) {
                    completionBlock();
                }
            }
        }];
    }
}

- (void)concurrentContainsImageForKey:(NSString *)key cacheType:(TXImageCacheType)cacheType completion:(TXImageCacheContainsCompletionBlock)completionBlock enumerator:(NSEnumerator<id<TXImageCache>> *)enumerator operation:(TXImageCachesManagerOperation *)operation {
    NSParameterAssert(enumerator);
    NSParameterAssert(operation);
    for (id<TXImageCache> cache in enumerator) {
        [cache containsImageForKey:key cacheType:cacheType completion:^(TXImageCacheType containsCacheType) {
            if (operation.isCancelled) {
                // Cancelled
                return;
            }
            if (operation.isFinished) {
                // Finished
                return;
            }
            [operation completeOne];
            if (containsCacheType != TXImageCacheTypeNone) {
                // Success
                [operation done];
                if (completionBlock) {
                    completionBlock(containsCacheType);
                }
                return;
            }
            if (operation.pendingCount == 0) {
                // Complete
                [operation done];
                if (completionBlock) {
                    completionBlock(TXImageCacheTypeNone);
                }
            }
        }];
    }
}

- (void)concurrentClearWithCacheType:(TXImageCacheType)cacheType completion:(SDWebImageNoParamsBlock)completionBlock enumerator:(NSEnumerator<id<TXImageCache>> *)enumerator operation:(TXImageCachesManagerOperation *)operation {
    NSParameterAssert(enumerator);
    NSParameterAssert(operation);
    for (id<TXImageCache> cache in enumerator) {
        [cache clearWithCacheType:cacheType completion:^{
            if (operation.isCancelled) {
                // Cancelled
                return;
            }
            if (operation.isFinished) {
                // Finished
                return;
            }
            [operation completeOne];
            if (operation.pendingCount == 0) {
                // Complete
                [operation done];
                if (completionBlock) {
                    completionBlock();
                }
            }
        }];
    }
}

#pragma mark - Serial Operation

- (void)serialQueryImageForKey:(NSString *)key options:(SDWebImageOptions)options context:(SDWebImageContext *)context cacheType:(TXImageCacheType)queryCacheType completion:(TXImageCacheQueryCompletionBlock)completionBlock enumerator:(NSEnumerator<id<TXImageCache>> *)enumerator operation:(TXImageCachesManagerOperation *)operation {
    NSParameterAssert(enumerator);
    NSParameterAssert(operation);
    id<TXImageCache> cache = enumerator.nextObject;
    if (!cache) {
        // Complete
        [operation done];
        if (completionBlock) {
            completionBlock(nil, nil, TXImageCacheTypeNone);
        }
        return;
    }
    @weakify(self);
    [cache queryImageForKey:key options:options context:context cacheType:queryCacheType completion:^(UIImage * _Nullable image, NSData * _Nullable data, TXImageCacheType cacheType) {
        @strongify(self);
        if (operation.isCancelled) {
            // Cancelled
            return;
        }
        if (operation.isFinished) {
            // Finished
            return;
        }
        [operation completeOne];
        if (image) {
            // Success
            [operation done];
            if (completionBlock) {
                completionBlock(image, data, cacheType);
            }
            return;
        }
        // Next
        [self serialQueryImageForKey:key options:options context:context cacheType:queryCacheType completion:completionBlock enumerator:enumerator operation:operation];
    }];
}

- (void)serialStoreImage:(UIImage *)image imageData:(NSData *)imageData forKey:(NSString *)key cacheType:(TXImageCacheType)cacheType completion:(SDWebImageNoParamsBlock)completionBlock enumerator:(NSEnumerator<id<TXImageCache>> *)enumerator {
    NSParameterAssert(enumerator);
    id<TXImageCache> cache = enumerator.nextObject;
    if (!cache) {
        // Complete
        if (completionBlock) {
            completionBlock();
        }
        return;
    }
    @weakify(self);
    [cache storeImage:image imageData:imageData forKey:key cacheType:cacheType completion:^{
        @strongify(self);
        // Next
        [self serialStoreImage:image imageData:imageData forKey:key cacheType:cacheType completion:completionBlock enumerator:enumerator];
    }];
}

- (void)serialRemoveImageForKey:(NSString *)key cacheType:(TXImageCacheType)cacheType completion:(SDWebImageNoParamsBlock)completionBlock enumerator:(NSEnumerator<id<TXImageCache>> *)enumerator {
    NSParameterAssert(enumerator);
    id<TXImageCache> cache = enumerator.nextObject;
    if (!cache) {
        // Complete
        if (completionBlock) {
            completionBlock();
        }
        return;
    }
    @weakify(self);
    [cache removeImageForKey:key cacheType:cacheType completion:^{
        @strongify(self);
        // Next
        [self serialRemoveImageForKey:key cacheType:cacheType completion:completionBlock enumerator:enumerator];
    }];
}

- (void)serialContainsImageForKey:(NSString *)key cacheType:(TXImageCacheType)cacheType completion:(TXImageCacheContainsCompletionBlock)completionBlock enumerator:(NSEnumerator<id<TXImageCache>> *)enumerator operation:(TXImageCachesManagerOperation *)operation {
    NSParameterAssert(enumerator);
    NSParameterAssert(operation);
    id<TXImageCache> cache = enumerator.nextObject;
    if (!cache) {
        // Complete
        [operation done];
        if (completionBlock) {
            completionBlock(TXImageCacheTypeNone);
        }
        return;
    }
    @weakify(self);
    [cache containsImageForKey:key cacheType:cacheType completion:^(TXImageCacheType containsCacheType) {
        @strongify(self);
        if (operation.isCancelled) {
            // Cancelled
            return;
        }
        if (operation.isFinished) {
            // Finished
            return;
        }
        [operation completeOne];
        if (containsCacheType != TXImageCacheTypeNone) {
            // Success
            [operation done];
            if (completionBlock) {
                completionBlock(containsCacheType);
            }
            return;
        }
        // Next
        [self serialContainsImageForKey:key cacheType:cacheType completion:completionBlock enumerator:enumerator operation:operation];
    }];
}

- (void)serialClearWithCacheType:(TXImageCacheType)cacheType completion:(SDWebImageNoParamsBlock)completionBlock enumerator:(NSEnumerator<id<TXImageCache>> *)enumerator {
    NSParameterAssert(enumerator);
    id<TXImageCache> cache = enumerator.nextObject;
    if (!cache) {
        // Complete
        if (completionBlock) {
            completionBlock();
        }
        return;
    }
    @weakify(self);
    [cache clearWithCacheType:cacheType completion:^{
        @strongify(self);
        // Next
        [self serialClearWithCacheType:cacheType completion:completionBlock enumerator:enumerator];
    }];
}

@end
