/*
 * This file is part of the SDWebImage package.
 * (c) Olivier Poitrey <rs@dailymotion.com>
 *
 * For the full copyright and license information, please view the LICENSE
 * file that was distributed with this source code.
 */

#import "TXImageTransformer.h"
#import "UIColor+SDHexString.h"
#if SD_UIKIT || SD_MAC
#import <CoreImage/CoreImage.h>
#endif

// Separator for different transformerKey, for example, `image.png` |> flip(YES,NO) |> rotate(pi/4,YES) => 'image-TXImageFlippingTransformer(1,0)-TXImageRotationTransformer(0.78539816339,1).png'
static NSString * const TXImageTransformerKeySeparator = @"-";

NSString * _Nullable TXTransformedKeyForKey(NSString * _Nullable key, NSString * _Nonnull transformerKey) {
    if (!key || !transformerKey) {
        return nil;
    }
    // Find the file extension
    NSURL *keyURL = [NSURL URLWithString:key];
    NSString *ext = keyURL ? keyURL.pathExtension : key.pathExtension;
    if (ext.length > 0) {
        // For non-file URL
        if (keyURL && !keyURL.isFileURL) {
            // keep anything except path (like URL query)
            NSURLComponents *component = [NSURLComponents componentsWithURL:keyURL resolvingAgainstBaseURL:NO];
            component.path = [[[component.path.stringByDeletingPathExtension stringByAppendingString:TXImageTransformerKeySeparator] stringByAppendingString:transformerKey] stringByAppendingPathExtension:ext];
            return component.URL.absoluteString;
        } else {
            // file URL
            return [[[key.stringByDeletingPathExtension stringByAppendingString:TXImageTransformerKeySeparator] stringByAppendingString:transformerKey] stringByAppendingPathExtension:ext];
        }
    } else {
        return [[key stringByAppendingString:TXImageTransformerKeySeparator] stringByAppendingString:transformerKey];
    }
}

NSString * _Nullable TXThumbnailedKeyForKey(NSString * _Nullable key, CGSize thumbnailPixelSize, BOOL preserveAspectRatio) {
    NSString *thumbnailKey = [NSString stringWithFormat:@"Thumbnail({%f,%f},%d)", thumbnailPixelSize.width, thumbnailPixelSize.height, preserveAspectRatio];
    return TXTransformedKeyForKey(key, thumbnailKey);
}

@interface TXImagePipelineTransformer ()

@property (nonatomic, copy, readwrite, nonnull) NSArray<id<TXImageTransformer>> *transformers;
@property (nonatomic, copy, readwrite) NSString *transformerKey;

@end

@implementation TXImagePipelineTransformer

+ (instancetype)transformerWithTransformers:(NSArray<id<TXImageTransformer>> *)transformers {
    TXImagePipelineTransformer *transformer = [TXImagePipelineTransformer new];
    transformer.transformers = transformers;
    transformer.transformerKey = [[self class] cacheKeyForTransformers:transformers];
    
    return transformer;
}

+ (NSString *)cacheKeyForTransformers:(NSArray<id<TXImageTransformer>> *)transformers {
    if (transformers.count == 0) {
        return @"";
    }
    NSMutableArray<NSString *> *cacheKeys = [NSMutableArray arrayWithCapacity:transformers.count];
    [transformers enumerateObjectsUsingBlock:^(id<TXImageTransformer>  _Nonnull transformer, NSUInteger idx, BOOL * _Nonnull stop) {
        NSString *cacheKey = transformer.transformerKey;
        [cacheKeys addObject:cacheKey];
    }];
    
    return [cacheKeys componentsJoinedByString:TXImageTransformerKeySeparator];
}

- (UIImage *)transformedImageWithImage:(UIImage *)image forKey:(NSString *)key {
    if (!image) {
        return nil;
    }
    UIImage *transformedImage = image;
    for (id<TXImageTransformer> transformer in self.transformers) {
        transformedImage = [transformer transformedImageWithImage:transformedImage forKey:key];
    }
    return transformedImage;
}

@end

@interface TXImageRoundCornerTransformer ()

@property (nonatomic, assign) CGFloat cornerRadius;
@property (nonatomic, assign) SDRectCorner corners;
@property (nonatomic, assign) CGFloat borderWidth;
@property (nonatomic, strong, nullable) UIColor *borderColor;

@end

@implementation TXImageRoundCornerTransformer

+ (instancetype)transformerWithRadius:(CGFloat)cornerRadius corners:(SDRectCorner)corners borderWidth:(CGFloat)borderWidth borderColor:(UIColor *)borderColor {
    TXImageRoundCornerTransformer *transformer = [TXImageRoundCornerTransformer new];
    transformer.cornerRadius = cornerRadius;
    transformer.corners = corners;
    transformer.borderWidth = borderWidth;
    transformer.borderColor = borderColor;
    
    return transformer;
}

- (NSString *)transformerKey {
    return [NSString stringWithFormat:@"TXImageRoundCornerTransformer(%f,%lu,%f,%@)", self.cornerRadius, (unsigned long)self.corners, self.borderWidth, self.borderColor.sd_hexString];
}

- (UIImage *)transformedImageWithImage:(UIImage *)image forKey:(NSString *)key {
    if (!image) {
        return nil;
    }
    return [image sd_roundedCornerImageWithRadius:self.cornerRadius corners:self.corners borderWidth:self.borderWidth borderColor:self.borderColor];
}

@end

@interface TXImageResizingTransformer ()

@property (nonatomic, assign) CGSize size;
@property (nonatomic, assign) SDImageScaleMode scaleMode;

@end

@implementation TXImageResizingTransformer

