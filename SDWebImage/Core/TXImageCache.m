/*
 * This file is part of the SDWebImage package.
 * (c) Olivier Poitrey <rs@dailymotion.com>
 *
 * For the full copyright and license information, please view the LICENSE
 * file that was distributed with this source code.
 */

#import "TXImageCache.h"
#import "NSImage+Compatibility.h"
#import "TXImageCodersManager.h"
#import "TXImageCoderHelper.h"
#import "TXAnimatedImage.h"
#import "UIImage+MemoryCacheCost.h"
#import "UIImage+Metadata.h"
#import "UIImage+ExtendedCacheData.h"

static NSString * _defaultDiskCacheDirectory;

@interface TXImageCache ()

#pragma mark - Properties
@property (nonatomic, strong, readwrite, nonnull) id<TXMemoryCache> memoryCache;
@property (nonatomic, strong, readwrite, nonnull) id<TXDiskCache> diskCache;
@property (nonatomic, copy, readwrite, nonnull) TXImageCacheConfig *config;
@property (nonatomic, copy, readwrite, nonnull) NSString *diskCachePath;
@property (nonatomic, strong, nullable) dispatch_queue_t ioQueue;

@end


@implementation TXImageCache

#pragma mark - Singleton, init, dealloc

+ (nonnull instancetype)sharedImageCache {
    static dispatch_once_t once;
    static id instance;
    dispatch_once(&once, ^{
        instance = [self new];
    });
    return instance;
}

+ (NSString *)defaultDiskCacheDirectory {
    if (!_defaultDiskCacheDirectory) {
        _defaultDiskCacheDirectory = [[self userCacheDirectory] stringByAppendingPathComponent:@"com.hackemist.TXImageCache"];
    }
    return _defaultDiskCacheDirectory;
}

+ (void)setDefaultDiskCacheDirectory:(NSString *)defaultDiskCacheDirectory {
    _defaultDiskCacheDirectory = [defaultDiskCacheDirectory copy];
}

- (instancetype)init {
    return [self initWithNamespace:@"default"];
}

- (nonnull instancetype)initWithNamespace:(nonnull NSString *)ns {
    return [self initWithNamespace:ns diskCacheDirectory:nil];
}

- (nonnull instancetype)initWithNamespace:(nonnull NSString *)ns
                       diskCacheDirectory:(nullable NSString *)directory {
    return [self initWithNamespace:ns diskCacheDirectory:directory config:TXImageCacheConfig.defaultCacheConfig];
}

- (nonnull instancetype)initWithNamespace:(nonnull NSString *)ns
                       diskCacheDirectory:(nullable NSString *)directory
                                   config:(nullable TXImageCacheConfig *)config {
    if ((self = [super init])) {
        NSAssert(ns, @"Cache namespace should not be nil");
        
        // Create IO serial queue
        _ioQueue = dispatch_queue_create("com.hackemist.TXImageCache", DISPATCH_QUEUE_SERIAL);
        
        if (!config) {
            config = TXImageCacheConfig.defaultCacheConfig;
        }
        _config = [config copy];
        
        // Init the memory cache
        NSAssert([config.memoryCacheClass conformsToProtocol:@protocol(TXMemoryCache)], @"Custom memory cache class must conform to `TXMemoryCache` protocol");
        _memoryCache = [[config.memoryCacheClass alloc] initWithConfig:_config];
        
        // Init the disk cache
        if (!directory) {
            // Use default disk cache directory
            directory = [self.class defaultDiskCacheDirectory];
        }
        _diskCachePath = [directory stringByAppendingPathComponent:ns];
        
        NSAssert([config.diskCacheClass conformsToProtocol:@protocol(TXDiskCache)], @"Custom disk cache class must conform to `TXDiskCache` protocol");
        _diskCache = [[config.diskCacheClass alloc] initWithCachePath:_diskCachePath config:_config];
        
        // Check and migrate disk cache directory if need
        [self migrateDiskCacheDirectory];

#if SD_UIKIT
        // Subscribe to app events
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(applicationWillTerminate:)
                                                     name:UIApplicationWillTerminateNotification
                                                   object:nil];

        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(applicationDidEnterBackground:)
                                                     name:UIApplicationDidEnterBackgroundNotification
                                                   object:nil];
#endif
#if SD_MAC
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(applicationWillTerminate:)
                                                     name:NSApplicationWillTerminateNotification
                                                   object:nil];
