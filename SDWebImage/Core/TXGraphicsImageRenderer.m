/*
* This file is part of the SDWebImage package.
* (c) Olivier Poitrey <rs@dailymotion.com>
*
* For the full copyright and license information, please view the LICENSE
* file that was distributed with this source code.
*/

#import "TXGraphicsImageRenderer.h"
#import "TXImageGraphics.h"

@interface TXGraphicsImageRendererFormat ()
#if SD_UIKIT
@property (nonatomic, strong) UIGraphicsImageRendererFormat *uiformat API_AVAILABLE(ios(10.0), tvos(10.0));
#endif
@end

@implementation TXGraphicsImageRendererFormat
@synthesize scale = _scale;
@synthesize opaque = _opaque;
@synthesize preferredRange = _preferredRange;

#pragma mark - Property
- (CGFloat)scale {
#if SD_UIKIT
    if (@available(iOS 10.0, tvOS 10.10, *)) {
        return self.uiformat.scale;
    } else {
        return _scale;
    }
#else
    return _scale;
#endif
}

- (void)setScale:(CGFloat)scale {
#if SD_UIKIT
    if (@available(iOS 10.0, tvOS 10.10, *)) {
        self.uiformat.scale = scale;
    } else {
        _scale = scale;
    }
#else
    _scale = scale;
#endif
}

- (BOOL)opaque {
#if SD_UIKIT
    if (@available(iOS 10.0, tvOS 10.10, *)) {
        return self.uiformat.opaque;
    } else {
        return _opaque;
    }
#else
    return _opaque;
#endif
}

- (void)setOpaque:(BOOL)opaque {
#if SD_UIKIT
    if (@available(iOS 10.0, tvOS 10.10, *)) {
        self.uiformat.opaque = opaque;
    } else {
        _opaque = opaque;
    }
#else
    _opaque = opaque;
#endif
}

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
- (TXGraphicsImageRendererFormatRange)preferredRange {
#if SD_UIKIT
    if (@available(iOS 10.0, tvOS 10.10, *)) {
        if (@available(iOS 12.0, tvOS 12.0, *)) {
            return (TXGraphicsImageRendererFormatRange)self.uiformat.preferredRange;
        } else {
            BOOL prefersExtendedRange = self.uiformat.prefersExtendedRange;
            if (prefersExtendedRange) {
                return TXGraphicsImageRendererFormatRangeExtended;
            } else {
                return TXGraphicsImageRendererFormatRangeStandard;
            }
        }
    } else {
        return _preferredRange;
    }
#else
    return _preferredRange;
#endif
}

- (void)setPreferredRange:(TXGraphicsImageRendererFormatRange)preferredRange {
#if SD_UIKIT
    if (@available(iOS 10.0, tvOS 10.10, *)) {
        if (@available(iOS 12.0, tvOS 12.0, *)) {
            self.uiformat.preferredRange = (UIGraphicsImageRendererFormatRange)preferredRange;
        } else {
            switch (preferredRange) {
                case TXGraphicsImageRendererFormatRangeExtended:
                    self.uiformat.prefersExtendedRange = YES;
                    break;
                case TXGraphicsImageRendererFormatRangeStandard:
                    self.uiformat.prefersExtendedRange = NO;
                default:
                    // Automatic means default
                    break;
            }
        }
    } else {
        _preferredRange = preferredRange;
    }
#else
    _preferredRange = preferredRange;
#endif
}
#pragma clang diagnostic pop

