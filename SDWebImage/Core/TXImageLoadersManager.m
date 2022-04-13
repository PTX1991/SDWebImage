/*
 * This file is part of the SDWebImage package.
 * (c) Olivier Poitrey <rs@dailymotion.com>
 *
 * For the full copyright and license information, please view the LICENSE
 * file that was distributed with this source code.
 */

#import "TXImageLoadersManager.h"
#import "TXWebImageDownloader.h"
#import "TXInternalMacros.h"

@interface TXImageLoadersManager ()

@property (nonatomic, strong, nonnull) NSMutableArray<id<TXImageLoader>> *imageLoaders;

@end

@implementation TXImageLoadersManager {
    SD_LOCK_DECLARE(_loadersLock);
}

+ (TXImageLoadersManager *)sharedManager {
    static dispatch_once_t onceToken;
    static TXImageLoadersManager *manager;
    dispatch_once(&onceToken, ^{
        manager = [[TXImageLoadersManager alloc] init];
    });
    return manager;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        // initialize with default image loaders
        _imageLoaders = [NSMutableArray arrayWithObject:[TXWebImageDownloader sharedDownloader]];
        SD_LOCK_INIT(_loadersLock);
    }
    return self;
}

- (NSArray<id<TXImageLoader>> *)loaders {
    SD_LOCK(_loadersLock);
    NSArray<id<TXImageLoader>>* loaders = [_imageLoaders copy];
    SD_UNLOCK(_loadersLock);
    return loaders;
}

- (void)setLoaders:(NSArray<id<TXImageLoader>> *)loaders {
    SD_LOCK(_loadersLock);
    [_imageLoaders removeAllObjects];
    if (loaders.count) {
        [_imageLoaders addObjectsFromArray:loaders];
    }
    SD_UNLOCK(_loadersLock);
}

#pragma mark - Loader Property

- (void)addLoader:(id<TXImageLoader>)loader {
    if (![loader conformsToProtocol:@protocol(TXImageLoader)]) {
        return;
    }
    SD_LOCK(_loadersLock);
    [_imageLoaders addObject:loader];
    SD_UNLOCK(_loadersLock);
}

- (void)removeLoader:(id<TXImageLoader>)loader {
    if (![loader conformsToProtocol:@protocol(TXImageLoader)]) {
        return;
    }
    SD_LOCK(_loadersLock);
    [_imageLoaders removeObject:loader];
    SD_UNLOCK(_loadersLock);
}

#pragma mark - TXImageLoader

- (BOOL)canRequestImageForURL:(nullable NSURL *)url {
    return [self canRequestImageForURL:url options:0 context:nil];
}

- (BOOL)canRequestImageForURL:(NSURL *)url options:(SDWebImageOptions)options context:(SDWebImageContext *)context {
    NSArray<id<TXImageLoader>> *loaders = self.loaders;
    for (id<TXImageLoader> loader in loaders.reverseObjectEnumerator) {
        if ([loader respondsToSelector:@selector(canRequestImageForURL:options:context:)]) {
            if ([loader canRequestImageForURL:url options:options context:context]) {
                return YES;
            }
        } else {
            if ([loader canRequestImageForURL:url]) {
                return YES;
            }
        }
    }
    return NO;
}

- (id<TXWebImageOperation>)requestImageWithURL:(NSURL *)url options:(SDWebImageOptions)options context:(SDWebImageContext *)context progress:(TXImageLoaderProgressBlock)progressBlock completed:(TXImageLoaderCompletedBlock)completedBlock {
    if (!url) {
        return nil;
    }
    NSArray<id<TXImageLoader>> *loaders = self.loaders;
    for (id<TXImageLoader> loader in loaders.reverseObjectEnumerator) {
        if ([loader canRequestImageForURL:url]) {
            return [loader requestImageWithURL:url options:options context:context progress:progressBlock completed:completedBlock];
        }
    }
    return nil;
}

- (BOOL)shouldBlockFailedURLWithURL:(NSURL *)url error:(NSError *)error {
    NSArray<id<TXImageLoader>> *loaders = self.loaders;
    for (id<TXImageLoader> loader in loaders.reverseObjectEnumerator) {
        if ([loader canRequestImageForURL:url]) {
            return [loader shouldBlockFailedURLWithURL:url error:error];
        }
    }
    return NO;
}

@end