#endif
    }

    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - Cache paths

- (nullable NSString *)cachePathForKey:(nullable NSString *)key {
    if (!key) {
        return nil;
    }
    return [self.diskCache cachePathForKey:key];
}

+ (nullable NSString *)userCacheDirectory {
    NSArray<NSString *> *paths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
    return paths.firstObject;
}

- (void)migrateDiskCacheDirectory {
    if ([self.diskCache isKindOfClass:[TXDiskCache class]]) {
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            // ~/Library/Caches/com.hackemist.TXImageCache/default/
            NSString *newDefaultPath = [[[self.class userCacheDirectory] stringByAppendingPathComponent:@"com.hackemist.TXImageCache"] stringByAppendingPathComponent:@"default"];
            // ~/Library/Caches/default/com.hackemist.SDWebImageCache.default/
            NSString *oldDefaultPath = [[[self.class userCacheDirectory] stringByAppendingPathComponent:@"default"] stringByAppendingPathComponent:@"com.hackemist.SDWebImageCache.default"];
            dispatch_async(self.ioQueue, ^{
                [((TXDiskCache *)self.diskCache) moveCacheDirectoryFromPath:oldDefaultPath toPath:newDefaultPath];
            });
        });
    }
}

#pragma mark - Store Ops

- (void)storeImage:(nullable UIImage *)image
            forKey:(nullable NSString *)key
        completion:(nullable SDWebImageNoParamsBlock)completionBlock {
    [self storeImage:image imageData:nil forKey:key toDisk:YES completion:completionBlock];
}

- (void)storeImage:(nullable UIImage *)image
            forKey:(nullable NSString *)key
            toDisk:(BOOL)toDisk
        completion:(nullable SDWebImageNoParamsBlock)completionBlock {
    [self storeImage:image imageData:nil forKey:key toDisk:toDisk completion:completionBlock];
}

- (void)storeImage:(nullable UIImage *)image
         imageData:(nullable NSData *)imageData
            forKey:(nullable NSString *)key
            toDisk:(BOOL)toDisk
        completion:(nullable SDWebImageNoParamsBlock)completionBlock {
    return [self storeImage:image imageData:imageData forKey:key toMemory:YES toDisk:toDisk completion:completionBlock];
}

- (void)storeImage:(nullable UIImage *)image
         imageData:(nullable NSData *)imageData
            forKey:(nullable NSString *)key
          toMemory:(BOOL)toMemory
            toDisk:(BOOL)toDisk
        completion:(nullable SDWebImageNoParamsBlock)completionBlock {
    if (!image || !key) {
        if (completionBlock) {
            completionBlock();
        }
        return;
    }
    // if memory cache is enabled
    if (toMemory && self.config.shouldCacheImagesInMemory) {
        NSUInteger cost = image.sd_memoryCost;
        [self.memoryCache setObject:image forKey:key cost:cost];
    }
    
    if (!toDisk) {
        if (completionBlock) {
            completionBlock();
        }
        return;
    }
    dispatch_async(self.ioQueue, ^{
        @autoreleasepool {
            NSData *data = imageData;
            if (!data && [image conformsToProtocol:@protocol(TXAnimatedImage)]) {
                // If image is custom animated image class, prefer its original animated data
                data = [((id<TXAnimatedImage>)image) animatedImageData];
            }
            if (!data && image) {
                // Check image's associated image format, may return .undefined
                SDImageFormat format = image.sd_imageFormat;
                if (format == SDImageFormatUndefined) {
                    // If image is animated, use GIF (APNG may be better, but has bugs before macOS 10.14)
                    if (image.sd_isAnimated) {
                        format = SDImageFormatGIF;
                    } else {
                        // If we do not have any data to detect image format, check whether it contains alpha channel to use PNG or JPEG format
                        format = [TXImageCoderHelper CGImageContainsAlpha:image.CGImage] ? SDImageFormatPNG : SDImageFormatJPEG;
                    }
                }
                data = [[TXImageCodersManager sharedManager] encodedDataWithImage:image format:format options:nil];
            }
            [self _storeImageDataToDisk:data forKey:key];
            [self _archivedDataWithImage:image forKey:key];
        }
        
        if (completionBlock) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completionBlock();
            });
        }
    });
}

