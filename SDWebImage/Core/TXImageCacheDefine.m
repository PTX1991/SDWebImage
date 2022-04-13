/*
 * This file is part of the SDWebImage package.
 * (c) Olivier Poitrey <rs@dailymotion.com>
 *
 * For the full copyright and license information, please view the LICENSE
 * file that was distributed with this source code.
 */

#import "TXImageCacheDefine.h"
#import "TXImageCodersManager.h"
#import "TXImageCoderHelper.h"
#import "TXAnimatedImage.h"
#import "UIImage+Metadata.h"
#import "TXInternalMacros.h"

UIImage * _Nullable TXImageCacheDecodeImageData(NSData * _Nonnull imageData, NSString * _Nonnull cacheKey, SDWebImageOptions options, SDWebImageContext * _Nullable context) {
    UIImage *image;
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
        Class animatedImageClass = context[SDWebImageContextAnimatedImageClass];
        // check whether we should use `TXAnimatedImage`
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
