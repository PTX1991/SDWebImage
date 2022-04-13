/*
 * This file is part of the SDWebImage package.
 * (c) Olivier Poitrey <rs@dailymotion.com>
 *
 * For the full copyright and license information, please view the LICENSE
 * file that was distributed with this source code.
 */

#import "TXImageCodersManager.h"
#import "TXImageIOCoder.h"
#import "TXImageGIFCoder.h"
#import "TXImageAPNGCoder.h"
#import "TXImageHEICCoder.h"
#import "TXInternalMacros.h"

@interface TXImageCodersManager ()

@property (nonatomic, strong, nonnull) NSMutableArray<id<TXImageCoder>> *imageCoders;

@end

@implementation TXImageCodersManager {
    SD_LOCK_DECLARE(_codersLock);
}

+ (nonnull instancetype)sharedManager {
    static dispatch_once_t once;
    static id instance;
    dispatch_once(&once, ^{
        instance = [self new];
    });
    return instance;
}

- (instancetype)init {
    if (self = [super init]) {
        // initialize with default coders
        _imageCoders = [NSMutableArray arrayWithArray:@[[TXImageIOCoder sharedCoder], [TXImageGIFCoder sharedCoder], [TXImageAPNGCoder sharedCoder]]];
        SD_LOCK_INIT(_codersLock);
    }
    return self;
}

- (NSArray<id<TXImageCoder>> *)coders {
    SD_LOCK(_codersLock);
    NSArray<id<TXImageCoder>> *coders = [_imageCoders copy];
    SD_UNLOCK(_codersLock);
    return coders;
}

- (void)setCoders:(NSArray<id<TXImageCoder>> *)coders {
    SD_LOCK(_codersLock);
    [_imageCoders removeAllObjects];
    if (coders.count) {
        [_imageCoders addObjectsFromArray:coders];
    }
    SD_UNLOCK(_codersLock);
}

#pragma mark - Coder IO operations

- (void)addCoder:(nonnull id<TXImageCoder>)coder {
    if (![coder conformsToProtocol:@protocol(TXImageCoder)]) {
        return;
    }
    SD_LOCK(_codersLock);
    [_imageCoders addObject:coder];
    SD_UNLOCK(_codersLock);
}

- (void)removeCoder:(nonnull id<TXImageCoder>)coder {
    if (![coder conformsToProtocol:@protocol(TXImageCoder)]) {
        return;
    }
    SD_LOCK(_codersLock);
    [_imageCoders removeObject:coder];
    SD_UNLOCK(_codersLock);
}

#pragma mark - TXImageCoder
- (BOOL)canDecodeFromData:(NSData *)data {
    NSArray<id<TXImageCoder>> *coders = self.coders;
    for (id<TXImageCoder> coder in coders.reverseObjectEnumerator) {
        if ([coder canDecodeFromData:data]) {
            return YES;
        }
    }
    return NO;
}

- (BOOL)canEncodeToFormat:(SDImageFormat)format {
    NSArray<id<TXImageCoder>> *coders = self.coders;
    for (id<TXImageCoder> coder in coders.reverseObjectEnumerator) {
        if ([coder canEncodeToFormat:format]) {
            return YES;
        }
    }
    return NO;
}

- (UIImage *)decodedImageWithData:(NSData *)data options:(nullable TXImageCoderOptions *)options {
    if (!data) {
        return nil;
    }
    UIImage *image;
    NSArray<id<TXImageCoder>> *coders = self.coders;
    for (id<TXImageCoder> coder in coders.reverseObjectEnumerator) {
        if ([coder canDecodeFromData:data]) {
            image = [coder decodedImageWithData:data options:options];
            break;
        }
    }
    
    return image;
}

- (NSData *)encodedDataWithImage:(UIImage *)image format:(SDImageFormat)format options:(nullable TXImageCoderOptions *)options {
    if (!image) {
        return nil;
    }
    NSArray<id<TXImageCoder>> *coders = self.coders;
    for (id<TXImageCoder> coder in coders.reverseObjectEnumerator) {
        if ([coder canEncodeToFormat:format]) {
            return [coder encodedDataWithImage:image format:format options:options];
        }
    }
    return nil;
}

@end