- (void)_archivedDataWithImage:(UIImage *)image forKey:(NSString *)key {
    if (!image) {
        return;
    }
    // Check extended data
    id extendedObject = image.sd_extendedObject;
    if (![extendedObject conformsToProtocol:@protocol(NSCoding)]) {
        return;
    }
    NSData *extendedData;
    if (@available(iOS 11, tvOS 11, macOS 10.13, watchOS 4, *)) {
        NSError *error;
        extendedData = [NSKeyedArchiver archivedDataWithRootObject:extendedObject requiringSecureCoding:NO error:&error];
        if (error) {
            NSLog(@"NSKeyedArchiver archive failed with error: %@", error);
        }
    } else {
        @try {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
            extendedData = [NSKeyedArchiver archivedDataWithRootObject:extendedObject];
#pragma clang diagnostic pop
        } @catch (NSException *exception) {
            NSLog(@"NSKeyedArchiver archive failed with exception: %@", exception);
        }
    }
    if (extendedData) {
        [self.diskCache setExtendedData:extendedData forKey:key];
    }
}

- (void)storeImageToMemory:(UIImage *)image forKey:(NSString *)key {
    if (!image || !key) {
        return;
    }
    NSUInteger cost = image.sd_memoryCost;
    [self.memoryCache setObject:image forKey:key cost:cost];
}

- (void)storeImageDataToDisk:(nullable NSData *)imageData
                      forKey:(nullable NSString *)key {
    if (!imageData || !key) {
        return;
    }
    
    dispatch_sync(self.ioQueue, ^{
        [self _storeImageDataToDisk:imageData forKey:key];
    });
}

// Make sure to call from io queue by caller
- (void)_storeImageDataToDisk:(nullable NSData *)imageData forKey:(nullable NSString *)key {
    if (!imageData || !key) {
        return;
    }
    
    [self.diskCache setData:imageData forKey:key];
}

#pragma mark - Query and Retrieve Ops

- (void)diskImageExistsWithKey:(nullable NSString *)key completion:(nullable TXImageCacheCheckCompletionBlock)completionBlock {
    dispatch_async(self.ioQueue, ^{
        BOOL exists = [self _diskImageDataExistsWithKey:key];
        if (completionBlock) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completionBlock(exists);
            });
        }
    });
}

- (BOOL)diskImageDataExistsWithKey:(nullable NSString *)key {
    if (!key) {
        return NO;
    }
    
    __block BOOL exists = NO;
    dispatch_sync(self.ioQueue, ^{
        exists = [self _diskImageDataExistsWithKey:key];
    });
    
    return exists;
}

// Make sure to call from io queue by caller
- (BOOL)_diskImageDataExistsWithKey:(nullable NSString *)key {
    if (!key) {
        return NO;
    }
    
    return [self.diskCache containsDataForKey:key];
}

- (void)diskImageDataQueryForKey:(NSString *)key completion:(TXImageCacheQueryDataCompletionBlock)completionBlock {
    dispatch_async(self.ioQueue, ^{
        NSData *imageData = [self diskImageDataBySearchingAllPathsForKey:key];
        if (completionBlock) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completionBlock(imageData);
            });
        }
    });
}

- (nullable NSData *)diskImageDataForKey:(nullable NSString *)key {
    if (!key) {
        return nil;
    }
    __block NSData *imageData = nil;
    dispatch_sync(self.ioQueue, ^{
        imageData = [self diskImageDataBySearchingAllPathsForKey:key];
    });
    
    return imageData;
}

- (nullable UIImage *)imageFromMemoryCacheForKey:(nullable NSString *)key {
    return [self.memoryCache objectForKey:key];
}

- (nullable UIImage *)imageFromDiskCacheForKey:(nullable NSString *)key {
    return [self imageFromDiskCacheForKey:key options:0 context:nil];
}

- (nullable UIImage *)imageFromDiskCacheForKey:(nullable NSString *)key options:(TXImageCacheOptions)options context:(nullable SDWebImageContext *)context {
    NSData *data = [self diskImageDataForKey:key];
    UIImage *diskImage = [self diskImageForKey:key data:data options:options context:context];
    
    BOOL shouldCacheToMomery = YES;
    if (context[SDWebImageContextStoreCacheType]) {
        TXImageCacheType cacheType = [context[SDWebImageContextStoreCacheType] integerValue];
        shouldCacheToMomery = (cacheType == TXImageCacheTypeAll || cacheType == TXImageCacheTypeMemory);
    }
    if (diskImage && self.config.shouldCacheImagesInMemory && shouldCacheToMomery) {
        NSUInteger cost = diskImage.sd_memoryCost;
        [self.memoryCache setObject:diskImage forKey:key cost:cost];
    }

    return diskImage;
}