+ (instancetype)transformerWithSize:(CGSize)size scaleMode:(SDImageScaleMode)scaleMode {
    TXImageResizingTransformer *transformer = [TXImageResizingTransformer new];
    transformer.size = size;
    transformer.scaleMode = scaleMode;
    
    return transformer;
}

- (NSString *)transformerKey {
    CGSize size = self.size;
    return [NSString stringWithFormat:@"TXImageResizingTransformer({%f,%f},%lu)", size.width, size.height, (unsigned long)self.scaleMode];
}

- (UIImage *)transformedImageWithImage:(UIImage *)image forKey:(NSString *)key {
    if (!image) {
        return nil;
    }
    return [image sd_resizedImageWithSize:self.size scaleMode:self.scaleMode];
}

@end

@interface TXImageCroppingTransformer ()

@property (nonatomic, assign) CGRect rect;

@end

@implementation TXImageCroppingTransformer

+ (instancetype)transformerWithRect:(CGRect)rect {
    TXImageCroppingTransformer *transformer = [TXImageCroppingTransformer new];
    transformer.rect = rect;
    
    return transformer;
}

- (NSString *)transformerKey {
    CGRect rect = self.rect;
    return [NSString stringWithFormat:@"TXImageCroppingTransformer({%f,%f,%f,%f})", rect.origin.x, rect.origin.y, rect.size.width, rect.size.height];
}

- (UIImage *)transformedImageWithImage:(UIImage *)image forKey:(NSString *)key {
    if (!image) {
        return nil;
    }
    return [image sd_croppedImageWithRect:self.rect];
}

@end

@interface TXImageFlippingTransformer ()

@property (nonatomic, assign) BOOL horizontal;
@property (nonatomic, assign) BOOL vertical;

@end

@implementation TXImageFlippingTransformer

+ (instancetype)transformerWithHorizontal:(BOOL)horizontal vertical:(BOOL)vertical {
    TXImageFlippingTransformer *transformer = [TXImageFlippingTransformer new];
    transformer.horizontal = horizontal;
    transformer.vertical = vertical;
    
    return transformer;
}

- (NSString *)transformerKey {
    return [NSString stringWithFormat:@"TXImageFlippingTransformer(%d,%d)", self.horizontal, self.vertical];
}

- (UIImage *)transformedImageWithImage:(UIImage *)image forKey:(NSString *)key {
    if (!image) {
        return nil;
    }
    return [image sd_flippedImageWithHorizontal:self.horizontal vertical:self.vertical];
}

@end

@interface TXImageRotationTransformer ()

@property (nonatomic, assign) CGFloat angle;
@property (nonatomic, assign) BOOL fitSize;

@end

@implementation TXImageRotationTransformer

+ (instancetype)transformerWithAngle:(CGFloat)angle fitSize:(BOOL)fitSize {
    TXImageRotationTransformer *transformer = [TXImageRotationTransformer new];
    transformer.angle = angle;
    transformer.fitSize = fitSize;
    
    return transformer;
}

- (NSString *)transformerKey {
    return [NSString stringWithFormat:@"TXImageRotationTransformer(%f,%d)", self.angle, self.fitSize];
}

- (UIImage *)transformedImageWithImage:(UIImage *)image forKey:(NSString *)key {
    if (!image) {
        return nil;
    }
    return [image sd_rotatedImageWithAngle:self.angle fitSize:self.fitSize];
}

@end

#pragma mark - Image Blending

@interface TXImageTintTransformer ()

@property (nonatomic, strong, nonnull) UIColor *tintColor;

@end

@implementation TXImageTintTransformer

+ (instancetype)transformerWithColor:(UIColor *)tintColor {
    TXImageTintTransformer *transformer = [TXImageTintTransformer new];
    transformer.tintColor = tintColor;
    
    return transformer;
}

- (NSString *)transformerKey {
    return [NSString stringWithFormat:@"TXImageTintTransformer(%@)", self.tintColor.sd_hexString];
}

- (UIImage *)transformedImageWithImage:(UIImage *)image forKey:(NSString *)key {
    if (!image) {
        return nil;
    }
    return [image sd_tintedImageWithColor:self.tintColor];
}

@end

#pragma mark - Image Effect

@interface TXImageBlurTransformer ()

@property (nonatomic, assign) CGFloat blurRadius;

@end

@implementation TXImageBlurTransformer

+ (instancetype)transformerWithRadius:(CGFloat)blurRadius {
    TXImageBlurTransformer *transformer = [TXImageBlurTransformer new];
    transformer.blurRadius = blurRadius;
    
    return transformer;
}

- (NSString *)transformerKey {
    return [NSString stringWithFormat:@"TXImageBlurTransformer(%f)", self.blurRadius];
}

- (UIImage *)transformedImageWithImage:(UIImage *)image forKey:(NSString *)key {
    if (!image) {
        return nil;
    }
    return [image sd_blurredImageWithRadius:self.blurRadius];
}

@end

#if SD_UIKIT || SD_MAC
@interface TXImageFilterTransformer ()

@property (nonatomic, strong, nonnull) CIFilter *filter;

@end

@implementation TXImageFilterTransformer

+ (instancetype)transformerWithFilter:(CIFilter *)filter {
    TXImageFilterTransformer *transformer = [TXImageFilterTransformer new];
    transformer.filter = filter;
    
    return transformer;
}

- (NSString *)transformerKey {
    return [NSString stringWithFormat:@"TXImageFilterTransformer(%@)", self.filter.name];
}

- (UIImage *)transformedImageWithImage:(UIImage *)image forKey:(NSString *)key {
    if (!image) {
        return nil;
    }
    return [image sd_filteredImageWithFilter:self.filter];
}

@end
#endif