- (instancetype)init {
    self = [super init];
    if (self) {
#if SD_UIKIT
        if (@available(iOS 10.0, tvOS 10.10, *)) {
            UIGraphicsImageRendererFormat *uiformat = [[UIGraphicsImageRendererFormat alloc] init];
            self.uiformat = uiformat;
        } else {
#endif
#if SD_WATCH
            CGFloat screenScale = [WKInterfaceDevice currentDevice].screenScale;
#elif SD_UIKIT
            CGFloat screenScale = [UIScreen mainScreen].scale;
#elif SD_MAC
            NSScreen *mainScreen = nil;
            if (@available(macOS 10.12, *)) {
                mainScreen = [NSScreen mainScreen];
            } else {
                mainScreen = [NSScreen screens].firstObject;
            }
            CGFloat screenScale = mainScreen.backingScaleFactor ?: 1.0f;
#endif
            self.scale = screenScale;
            self.opaque = NO;
            self.preferredRange = TXGraphicsImageRendererFormatRangeStandard;
#if SD_UIKIT
        }
#endif
    }
    return self;
}

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wunguarded-availability"
- (instancetype)initForMainScreen {
    self = [super init];
    if (self) {
#if SD_UIKIT
        if (@available(iOS 10.0, tvOS 10.0, *)) {
            UIGraphicsImageRendererFormat *uiformat;
            // iOS 11.0.0 GM does have `preferredFormat`, but iOS 11 betas did not (argh!)
            if ([UIGraphicsImageRenderer respondsToSelector:@selector(preferredFormat)]) {
                uiformat = [UIGraphicsImageRendererFormat preferredFormat];
            } else {
                uiformat = [UIGraphicsImageRendererFormat defaultFormat];
            }
            self.uiformat = uiformat;
        } else {
#endif
#if SD_WATCH
            CGFloat screenScale = [WKInterfaceDevice currentDevice].screenScale;
#elif SD_UIKIT
            CGFloat screenScale = [UIScreen mainScreen].scale;
#elif SD_MAC
            NSScreen *mainScreen = nil;
            if (@available(macOS 10.12, *)) {
                mainScreen = [NSScreen mainScreen];
            } else {
                mainScreen = [NSScreen screens].firstObject;
            }
            CGFloat screenScale = mainScreen.backingScaleFactor ?: 1.0f;
#endif
            self.scale = screenScale;
            self.opaque = NO;
            self.preferredRange = TXGraphicsImageRendererFormatRangeStandard;
#if SD_UIKIT
        }
#endif
    }
    return self;
}
#pragma clang diagnostic pop

+ (instancetype)preferredFormat {
    TXGraphicsImageRendererFormat *format = [[TXGraphicsImageRendererFormat alloc] initForMainScreen];
    return format;
}

@end

@interface TXGraphicsImageRenderer ()
@property (nonatomic, assign) CGSize size;
@property (nonatomic, strong) TXGraphicsImageRendererFormat *format;
#if SD_UIKIT
@property (nonatomic, strong) UIGraphicsImageRenderer *uirenderer API_AVAILABLE(ios(10.0), tvos(10.0));
#endif
@end

@implementation TXGraphicsImageRenderer

- (instancetype)initWithSize:(CGSize)size {
    return [self initWithSize:size format:TXGraphicsImageRendererFormat.preferredFormat];
}

- (instancetype)initWithSize:(CGSize)size format:(TXGraphicsImageRendererFormat *)format {
    NSParameterAssert(format);
    self = [super init];
    if (self) {
        self.size = size;
        self.format = format;
#if SD_UIKIT
        if (@available(iOS 10.0, tvOS 10.0, *)) {
            UIGraphicsImageRendererFormat *uiformat = format.uiformat;
            self.uirenderer = [[UIGraphicsImageRenderer alloc] initWithSize:size format:uiformat];
        }
#endif
    }
    return self;
}

- (UIImage *)imageWithActions:(NS_NOESCAPE SDGraphicsImageDrawingActions)actions {
    NSParameterAssert(actions);
#if SD_UIKIT
    if (@available(iOS 10.0, tvOS 10.0, *)) {
        UIGraphicsImageDrawingActions uiactions = ^(UIGraphicsImageRendererContext *rendererContext) {
            if (actions) {
                actions(rendererContext.CGContext);
            }
        };
        return [self.uirenderer imageWithActions:uiactions];
    } else {
#endif
        SDGraphicsBeginImageContextWithOptions(self.size, self.format.opaque, self.format.scale);
        CGContextRef context = SDGraphicsGetCurrentContext();
        if (actions) {
            actions(context);
        }
        UIImage *image = SDGraphicsGetImageFromCurrentImageContext();
        SDGraphicsEndImageContext();
        return image;
#if SD_UIKIT
    }
#endif
}

@end