- (nullable UIImage *)imageFromCacheForKey:(nullable NSString *)key {
    return [self imageFromCacheForKey:key options:0 context:nil];
}

- (nullable UIImage *)imageFromCacheForKey:(nullable NSString *)key options:(TXImageCacheOptions)options context:(nullable SDWebImageContext *)context {
    // First check the in-memory cache...
    UIImage *image = [self imageFromMemoryCacheForKey:key];
    if (image) {
        if (options & TXImageCacheDecodeFirstFrameOnly) {
            // Ensure static image
            Class animatedImageClass = image.class;
            if (image.sd_isAnimated || ([animatedImageClass isSubclassOfClass:[UIImage class]] && [animatedImageClass conformsToProtocol:@protocol(TXAnimatedImage)])) {
#if SD_MAC
                image = [[NSImage alloc] initWithCGImage:image.CGImage scale:image.scale orientation:kCGImagePropertyOrientationUp];
#else
                image = [[UIImage alloc] initWithCGImage:image.CGImage scale:image.scale orientation:image.imageOrientation];
#endif
            }
        } else if (options & TXImageCacheMatchAnimatedImageClass) {
            // Check image class matching
            Class animatedImageClass = image.class;
            Class desiredImageClass = context[SDWebImageContextAnimatedImageClass];
            if (desiredImageClass && ![animatedImageClass isSubclassOfClass:desiredImageClass]) {
                image = nil;
            }
        }
    }
    
    // Since we don't need to query imageData, return image if exist
    if (image) {
        return image;
    }
    
    // Second check the disk cache...
    image = [self imageFromDiskCacheForKey:key options:options context:context];
    return image;
}

- (nullable NSData *)diskImageDataBySearchingAllPathsForKey:(nullable NSString *)key {
    if (!key) {
        return nil;
    }
    
    NSData *data = [self.diskCache dataForKey:key];
    if (data) {
        return data;
    }
    
    // Addtional cache path for custom pre-load cache
    if (self.additionalCachePathBlock) {
        NSString *filePath = self.additionalCachePathBlock(key);
        if (filePath) {
            data = [NSData dataWithContentsOfFile:filePath options:self.config.diskCacheReadingOptions error:nil];
        }
    }

    return data;
}

- (nullable UIImage *)diskImageForKey:(nullable NSString *)key {
    NSData *data = [self diskImageDataForKey:key];
    return [self diskImageForKey:key data:data];
}

- (nullable UIImage *)diskImageForKey:(nullable NSString *)key data:(nullable NSData *)data {
    return [self diskImageForKey:key data:data options:0 context:nil];
}

- (nullable UIImage *)diskImageForKey:(nullable NSString *)key data:(nullable NSData *)data options:(TXImageCacheOptions)options context:(SDWebImageContext *)context {
    if (!data) {
        return nil;
    }
    UIImage *image = TXImageCacheDecodeImageData(data, key, [[self class] imageOptionsFromCacheOptions:options], context);
    [self _unarchiveObjectWithImage:image forKey:key];
    return image;
}

- (void)_unarchiveObjectWithImage:(UIImage *)image forKey:(NSString *)key {
    if (!image) {
        return;
    }
    // Check extended data
    NSData *extendedData = [self.diskCache extendedDataForKey:key];
    if (!extendedData) {
        return;
    }
    id extendedObject;
    if (@available(iOS 11, tvOS 11, macOS 10.13, watchOS 4, *)) {
        NSError *error;
        NSKeyedUnarchiver *unarchiver = [[NSKeyedUnarchiver alloc] initForReadingFromData:extendedData error:&error];
        unarchiver.requiresSecureCoding = NO;
        extendedObject = [unarchiver decodeTopLevelObjectForKey:NSKeyedArchiveRootObjectKey error:&error];
        if (error) {
            NSLog(@"NSKeyedUnarchiver unarchive failed with error: %@", error);
        }
    } else {
        @try {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
            extendedObject = [NSKeyedUnarchiver unarchiveObjectWithData:extendedData];
#pragma clang diagnostic pop
        } @catch (NSException *exception) {
            NSLog(@"NSKeyedUnarchiver unarchive failed with exception: %@", exception);
        }
    }
    image.sd_extendedObject = extendedObject;
}

