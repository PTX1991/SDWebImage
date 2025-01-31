/*
 * This file is part of the SDWebImage package.
 * (c) Olivier Poitrey <rs@dailymotion.com>
 *
 * For the full copyright and license information, please view the LICENSE
 * file that was distributed with this source code.
 */

#import "TXImageGIFCoder.h"
#import "TXImageIOAnimatedCoderInternal.h"
#if SD_MAC
#import <CoreServices/CoreServices.h>
#else
#import <MobileCoreServices/MobileCoreServices.h>
#endif

@implementation TXImageGIFCoder

+ (instancetype)sharedCoder {
    static TXImageGIFCoder *coder;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        coder = [[TXImageGIFCoder alloc] init];
    });
    return coder;
}

#pragma mark - Subclass Override

+ (SDImageFormat)imageFormat {
    return SDImageFormatGIF;
}

+ (NSString *)imageUTType {
    return (__bridge NSString *)kSDUTTypeGIF;
}

+ (NSString *)dictionaryProperty {
    return (__bridge NSString *)kCGImagePropertyGIFDictionary;
}

+ (NSString *)unclampedDelayTimeProperty {
    return (__bridge NSString *)kCGImagePropertyGIFUnclampedDelayTime;
}

+ (NSString *)delayTimeProperty {
    return (__bridge NSString *)kCGImagePropertyGIFDelayTime;
}

+ (NSString *)loopCountProperty {
    return (__bridge NSString *)kCGImagePropertyGIFLoopCount;
}

+ (NSUInteger)defaultLoopCount {
    return 1;
}

@end
