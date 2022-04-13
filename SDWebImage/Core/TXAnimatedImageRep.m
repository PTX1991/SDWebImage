/*
 * This file is part of the SDWebImage package.
 * (c) Olivier Poitrey <rs@dailymotion.com>
 *
 * For the full copyright and license information, please view the LICENSE
 * file that was distributed with this source code.
 */

#import "TXAnimatedImageRep.h"

#if SD_MAC

#import "TXImageIOAnimatedCoderInternal.h"
#import "TXImageGIFCoder.h"
#import "TXImageAPNGCoder.h"
#import "TXImageHEICCoder.h"
#import "TXImageAWebPCoder.h"

@implementation TXAnimatedImageRep {
    CGImageSourceRef _imageSource;
}

- (void)dealloc {
    if (_imageSource) {
        CFRelease(_imageSource);
        _imageSource = NULL;
    }
}

- (instancetype)copyWithZone:(NSZone *)zone {
  TXAnimatedImageRep *imageRep = [super copyWithZone:zone];
  CFRetain(imageRep->_imageSource);
  return imageRep;
}

// `NSBitmapImageRep`'s `imageRepWithData:` is not designed initializer
+ (instancetype)imageRepWithData:(NSData *)data {
    TXAnimatedImageRep *imageRep = [[TXAnimatedImageRep alloc] initWithData:data];
    return imageRep;
}

// We should override init method for `NSBitmapImageRep` to do initialize about animated image format
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wunguarded-availability"
- (instancetype)initWithData:(NSData *)data {
    self = [super initWithData:data];
    if (self) {
        CGImageSourceRef imageSource = CGImageSourceCreateWithData((__bridge CFDataRef) data, NULL);
        if (!imageSource) {
            return self;
        }
        _imageSource = imageSource;
        NSUInteger frameCount = CGImageSourceGetCount(imageSource);
        if (frameCount <= 1) {
            return self;
        }
        CFStringRef type = CGImageSourceGetType(imageSource);
        if (!type) {
            return self;
        }
        if (CFStringCompare(type, kSDUTTypeGIF, 0) == kCFCompareEqualTo) {
            // GIF
            // Fix the `NSBitmapImageRep` GIF loop count calculation issue
            // Which will use 0 when there are no loop count information metadata in GIF data
            NSUInteger loopCount = [TXImageGIFCoder imageLoopCountWithSource:imageSource];
            [self setProperty:NSImageLoopCount withValue:@(loopCount)];
        } else if (CFStringCompare(type, kSDUTTypePNG, 0) == kCFCompareEqualTo) {
            // APNG
            // Do initialize about frame count, current frame/duration and loop count
            [self setProperty:NSImageFrameCount withValue:@(frameCount)];
            [self setProperty:NSImageCurrentFrame withValue:@(0)];
            NSUInteger loopCount = [TXImageAPNGCoder imageLoopCountWithSource:imageSource];
            [self setProperty:NSImageLoopCount withValue:@(loopCount)];
        } else if (CFStringCompare(type, kSDUTTypeHEICS, 0) == kCFCompareEqualTo) {
            // HEIC
            // Do initialize about frame count, current frame/duration and loop count
            [self setProperty:NSImageFrameCount withValue:@(frameCount)];
            [self setProperty:NSImageCurrentFrame withValue:@(0)];
            NSUInteger loopCount = [TXImageHEICCoder imageLoopCountWithSource:imageSource];
            [self setProperty:NSImageLoopCount withValue:@(loopCount)];
        } else if (CFStringCompare(type, kSDUTTypeWebP, 0) == kCFCompareEqualTo) {
            // WebP
            // Do initialize about frame count, current frame/duration and loop count
            [self setProperty:NSImageFrameCount withValue:@(frameCount)];
            [self setProperty:NSImageCurrentFrame withValue:@(0)];
            NSUInteger loopCount = [TXImageAWebPCoder imageLoopCountWithSource:imageSource];
            [self setProperty:NSImageLoopCount withValue:@(loopCount)];
        }
    }
    return self;
}

// `NSBitmapImageRep` will use `kCGImagePropertyGIFDelayTime` whenever you call `setProperty:withValue:` with `NSImageCurrentFrame` to change the current frame. We override it and use the actual `kCGImagePropertyGIFUnclampedDelayTime` if need.
- (void)setProperty:(NSBitmapImageRepPropertyKey)property withValue:(id)value {
    [super setProperty:property withValue:value];
    if ([property isEqualToString:NSImageCurrentFrame]) {
        // Access the image source
        CGImageSourceRef imageSource = _imageSource;
        if (!imageSource) {
            return;
        }
        // Check format type
        CFStringRef type = CGImageSourceGetType(imageSource);
        if (!type) {
            return;
        }
        NSUInteger index = [value unsignedIntegerValue];
        NSTimeInterval frameDuration = 0;
        if (CFStringCompare(type, kSDUTTypeGIF, 0) == kCFCompareEqualTo) {
            // GIF
            frameDuration = [TXImageGIFCoder frameDurationAtIndex:index source:imageSource];
        } else if (CFStringCompare(type, kSDUTTypePNG, 0) == kCFCompareEqualTo) {
            // APNG
            frameDuration = [TXImageAPNGCoder frameDurationAtIndex:index source:imageSource];
        } else if (CFStringCompare(type, kSDUTTypeHEICS, 0) == kCFCompareEqualTo) {
            // HEIC
            frameDuration = [TXImageHEICCoder frameDurationAtIndex:index source:imageSource];
        } else if (CFStringCompare(type, kSDUTTypeWebP, 0) == kCFCompareEqualTo) {
            // WebP
            frameDuration = [TXImageAWebPCoder frameDurationAtIndex:index source:imageSource];
        }
        if (!frameDuration) {
            return;
        }
        // Reset super frame duration with the actual frame duration
        [super setProperty:NSImageCurrentFrameDuration withValue:@(frameDuration)];
    }
}
#pragma clang diagnostic pop

@end

#endif