- (nullable NSOperation *)queryCacheOperationForKey:(NSString *)key done:(TXImageCacheQueryCompletionBlock)doneBlock {
    return [self queryCacheOperationForKey:key options:0 done:doneBlock];
}

- (nullable NSOperation *)queryCacheOperationForKey:(NSString *)key options:(TXImageCacheOptions)options done:(TXImageCacheQueryCompletionBlock)doneBlock {
    return [self queryCacheOperationForKey:key options:options context:nil done:doneBlock];
}

- (nullable NSOperation *)queryCacheOperationForKey:(nullable NSString *)key options:(TXImageCacheOptions)options context:(nullable SDWebImageContext *)context done:(nullable TXImageCacheQueryCompletionBlock)doneBlock {
    return [self queryCacheOperationForKey:key options:options context:context cacheType:TXImageCacheTypeAll done:doneBlock];
}

- (nullable NSOperation *)queryCacheOperationForKey:(nullable NSString *)key options:(TXImageCacheOptions)options context:(nullable SDWebImageContext *)context cacheType:(TXImageCacheType)queryCacheType done:(nullable TXImageCacheQueryCompletionBlock)doneBlock {
    if (!key) {
        if (doneBlock) {
            doneBlock(nil, nil, TXImageCacheTypeNone);
        }
        return nil;
    }
    // Invalid cache type
    if (queryCacheType == TXImageCacheTypeNone) {
        if (doneBlock) {
            doneBlock(nil, nil, TXImageCacheTypeNone);
        }
        return nil;
    }
    
    // First check the in-memory cache...
    UIImage *image;
    if (queryCacheType != TXImageCacheTypeDisk) {
        image = [self imageFromMemoryCacheForKey:key];
    }
    
    if (image) {
        if (options & TXImageCacheDecodeFirstFrameOnly) {
            // Ensure static image
            Class animatedImageClass = image.class;
            if (image.sd_isAnimated || ([animatedImageClass isSubclassOfClass:[UIImage class]] && [animatedImageClass conformsToProtocol:@protocol(TXAnimatedImage)])) {
#if SD_MAC
                image = [[NSImage alloc] initWithCGImage:image.CGImage scale:image.scale orientation:kCGImagePropertyOrientationUp];
#else
                image = [[UIImage alloc] initWithCGImage:image.CGImage scale:image.scale orientation:image.imageOrientation];
#endif
            }
        } else if (options & TXImageCacheMatchAnimatedImageClass) {
            // Check image class matching
            Class animatedImageClass = image.class;
            Class desiredImageClass = context[SDWebImageContextAnimatedImageClass];
            if (desiredImageClass && ![animatedImageClass isSubclassOfClass:desiredImageClass]) {
                image = nil;
            }
        }
    }

    BOOL shouldQueryMemoryOnly = (queryCacheType == TXImageCacheTypeMemory) || (image && !(options & TXImageCacheQueryMemoryData));
    if (shouldQueryMemoryOnly) {
        if (doneBlock) {
            doneBlock(image, nil, TXImageCacheTypeMemory);
        }
        return nil;
    }
    
    // Second check the disk cache...
    NSOperation *operation = [NSOperation new];
    // Check whether we need to synchronously query disk
    // 1. in-memory cache hit & memoryDataSync
    // 2. in-memory cache miss & diskDataSync
    BOOL shouldQueryDiskSync = ((image && options & TXImageCacheQueryMemoryDataSync) ||
                                (!image && options & TXImageCacheQueryDiskDataSync));
    NSData* (^queryDiskDataBlock)(void) = ^NSData* {
        if (operation.isCancelled) {
            return nil;
        }
        
        return [self diskImageDataBySearchingAllPathsForKey:key];
    };
    
    UIImage* (^queryDiskImageBlock)(NSData*) = ^UIImage*(NSData* diskData) {
        if (operation.isCancelled) {
            return nil;
        }
        
        UIImage *diskImage;
        if (image) {
            // the image is from in-memory cache, but need image data
            diskImage = image;
        } else if (diskData) {
            BOOL shouldCacheToMomery = YES;
            if (context[SDWebImageContextStoreCacheType]) {
                TXImageCacheType cacheType = [context[SDWebImageContextStoreCacheType] integerValue];
                shouldCacheToMomery = (cacheType == TXImageCacheTypeAll || cacheType == TXImageCacheTypeMemory);
            }
            // decode image data only if in-memory cache missed
            diskImage = [self diskImageForKey:key data:diskData options:options context:context];
            if (shouldCacheToMomery && diskImage && self.config.shouldCacheImagesInMemory) {
                NSUInteger cost = diskImage.sd_memoryCost;
                [self.memoryCache setObject:diskImage forKey:key cost:cost];
            }
        }
        return diskImage;
    };
    
    // Query in ioQueue to keep IO-safe
    if (shouldQueryDiskSync) {
        __block NSData* diskData;
        __block UIImage* diskImage;
        dispatch_sync(self.ioQueue, ^{
            diskData = queryDiskDataBlock();
            diskImage = queryDiskImageBlock(diskData);
        });
        if (doneBlock) {
            doneBlock(diskImage, diskData, TXImageCacheTypeDisk);
        }
    } else {
        dispatch_async(self.ioQueue, ^{
            NSData* diskData = queryDiskDataBlock();
            UIImage* diskImage = queryDiskImageBlock(diskData);
            if (doneBlock) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    doneBlock(diskImage, diskData, TXImageCacheTypeDisk);
                });
            }
        });
    }
    
    return operation;
}

