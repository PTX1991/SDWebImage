/*
 * This file is part of the SDWebImage package.
 * (c) Olivier Poitrey <rs@dailymotion.com>
 *
 * For the full copyright and license information, please view the LICENSE
 * file that was distributed with this source code.
 */

#import "TXImageLoader.h"
#import "TXWebImageCacheKeyFilter.h"
#import "TXImageCodersManager.h"
#import "TXImageCoderHelper.h"
#import "TXAnimatedImage.h"
#import "UIImage+Metadata.h"
#import "TXInternalMacros.h"
#import "objc/runtime.h"

SDWebImageContextOption const SDWebImageContextLoaderCachedImage = @"loaderCachedImage";

static void * TXImageLoaderProgressiveCoderKey = &TXImageLoaderProgressiveCoderKey;

id<SDProgressiveImageCoder> TXImageLoaderGetProgressiveCoder(id<TXWebImageOperation> operation) {
    NSCParameterAssert(operation);
    return objc_getAssociatedObject(operation, TXImageLoaderProgressiveCoderKey);
}

void TXImageLoaderSetProgressiveCoder(id<TXWebImageOperation> operation, id<SDProgressiveImageCoder> progressiveCoder) {
    NSCParameterAssert(operation);
    objc_setAssociatedObject(operation, TXImageLoaderProgressiveCoderKey, progressiveCoder, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

UIImage * _Nullable TXImageLoaderDecodeImageData(NSData * _Nonnull imageData, NSURL * _Nonnull imageURL, SDWebImageOptions options, SDWebImageContext * _Nullable context) {
    NSCParameterAssert(imageData);
    NSCParameterAssert(imageURL);
    
    UIImage *image;
    id<TXWebImageCacheKeyFilter> cacheKeyFilter = context[SDWebImageContextCacheKeyFilter];
    NSString *cacheKey;
    if (cacheKeyFilter) {
        cacheKey = [cacheKeyFilter cacheKeyForURL:imageURL];
    } else {
        cacheKey = imageURL.absoluteString;
    }
    BOOL decodeFirstFrame = SD_OPTIONS_CONTAINS(options, SDWebImageDecodeFirstFrameOnly);
    NSNumber *scaleValue = context[SDWebImageContextImageScaleFactor];
    CGFloat scale = scaleValue.doubleValue >= 1 ? scaleValue.doubleValue : SDImageScaleFactorForKey(cacheKey);
    NSNumber *preserveAspectRatioValue = context[SDWebImageContextImagePreserveAspectRatio];
    NSValue *thumbnailSizeValue;
    BOOL shouldScaleDown = SD_OPTIONS_CONTAINS(options, SDWebImageScaleDownLargeImages);
    if (shouldScaleDown) {
        CGFloat thumbnailPixels = TXImageCoderHelper.defaultScaleDownLimitBytes / 4;
        CGFloat dimension = ceil(sqrt(thumbnailPixels));
        thumbnailSizeValue = @(CGSizeMake(dimension, dimension));
    }
    if (context[SDWebImageContextImageThumbnailPixelSize]) {
        thumbnailSizeValue = context[SDWebImageContextImageThumbnailPixelSize];
    }
    
    TXImageCoderMutableOptions *mutableCoderOptions = [NSMutableDictionary dictionaryWithCapacity:2];
    mutableCoderOptions[TXImageCoderDecodeFirstFrameOnly] = @(decodeFirstFrame);
    mutableCoderOptions[TXImageCoderDecodeScaleFactor] = @(scale);
    mutableCoderOptions[TXImageCoderDecodePreserveAspectRatio] = preserveAspectRatioValue;
    mutableCoderOptions[TXImageCoderDecodeThumbnailPixelSize] = thumbnailSizeValue;
    mutableCoderOptions[TXImageCoderWebImageContext] = context;
    TXImageCoderOptions *coderOptions = [mutableCoderOptions copy];
    
    // Grab the image coder
    id<TXImageCoder> imageCoder;
    if ([context[SDWebImageContextImageCoder] conformsToProtocol:@protocol(TXImageCoder)]) {
        imageCoder = context[SDWebImageContextImageCoder];
    } else {
        imageCoder = [TXImageCodersManager sharedManager];
    }
    
    if (!decodeFirstFrame) {
        // check whether we should use `TXAnimatedImage`
        Class animatedImageClass = context[SDWebImageContextAnimatedImageClass];
        if ([animatedImageClass isSubclassOfClass:[UIImage class]] && [animatedImageClass conformsToProtocol:@protocol(TXAnimatedImage)]) {
            image = [[animatedImageClass alloc] initWithData:imageData scale:scale options:coderOptions];
            if (image) {
                // Preload frames if supported
                if (options & SDWebImagePreloadAllFrames && [image respondsToSelector:@selector(preloadAllFrames)]) {
                    [((id<TXAnimatedImage>)image) preloadAllFrames];
                }
            } else {
                // Check image class matching
                if (options & SDWebImageMatchAnimatedImageClass) {
                    return nil;
                }
            }
        }
    }
    if (!image) {
        image = [imageCoder decodedImageWithData:imageData options:coderOptions];
    }
    if (image) {
        BOOL shouldDecode = !SD_OPTIONS_CONTAINS(options, SDWebImageAvoidDecodeImage);
        if ([image.class conformsToProtocol:@protocol(TXAnimatedImage)]) {
            // `TXAnimatedImage` do not decode
            shouldDecode = NO;
        } else if (image.sd_isAnimated) {
            // animated image do not decode
            shouldDecode = NO;
        }
        
        if (shouldDecode) {
            image = [TXImageCoderHelper decodedImageWithImage:image];
        }
    }
    
    return image;
}

UIImage * _Nullable TXImageLoaderDecodeProgressiveImageData(NSData * _Nonnull imageData, NSURL * _Nonnull imageURL, BOOL finished,  id<TXWebImageOperation> _Nonnull operation, SDWebImageOptions options, SDWebImageContext * _Nullable context) {
    NSCParameterAssert(imageData);
    NSCParameterAssert(imageURL);
    NSCParameterAssert(operation);
    
    UIImage *image;
    id<TXWebImageCacheKeyFilter> cacheKeyFilter = context[SDWebImageContextCacheKeyFilter];
    NSString *cacheKey;
    if (cacheKeyFilter) {
        cacheKey = [cacheKeyFilter cacheKeyForURL:imageURL];
    } else {
        cacheKey = imageURL.absoluteString;
    }
    BOOL decodeFirstFrame = SD_OPTIONS_CONTAINS(options, SDWebImageDecodeFirstFrameOnly);
    NSNumber *scaleValue = context[SDWebImageContextImageScaleFactor];
    CGFloat scale = scaleValue.doubleValue >= 1 ? scaleValue.doubleValue : SDImageScaleFactorForKey(cacheKey);
    NSNumber *preserveAspectRatioValue = context[SDWebImageContextImagePreserveAspectRatio];
    NSValue *thumbnailSizeValue;
    BOOL shouldScaleDown = SD_OPTIONS_CONTAINS(options, SDWebImageScaleDownLargeImages);
    if (shouldScaleDown) {
        CGFloat thumbnailPixels = TXImageCoderHelper.defaultScaleDownLimitBytes / 4;
        CGFloat dimension = ceil(sqrt(thumbnailPixels));
        thumbnailSizeValue = @(CGSizeMake(dimension, dimension));
    }
    if (context[SDWebImageContextImageThumbnailPixelSize]) {
        thumbnailSizeValue = context[SDWebImageContextImageThumbnailPixelSize];
    }
    
    TXImageCoderMutableOptions *mutableCoderOptions = [NSMutableDictionary dictionaryWithCapacity:2];
    mutableCoderOptions[TXImageCoderDecodeFirstFrameOnly] = @(decodeFirstFrame);
    mutableCoderOptions[TXImageCoderDecodeScaleFactor] = @(scale);
    mutableCoderOptions[TXImageCoderDecodePreserveAspectRatio] = preserveAspectRatioValue;
    mutableCoderOptions[TXImageCoderDecodeThumbnailPixelSize] = thumbnailSizeValue;
    mutableCoderOptions[TXImageCoderWebImageContext] = context;
    TXImageCoderOptions *coderOptions = [mutableCoderOptions copy];
    
    // Grab the progressive image coder
    id<SDProgressiveImageCoder> progressiveCoder = TXImageLoaderGetProgressiveCoder(operation);
    if (!progressiveCoder) {
        id<SDProgressiveImageCoder> imageCoder = context[SDWebImageContextImageCoder];
        // Check the progressive coder if provided
        if ([imageCoder conformsToProtocol:@protocol(SDProgressiveImageCoder)]) {
            progressiveCoder = [[[imageCoder class] alloc] initIncrementalWithOptions:coderOptions];
        } else {
            // We need to create a new instance for progressive decoding to avoid conflicts
            for (id<TXImageCoder> coder in [TXImageCodersManager sharedManager].coders.reverseObjectEnumerator) {
                if ([coder conformsToProtocol:@protocol(SDProgressiveImageCoder)] &&
                    [((id<SDProgressiveImageCoder>)coder) canIncrementalDecodeFromData:imageData]) {
                    progressiveCoder = [[[coder class] alloc] initIncrementalWithOptions:coderOptions];
                    break;
                }
            }
        }
        TXImageLoaderSetProgressiveCoder(operation, progressiveCoder);
    }
    // If we can't find any progressive coder, disable progressive download
    if (!progressiveCoder) {
        return nil;
    }
    
    [progressiveCoder updateIncrementalData:imageData finished:finished];
    if (!decodeFirstFrame) {
        // check whether we should use `TXAnimatedImage`
        Class animatedImageClass = context[SDWebImageContextAnimatedImageClass];
        if ([animatedImageClass isSubclassOfClass:[UIImage class]] && [animatedImageClass conformsToProtocol:@protocol(TXAnimatedImage)] && [progressiveCoder conformsToProtocol:@protocol(TXAnimatedImageCoder)]) {
            image = [[animatedImageClass alloc] initWithAnimatedCoder:(id<TXAnimatedImageCoder>)progressiveCoder scale:scale];
            if (image) {
                // Progressive decoding does not preload frames
            } else {
                // Check image class matching
                if (options & SDWebImageMatchAnimatedImageClass) {
                    return nil;
                }
            }
        }
    }
    if (!image) {
        image = [progressiveCoder incrementalDecodedImageWithOptions:coderOptions];
    }
    if (image) {
        BOOL shouldDecode = !SD_OPTIONS_CONTAINS(options, SDWebImageAvoidDecodeImage);
        if ([image.class conformsToProtocol:@protocol(TXAnimatedImage)]) {
            // `TXAnimatedImage` do not decode
            shouldDecode = NO;
        } else if (image.sd_isAnimated) {
            // animated image do not decode
            shouldDecode = NO;
        }
        if (shouldDecode) {
            image = [TXImageCoderHelper decodedImageWithImage:image];
        }
        // mark the image as progressive (completed one are not mark as progressive)
        image.sd_isIncremental = !finished;
    }
    
    return image;
}