#pragma mark - Remove Ops

- (void)removeImageForKey:(nullable NSString *)key withCompletion:(nullable SDWebImageNoParamsBlock)completion {
    [self removeImageForKey:key fromDisk:YES withCompletion:completion];
}

- (void)removeImageForKey:(nullable NSString *)key fromDisk:(BOOL)fromDisk withCompletion:(nullable SDWebImageNoParamsBlock)completion {
    [self removeImageForKey:key fromMemory:YES fromDisk:fromDisk withCompletion:completion];
}

- (void)removeImageForKey:(nullable NSString *)key fromMemory:(BOOL)fromMemory fromDisk:(BOOL)fromDisk withCompletion:(nullable SDWebImageNoParamsBlock)completion {
    if (key == nil) {
        return;
    }

    if (fromMemory && self.config.shouldCacheImagesInMemory) {
        [self.memoryCache removeObjectForKey:key];
    }

    if (fromDisk) {
        dispatch_async(self.ioQueue, ^{
            [self.diskCache removeDataForKey:key];
            
            if (completion) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    completion();
                });
            }
        });
    } else if (completion) {
        completion();
    }
}

- (void)removeImageFromMemoryForKey:(NSString *)key {
    if (!key) {
        return;
    }
    
    [self.memoryCache removeObjectForKey:key];
}

- (void)removeImageFromDiskForKey:(NSString *)key {
    if (!key) {
        return;
    }
    dispatch_sync(self.ioQueue, ^{
        [self _removeImageFromDiskForKey:key];
    });
}

// Make sure to call from io queue by caller
- (void)_removeImageFromDiskForKey:(NSString *)key {
    if (!key) {
        return;
    }
    
    [self.diskCache removeDataForKey:key];
}

#pragma mark - Cache clean Ops

- (void)clearMemory {
    [self.memoryCache removeAllObjects];
}

- (void)clearDiskOnCompletion:(nullable SDWebImageNoParamsBlock)completion {
    dispatch_async(self.ioQueue, ^{
        [self.diskCache removeAllData];
        if (completion) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completion();
            });
        }
    });
}

- (void)deleteOldFilesWithCompletionBlock:(nullable SDWebImageNoParamsBlock)completionBlock {
    dispatch_async(self.ioQueue, ^{
        [self.diskCache removeExpiredData];
        if (completionBlock) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completionBlock();
            });
        }
    });
}

#pragma mark - UIApplicationWillTerminateNotification

#if SD_UIKIT || SD_MAC
- (void)applicationWillTerminate:(NSNotification *)notification {
    // On iOS/macOS, the async opeartion to remove exipred data will be terminated quickly
    // Try using the sync operation to ensure we reomve the exipred data
    if (!self.config.shouldRemoveExpiredDataWhenTerminate) {
        return;
    }
    dispatch_sync(self.ioQueue, ^{
        [self.diskCache removeExpiredData];
    });
}
#endif

#pragma mark - UIApplicationDidEnterBackgroundNotification

#if SD_UIKIT
- (void)applicationDidEnterBackground:(NSNotification *)notification {
    if (!self.config.shouldRemoveExpiredDataWhenEnterBackground) {
        return;
    }
    Class UIApplicationClass = NSClassFromString(@"UIApplication");
    if(!UIApplicationClass || ![UIApplicationClass respondsToSelector:@selector(sharedApplication)]) {
        return;
    }
    UIApplication *application = [UIApplication performSelector:@selector(sharedApplication)];
    __block UIBackgroundTaskIdentifier bgTask = [application beginBackgroundTaskWithExpirationHandler:^{
        // Clean up any unfinished task business by marking where you
        // stopped or ending the task outright.
        [application endBackgroundTask:bgTask];
        bgTask = UIBackgroundTaskInvalid;
    }];

    // Start the long-running task and return immediately.
    [self deleteOldFilesWithCompletionBlock:^{
        [application endBackgroundTask:bgTask];
        bgTask = UIBackgroundTaskInvalid;
    }];
}
#endif

#pragma mark - Cache Info

- (NSUInteger)totalDiskSize {
    __block NSUInteger size = 0;
    dispatch_sync(self.ioQueue, ^{
        size = [self.diskCache totalSize];
    });
    return size;
}

- (NSUInteger)totalDiskCount {
    __block NSUInteger count = 0;
    dispatch_sync(self.ioQueue, ^{
        count = [self.diskCache totalCount];
    });
    return count;
}

- (void)calculateSizeWithCompletionBlock:(nullable TXImageCacheCalculateSizeBlock)completionBlock {
    dispatch_async(self.ioQueue, ^{
        NSUInteger fileCount = [self.diskCache totalCount];
        NSUInteger totalSize = [self.diskCache totalSize];
        if (completionBlock) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completionBlock(fileCount, totalSize);
            });
        }
    });
}

#pragma mark - Helper
+ (SDWebImageOptions)imageOptionsFromCacheOptions:(TXImageCacheOptions)cacheOptions {
    SDWebImageOptions options = 0;
    if (cacheOptions & TXImageCacheScaleDownLargeImages) options |= SDWebImageScaleDownLargeImages;
    if (cacheOptions & TXImageCacheDecodeFirstFrameOnly) options |= SDWebImageDecodeFirstFrameOnly;
    if (cacheOptions & TXImageCachePreloadAllFrames) options |= SDWebImagePreloadAllFrames;
    if (cacheOptions & TXImageCacheAvoidDecodeImage) options |= SDWebImageAvoidDecodeImage;
    if (cacheOptions & TXImageCacheMatchAnimatedImageClass) options |= SDWebImageMatchAnimatedImageClass;
    
    return options;
}

@end

@implementation TXImageCache (TXImageCache)

#pragma mark - TXImageCache

- (id<TXWebImageOperation>)queryImageForKey:(NSString *)key options:(SDWebImageOptions)options context:(nullable SDWebImageContext *)context completion:(nullable TXImageCacheQueryCompletionBlock)completionBlock {
    return [self queryImageForKey:key options:options context:context cacheType:TXImageCacheTypeAll completion:completionBlock];
}

- (id<TXWebImageOperation>)queryImageForKey:(NSString *)key options:(SDWebImageOptions)options context:(nullable SDWebImageContext *)context cacheType:(TXImageCacheType)cacheType completion:(nullable TXImageCacheQueryCompletionBlock)completionBlock {
    TXImageCacheOptions cacheOptions = 0;
    if (options & SDWebImageQueryMemoryData) cacheOptions |= TXImageCacheQueryMemoryData;
    if (options & SDWebImageQueryMemoryDataSync) cacheOptions |= TXImageCacheQueryMemoryDataSync;
    if (options & SDWebImageQueryDiskDataSync) cacheOptions |= TXImageCacheQueryDiskDataSync;
    if (options & SDWebImageScaleDownLargeImages) cacheOptions |= TXImageCacheScaleDownLargeImages;
    if (options & SDWebImageAvoidDecodeImage) cacheOptions |= TXImageCacheAvoidDecodeImage;
    if (options & SDWebImageDecodeFirstFrameOnly) cacheOptions |= TXImageCacheDecodeFirstFrameOnly;
    if (options & SDWebImagePreloadAllFrames) cacheOptions |= TXImageCachePreloadAllFrames;
    if (options & SDWebImageMatchAnimatedImageClass) cacheOptions |= TXImageCacheMatchAnimatedImageClass;
    
    return [self queryCacheOperationForKey:key options:cacheOptions context:context cacheType:cacheType done:completionBlock];
}

- (void)storeImage:(UIImage *)image imageData:(NSData *)imageData forKey:(nullable NSString *)key cacheType:(TXImageCacheType)cacheType completion:(nullable SDWebImageNoParamsBlock)completionBlock {
    switch (cacheType) {
        case TXImageCacheTypeNone: {
            [self storeImage:image imageData:imageData forKey:key toMemory:NO toDisk:NO completion:completionBlock];
        }
            break;
        case TXImageCacheTypeMemory: {
            [self storeImage:image imageData:imageData forKey:key toMemory:YES toDisk:NO completion:completionBlock];
        }
            break;
        case TXImageCacheTypeDisk: {
            [self storeImage:image imageData:imageData forKey:key toMemory:NO toDisk:YES completion:completionBlock];
        }
            break;
        case TXImageCacheTypeAll: {
            [self storeImage:image imageData:imageData forKey:key toMemory:YES toDisk:YES completion:completionBlock];
        }
            break;
        default: {
            if (completionBlock) {
                completionBlock();
            }
        }
            break;
    }
}

- (void)removeImageForKey:(NSString *)key cacheType:(TXImageCacheType)cacheType completion:(nullable SDWebImageNoParamsBlock)completionBlock {
    switch (cacheType) {
        case TXImageCacheTypeNone: {
            [self removeImageForKey:key fromMemory:NO fromDisk:NO withCompletion:completionBlock];
        }
            break;
        case TXImageCacheTypeMemory: {
            [self removeImageForKey:key fromMemory:YES fromDisk:NO withCompletion:completionBlock];
        }
            break;
        case TXImageCacheTypeDisk: {
            [self removeImageForKey:key fromMemory:NO fromDisk:YES withCompletion:completionBlock];
        }
            break;
        case TXImageCacheTypeAll: {
            [self removeImageForKey:key fromMemory:YES fromDisk:YES withCompletion:completionBlock];
        }
            break;
        default: {
            if (completionBlock) {
                completionBlock();
            }
        }
            break;
    }
}

- (void)containsImageForKey:(NSString *)key cacheType:(TXImageCacheType)cacheType completion:(nullable TXImageCacheContainsCompletionBlock)completionBlock {
    switch (cacheType) {
        case TXImageCacheTypeNone: {
            if (completionBlock) {
                completionBlock(TXImageCacheTypeNone);
            }
        }
            break;
        case TXImageCacheTypeMemory: {
            BOOL isInMemoryCache = ([self imageFromMemoryCacheForKey:key] != nil);
            if (completionBlock) {
                completionBlock(isInMemoryCache ? TXImageCacheTypeMemory : TXImageCacheTypeNone);
            }
        }
            break;
        case TXImageCacheTypeDisk: {
            [self diskImageExistsWithKey:key completion:^(BOOL isInDiskCache) {
                if (completionBlock) {
                    completionBlock(isInDiskCache ? TXImageCacheTypeDisk : TXImageCacheTypeNone);
                }
            }];
        }
            break;
        case TXImageCacheTypeAll: {
            BOOL isInMemoryCache = ([self imageFromMemoryCacheForKey:key] != nil);
            if (isInMemoryCache) {
                if (completionBlock) {
                    completionBlock(TXImageCacheTypeMemory);
                }
                return;
            }
            [self diskImageExistsWithKey:key completion:^(BOOL isInDiskCache) {
                if (completionBlock) {
                    completionBlock(isInDiskCache ? TXImageCacheTypeDisk : TXImageCacheTypeNone);
                }
            }];
        }
            break;
        default:
            if (completionBlock) {
                completionBlock(TXImageCacheTypeNone);
            }
            break;
    }
}

- (void)clearWithCacheType:(TXImageCacheType)cacheType completion:(SDWebImageNoParamsBlock)completionBlock {
    switch (cacheType) {
        case TXImageCacheTypeNone: {
            if (completionBlock) {
                completionBlock();
            }
        }
            break;
        case TXImageCacheTypeMemory: {
            [self clearMemory];
            if (completionBlock) {
                completionBlock();
            }
        }
            break;
        case TXImageCacheTypeDisk: {
            [self clearDiskOnCompletion:completionBlock];
        }
            break;
        case TXImageCacheTypeAll: {
            [self clearMemory];
            [self clearDiskOnCompletion:completionBlock];
        }
            break;
        default: {
            if (completionBlock) {
                completionBlock();
            }
        }
            break;
    }
}

@end

