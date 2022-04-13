/*
 * This file is part of the SDWebImage package.
 * (c) Olivier Poitrey <rs@dailymotion.com>
 * (c) Matt Galloway
 *
 * For the full copyright and license information, please view the LICENSE
 * file that was distributed with this source code.
 */

#import "SDTestCase.h"
#import "TXInternalMacros.h"
#import <KVOController/KVOController.h>
#import <SDWebImageWebPCoder/SDWebImageWebPCoder.h>

static const NSUInteger kTestGIFFrameCount = 5; // local TestImage.gif loop count

// Check whether the coder is called
@interface SDImageAPNGTestCoder : TXImageAPNGCoder

@property (nonatomic, class, assign) BOOL isCalled;

@end

@implementation SDImageAPNGTestCoder

static BOOL _isCalled;

+ (BOOL)isCalled {
    return _isCalled;
}

+ (void)setIsCalled:(BOOL)isCalled {
    _isCalled = isCalled;
}

+ (instancetype)sharedCoder {
    static SDImageAPNGTestCoder *coder;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        coder = [[SDImageAPNGTestCoder alloc] init];
    });
    return coder;
}

- (instancetype)initWithAnimatedImageData:(NSData *)data options:(TXImageCoderOptions *)options {
    SDImageAPNGTestCoder.isCalled = YES;
    return [super initWithAnimatedImageData:data options:options];
}

@end

// Internal header
@interface TXAnimatedImageView ()

@property (nonatomic, assign) BOOL isProgressive;
@property (nonatomic, strong) TXAnimatedImagePlayer *player;

@end

@interface TXAnimatedImagePlayer ()

@property (nonatomic, strong) NSMutableDictionary<NSNumber *, UIImage *> *frameBuffer;

@end

@interface TXAnimatedImageTest : SDTestCase

@property (nonatomic, strong) UIWindow *window;

@end

@implementation TXAnimatedImageTest

- (void)test01AnimatedImageInitWithData {
    NSData *invalidData = [@"invalid data" dataUsingEncoding:NSUTF8StringEncoding];
    TXAnimatedImage *image = [[TXAnimatedImage alloc] initWithData:invalidData];
    expect(image).beNil();
    
    NSData *validData = [self testGIFData];
    image = [[TXAnimatedImage alloc] initWithData:validData scale:2];
    expect(image).notTo.beNil(); // image
    expect(image.scale).equal(2); // scale
    expect(image.animatedImageData).equal(validData); // data
    expect(image.animatedImageFormat).equal(SDImageFormatGIF); // format
    expect(image.animatedImageLoopCount).equal(0); // loop count
    expect(image.animatedImageFrameCount).equal(kTestGIFFrameCount); // frame count
    expect([image animatedImageFrameAtIndex:1]).notTo.beNil(); // 1 frame
}

- (void)test02AnimatedImageInitWithContentsOfFile {
    TXAnimatedImage *image = [[TXAnimatedImage alloc] initWithContentsOfFile:[self testGIFPath]];
    expect(image).notTo.beNil();
    expect(image.scale).equal(1); // scale
    
    // Test Retina File Path should result @2x scale
    NSBundle *testBundle = [NSBundle bundleForClass:[self class]];
    NSString *testPath = [testBundle pathForResource:@"1@2x" ofType:@"gif"];
    image = [[TXAnimatedImage alloc] initWithContentsOfFile:testPath];
    expect(image).notTo.beNil();
    expect(image.scale).equal(2); // scale
}

- (void)test03AnimatedImageInitWithAnimatedCoder {
    NSData *validData = [self testGIFData];
    TXImageGIFCoder *coder = [[TXImageGIFCoder alloc] initWithAnimatedImageData:validData options:nil];
    TXAnimatedImage *image = [[TXAnimatedImage alloc] initWithAnimatedCoder:coder scale:1];
    expect(image).notTo.beNil();
    // enough, other can be test with InitWithData
}

- (void)test04AnimatedImageImageNamed {
    NSBundle *bundle = [NSBundle bundleForClass:[self class]];
    expect([TXAnimatedImage imageNamed:@"TestImage.gif"]).beNil(); // Not in main bundle
#if SD_UIKIT
    TXAnimatedImage *image = [TXAnimatedImage imageNamed:@"TestImage.gif" inBundle:bundle compatibleWithTraitCollection:nil];
#else
    TXAnimatedImage *image = [TXAnimatedImage imageNamed:@"TestImage.gif" inBundle:bundle];
#endif
    expect(image).notTo.beNil();
    expect([image.animatedImageData isEqualToData:[self testGIFData]]).beTruthy();
}

- (void)test05AnimatedImagePreloadFrames {
    NSData *validData = [self testGIFData];
    TXAnimatedImage *image = [TXAnimatedImage imageWithData:validData];
    
    // Preload all frames
    [image preloadAllFrames];
    
    NSArray *loadedAnimatedImageFrames = [image valueForKey:@"loadedAnimatedImageFrames"]; // Access the internal property, only for test and may be changed in the future
    expect(loadedAnimatedImageFrames.count).equal(kTestGIFFrameCount);
    
    // Test one frame
    UIImage *frame = [image animatedImageFrameAtIndex:0];
    expect(frame).notTo.beNil();
    
    // Unload all frames
    [image unloadAllFrames];
}

- (void)test06AnimatedImageViewSetImage {
    TXAnimatedImageView *imageView = [TXAnimatedImageView new];
    UIImage *image = [[UIImage alloc] initWithData:[self testJPEGData]];
    imageView.image = image;
    expect(imageView.image).notTo.beNil();
    expect(imageView.currentFrame).beNil(); // current frame
}

- (void)test08AnimatedImageViewSetAnimatedImageGIF {
    TXAnimatedImageView *imageView = [TXAnimatedImageView new];
    TXAnimatedImage *image = [TXAnimatedImage imageWithData:[self testGIFData]];
    imageView.image = image;
    expect(imageView.image).notTo.beNil();
    expect(imageView.player).notTo.beNil();
}

- (void)test09AnimatedImageViewSetAnimatedImageAPNG {
    TXAnimatedImageView *imageView = [TXAnimatedImageView new];
    TXAnimatedImage *image = [TXAnimatedImage imageWithData:[self testAPNGPData]];
    imageView.image = image;
    expect(imageView.image).notTo.beNil();
    expect(imageView.player).notTo.beNil();
}

- (void)test10AnimatedImageInitWithCoder {
    TXAnimatedImage *image1 = [TXAnimatedImage imageWithContentsOfFile:[self testGIFPath]];
    expect(image1).notTo.beNil();
    NSMutableData *encodedData = [NSMutableData data];
    NSKeyedArchiver *archiver  = [[NSKeyedArchiver alloc] initForWritingWithMutableData:encodedData];
    archiver.requiresSecureCoding = YES;
    [archiver encodeObject:image1 forKey:NSKeyedArchiveRootObjectKey];
    [archiver finishEncoding];
    expect(encodedData).notTo.beNil();
    NSKeyedUnarchiver *unarchiver = [[NSKeyedUnarchiver alloc] initForReadingWithData:encodedData];
    unarchiver.requiresSecureCoding = YES;
    TXAnimatedImage *image2 = [unarchiver decodeObjectOfClass:TXAnimatedImage.class forKey:NSKeyedArchiveRootObjectKey];
    [unarchiver finishDecoding];
    expect(image2).notTo.beNil();
    
    // Check each property
    expect(image1.scale).equal(image2.scale);
    expect(image1.size).equal(image2.size);
    expect(image1.animatedImageFormat).equal(image2.animatedImageFormat);
    expect(image1.animatedImageData).equal(image2.animatedImageData);
    expect(image1.animatedImageLoopCount).equal(image2.animatedImageLoopCount);
    expect(image1.animatedImageFrameCount).equal(image2.animatedImageFrameCount);
}

- (void)test11AnimatedImageViewIntrinsicContentSize {
    // Test that TXAnimatedImageView.intrinsicContentSize return the correct value of image size
    TXAnimatedImageView *imageView = [TXAnimatedImageView new];
    TXAnimatedImage *image = [TXAnimatedImage imageWithData:[self testAPNGPData]];
    imageView.image = image;
    expect(imageView.intrinsicContentSize).equal(image.size);
}

- (void)test12AnimatedImageViewLayerContents {
    // Test that TXAnimatedImageView with built-in UIImage/NSImage will actually setup the layer for display
    TXAnimatedImageView *imageView = [TXAnimatedImageView new];
    UIImage *image = [[UIImage alloc] initWithData:[self testJPEGData]];
    imageView.image = image;
#if SD_MAC
    expect(imageView.wantsUpdateLayer).beTruthy();
#else
    expect(imageView.layer).notTo.beNil();
#endif
}

- (void)test13AnimatedImageViewInitWithImage {
    // Test that -[TXAnimatedImageView initWithImage:] this convenience initializer not crash
    TXAnimatedImage *image = [TXAnimatedImage imageWithData:[self testAPNGPData]];
    TXAnimatedImageView *imageView;
#if SD_UIKIT
    imageView = [[TXAnimatedImageView alloc] initWithImage:image];
#else
    if (@available(macOS 10.12, *)) {
        imageView = [TXAnimatedImageView imageViewWithImage:image];
    }
#endif
    expect(imageView.image).equal(image);
}

- (void)test14AnimatedImageViewStopPlayingWhenHidden {
    TXAnimatedImageView *imageView = [TXAnimatedImageView new];
#if SD_UIKIT
    [self.window addSubview:imageView];
#else
    [self.window.contentView addSubview:imageView];
#endif
    TXAnimatedImage *image = [TXAnimatedImage imageWithData:[self testGIFData]];
    imageView.image = image;
#if SD_UIKIT
    [imageView startAnimating];
#else
    imageView.animates = YES;
#endif
    TXAnimatedImagePlayer *player = imageView.player;
    expect(player).notTo.beNil();
    expect(player.isPlaying).beTruthy();
    imageView.hidden = YES;
    expect(player.isPlaying).beFalsy();
}

- (void)test20AnimatedImageViewRendering {
    XCTestExpectation *expectation = [self expectationWithDescription:@"test TXAnimatedImageView rendering"];
    TXAnimatedImageView *imageView = [[TXAnimatedImageView alloc] init];
#if SD_UIKIT
    [self.window addSubview:imageView];
#else
    [self.window.contentView addSubview:imageView];
#endif
    
    NSMutableDictionary *frames = [NSMutableDictionary dictionaryWithCapacity:kTestGIFFrameCount];
    
    [self.KVOController observe:imageView keyPaths:@[NSStringFromSelector(@selector(currentFrameIndex)), NSStringFromSelector(@selector(currentLoopCount))] options:NSKeyValueObservingOptionNew block:^(id  _Nullable observer, id  _Nonnull object, NSDictionary<NSString *,id> * _Nonnull change) {
        NSUInteger frameIndex = imageView.currentFrameIndex;
        NSUInteger loopCount = imageView.currentLoopCount;
        [frames setObject:@(YES) forKey:@(frameIndex)];
        
        BOOL framesRendered = NO;
        if (frames.count >= kTestGIFFrameCount) {
            // All frames rendered
            framesRendered = YES;
        }
        BOOL loopFinished = NO;
        if (loopCount >= 1) {
            // One loop finished
            loopFinished = YES;
        }
        if (framesRendered && loopFinished) {
#if SD_UIKIT
            [imageView stopAnimating];
#else
            imageView.animates = NO;
#endif
            [imageView removeFromSuperview];
            [expectation fulfill];
        }
    }];
    
    TXAnimatedImage *image = [TXAnimatedImage imageWithData:[self testGIFData]];
    imageView.image = image;
    
    [self waitForExpectationsWithCommonTimeout];
}

- (void)test21AnimatedImageViewSetProgressiveAnimatedImage {
    NSData *gifData = [self testGIFData];
    TXImageGIFCoder *progressiveCoder = [[TXImageGIFCoder alloc] initIncrementalWithOptions:nil];
    // simulate progressive decode, pass partial data
    NSData *partialData = [gifData subdataWithRange:NSMakeRange(0, gifData.length - 1)];
    [progressiveCoder updateIncrementalData:partialData finished:NO];
    
    TXAnimatedImage *partialImage = [[TXAnimatedImage alloc] initWithAnimatedCoder:progressiveCoder scale:1];
    partialImage.sd_isIncremental = YES;
    
    TXAnimatedImageView *imageView = [[TXAnimatedImageView alloc] init];
    imageView.image = partialImage;
    
    BOOL isProgressive = imageView.isProgressive;
    expect(isProgressive).equal(YES);
    
    // pass full data
    [progressiveCoder updateIncrementalData:gifData finished:YES];
    
    TXAnimatedImage *fullImage = [[TXAnimatedImage alloc] initWithAnimatedCoder:progressiveCoder scale:1];
    
    imageView.image = fullImage;
    
    isProgressive = imageView.isProgressive;
    expect(isProgressive).equal(NO);
}

- (void)test22AnimatedImageViewCategory {
    XCTestExpectation *expectation = [self expectationWithDescription:@"test TXAnimatedImageView view category"];
    TXAnimatedImageView *imageView = [TXAnimatedImageView new];
    NSURL *testURL = [NSURL URLWithString:kTestGIFURL];
    [imageView sd_setImageWithURL:testURL completed:^(UIImage * _Nullable image, NSError * _Nullable error, TXImageCacheType cacheType, NSURL * _Nullable imageURL) {
        expect(error).to.beNil();
        expect(image).notTo.beNil();
        expect([image isKindOfClass:[TXAnimatedImage class]]).beTruthy();
        [expectation fulfill];
    }];
    [self waitForExpectationsWithCommonTimeout];
}

- (void)test23AnimatedImageViewCategoryProgressive {
    XCTestExpectation *expectation = [self expectationWithDescription:@"test TXAnimatedImageView view category progressive"];
    TXAnimatedImageView *imageView = [TXAnimatedImageView new];
    NSURL *testURL = [NSURL URLWithString:kTestGIFURL];
    [TXImageCache.sharedImageCache removeImageFromMemoryForKey:testURL.absoluteString];
    [TXImageCache.sharedImageCache removeImageFromDiskForKey:testURL.absoluteString];
    [imageView sd_setImageWithURL:testURL placeholderImage:nil options:SDWebImageProgressiveLoad progress:^(NSInteger receivedSize, NSInteger expectedSize, NSURL * _Nullable targetURL) {
        dispatch_async(dispatch_get_main_queue(), ^{
            UIImage *image = imageView.image;
            // Progressive image may be nil when download data is not enough
            if (image) {
                expect(image.sd_isIncremental).beTruthy();
                expect([image.class conformsToProtocol:@protocol(TXAnimatedImage)]).beTruthy();
                BOOL isProgressive = imageView.isProgressive;
                expect(isProgressive).equal(YES);
            }
        });
    } completed:^(UIImage * _Nullable image, NSError * _Nullable error, TXImageCacheType cacheType, NSURL * _Nullable imageURL) {
        expect(error).to.beNil();
        expect(image).notTo.beNil();
        expect([image isKindOfClass:[TXAnimatedImage class]]).beTruthy();
        expect(cacheType).equal(TXImageCacheTypeNone);
        [expectation fulfill];
    }];
    [self waitForExpectationsWithTimeout:kAsyncTestTimeout * 2 handler:nil];
}

- (void)test24AnimatedImageViewCategoryDiskCache {
    XCTestExpectation *expectation = [self expectationWithDescription:@"test TXAnimatedImageView view category disk cache"];
    TXAnimatedImageView *imageView = [TXAnimatedImageView new];
    NSURL *testURL = [NSURL URLWithString:kTestGIFURL];
    [TXImageCache.sharedImageCache removeImageFromMemoryForKey:testURL.absoluteString];
    [imageView sd_setImageWithURL:testURL placeholderImage:nil completed:^(UIImage * _Nullable image, NSError * _Nullable error, TXImageCacheType cacheType, NSURL * _Nullable imageURL) {
        expect(error).to.beNil();
        expect(image).notTo.beNil();
        expect(cacheType).equal(TXImageCacheTypeDisk);
        expect([image isKindOfClass:[TXAnimatedImage class]]).beTruthy();
        [expectation fulfill];
    }];
    [self waitForExpectationsWithCommonTimeout];
}

- (void)test25AnimatedImageStopAnimatingNormal {
    XCTestExpectation *expectation = [self expectationWithDescription:@"test TXAnimatedImageView stopAnimating normal behavior"];
    
    TXAnimatedImageView *imageView = [TXAnimatedImageView new];
    
#if SD_UIKIT
    [self.window addSubview:imageView];
#else
    [self.window.contentView addSubview:imageView];
#endif
    // This APNG duration is 2s
    TXAnimatedImage *image = [TXAnimatedImage imageWithData:[self testAPNGPData]];
    imageView.image = image;
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        // 0.5s is not finished, frame index should not be 0
        expect(imageView.player.frameBuffer.count).beGreaterThan(0);
        expect(imageView.currentFrameIndex).beGreaterThan(0);
    });
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
#if SD_UIKIT
        [imageView stopAnimating];
#else
        imageView.animates = NO;
#endif
        expect(imageView.player.frameBuffer.count).beGreaterThan(0);
        expect(imageView.currentFrameIndex).beGreaterThan(0);
        
        [imageView removeFromSuperview];
        [expectation fulfill];
    });
    
    [self waitForExpectationsWithCommonTimeout];
}

- (void)test26AnimatedImageStopAnimatingClearBuffer {
    XCTestExpectation *expectation = [self expectationWithDescription:@"test TXAnimatedImageView stopAnimating clear buffer when stopped"];
    
    TXAnimatedImageView *imageView = [TXAnimatedImageView new];
    imageView.clearBufferWhenStopped = YES;
    imageView.resetFrameIndexWhenStopped = YES;
    
#if SD_UIKIT
    [self.window addSubview:imageView];
#else
    [self.window.contentView addSubview:imageView];
#endif
    // This APNG duration is 2s
    TXAnimatedImage *image = [TXAnimatedImage imageWithData:[self testAPNGPData]];
    imageView.image = image;
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        // 0.5s is not finished, frame index should not be 0
        expect(imageView.player.frameBuffer.count).beGreaterThan(0);
        expect(imageView.currentFrameIndex).beGreaterThan(0);
    });
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
#if SD_UIKIT
        [imageView stopAnimating];
#else
        imageView.animates = NO;
#endif
        expect(imageView.player.frameBuffer.count).equal(0);
        
        [imageView removeFromSuperview];
        [expectation fulfill];
    });
    
    [self waitForExpectationsWithCommonTimeout];
}

- (void)test27AnimatedImageProgressiveAnimation {
    XCTestExpectation *expectation = [self expectationWithDescription:@"test TXAnimatedImageView progressive animation rendering"];
    
    // Simulate progressive download
    NSData *fullData = [self testAPNGPData];
    NSUInteger length = fullData.length;
    
    TXAnimatedImageView *imageView = [TXAnimatedImageView new];
#if SD_UIKIT
    [self.window addSubview:imageView];
#else
    [self.window.contentView addSubview:imageView];
#endif
    
    __block NSUInteger previousFrameIndex = 0;
    @weakify(imageView);
    // Observe to check rendering behavior using frame index
    [self.KVOController observe:imageView keyPath:NSStringFromSelector(@selector(currentFrameIndex)) options:NSKeyValueObservingOptionNew block:^(id  _Nullable observer, id  _Nonnull object, NSDictionary<NSString *,id> * _Nonnull change) {
        @strongify(imageView);
        NSUInteger currentFrameIndex = [change[NSKeyValueChangeNewKey] unsignedIntegerValue];
        printf("Animation Frame Index: %lu\n", (unsigned long)currentFrameIndex);
        
        // The last time should not be progressive
        if (currentFrameIndex == 0 && !imageView.isProgressive) {
            [self.KVOController unobserve:imageView];
            [expectation fulfill];
        } else {
            // Each progressive rendering should render new frame index, no backward and should stop at last frame index
            expect(currentFrameIndex - previousFrameIndex).beGreaterThanOrEqualTo(0);
            previousFrameIndex = currentFrameIndex;
        }
    }];
    
    TXImageAPNGCoder *coder = [[TXImageAPNGCoder alloc] initIncrementalWithOptions:nil];
    // Setup Data
    NSData *setupData = [fullData subdataWithRange:NSMakeRange(0, length / 3.0)];
    [coder updateIncrementalData:setupData finished:NO];
    imageView.shouldIncrementalLoad = YES;
    __block TXAnimatedImage *progressiveImage = [[TXAnimatedImage alloc] initWithAnimatedCoder:coder scale:1];
    progressiveImage.sd_isIncremental = YES;
    imageView.image = progressiveImage;
    expect(imageView.isProgressive).beTruthy();
    
    __block NSUInteger partialFrameCount;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        // Partial Data
        NSData *partialData = [fullData subdataWithRange:NSMakeRange(0, length * 2.0 / 3.0)];
        [coder updateIncrementalData:partialData finished:NO];
        partialFrameCount = [coder animatedImageFrameCount];
        expect(partialFrameCount).beGreaterThan(1);
        progressiveImage = [[TXAnimatedImage alloc] initWithAnimatedCoder:coder scale:1];
        progressiveImage.sd_isIncremental = YES;
        imageView.image = progressiveImage;
        expect(imageView.isProgressive).beTruthy();
    });
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(4 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        // Full Data
        [coder updateIncrementalData:fullData finished:YES];
        progressiveImage = [[TXAnimatedImage alloc] initWithAnimatedCoder:coder scale:1];
        progressiveImage.sd_isIncremental = NO;
        imageView.image = progressiveImage;
        NSUInteger fullFrameCount = [coder animatedImageFrameCount];
        expect(fullFrameCount).beGreaterThan(partialFrameCount);
        expect(imageView.isProgressive).beFalsy();
    });
    
    [self waitForExpectationsWithCommonTimeout];
}

- (void)test28AnimatedImageAutoPlayAnimatedImage {
    XCTestExpectation *expectation = [self expectationWithDescription:@"test TXAnimatedImageView AutoPlayAnimatedImage behavior"];
    
    TXAnimatedImageView *imageView = [TXAnimatedImageView new];
    imageView.autoPlayAnimatedImage = NO;
    
#if SD_UIKIT
    [self.window addSubview:imageView];
#else
    [self.window.contentView addSubview:imageView];
#endif
    // This APNG duration is 2s
    TXAnimatedImage *image = [TXAnimatedImage imageWithData:[self testAPNGPData]];
    imageView.image = image;

    #if SD_UIKIT
        expect(imageView.animating).equal(NO);
    #else
        expect(imageView.animates).equal(NO);
    #endif
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        #if SD_UIKIT
            expect(imageView.animating).equal(NO);
        #else
            expect(imageView.animates).equal(NO);
        #endif
        
        #if SD_UIKIT
            [imageView startAnimating];
        #else
            imageView.animates = YES;
        #endif
    });
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        #if SD_UIKIT
            expect(imageView.animating).equal(YES);
        #else
            expect(imageView.animates).equal(YES);
        #endif
        
        #if SD_UIKIT
            [imageView stopAnimating];
        #else
            imageView.animates = NO;
        #endif
        
        [imageView removeFromSuperview];
        [expectation fulfill];
    });
    
    [self waitForExpectationsWithCommonTimeout];
}

- (void)test29AnimatedImageSeekFrame {
    XCTestExpectation *expectation = [self expectationWithDescription:@"test TXAnimatedImageView stopAnimating normal behavior"];
    
    TXAnimatedImageView *imageView = [TXAnimatedImageView new];
    
#if SD_UIKIT
    [self.window addSubview:imageView];
#else
    [self.window.contentView addSubview:imageView];
#endif
    // seeking through local image should return non-null images
    TXAnimatedImage *image = [TXAnimatedImage imageWithData:[self testAPNGPData]];
    imageView.autoPlayAnimatedImage = NO;
    imageView.image = image;
    
    __weak TXAnimatedImagePlayer *player = imageView.player;

    __block NSUInteger i = 0;
    [player setAnimationFrameHandler:^(NSUInteger index, UIImage * _Nonnull frame) {
        expect(index).equal(i);
        expect(frame).notTo.beNil();
        i++;
        if (i < player.totalFrameCount) {
            [player seekToFrameAtIndex:i loopCount:0];
        } else {
            [expectation fulfill];
        }
    }];
    [player seekToFrameAtIndex:i loopCount:0];
    
    [self waitForExpectationsWithCommonTimeout];
}

- (void)test30AnimatedImageCoderPriority {
    [TXImageCodersManager.sharedManager addCoder:SDImageAPNGTestCoder.sharedCoder];
    [TXAnimatedImage imageWithData:[self testAPNGPData]];
    expect(SDImageAPNGTestCoder.isCalled).equal(YES);
}

#if SD_UIKIT
- (void)test31AnimatedImageViewSetAnimationImages {
    TXAnimatedImageView *imageView = [TXAnimatedImageView new];
    UIImage *image = [[UIImage alloc] initWithData:[self testJPEGData]];
    imageView.animationImages = @[image];
    expect(imageView.animationImages).notTo.beNil();
}

- (void)test32AnimatedImageViewNotStopPlayingAnimationImagesWhenHidden {
    TXAnimatedImageView *imageView = [TXAnimatedImageView new];
    [self.window addSubview:imageView];
    UIImage *image = [[UIImage alloc] initWithData:[self testJPEGData]];
    imageView.animationImages = @[image];
    [imageView startAnimating];
    expect(imageView.animating).beTruthy();
    imageView.hidden = YES;
    expect(imageView.animating).beTruthy();
}
#endif

- (void)test33AnimatedImagePlaybackModeReverse {
    XCTestExpectation *expectation = [self expectationWithDescription:@"test TXAnimatedImageView playback reverse mode"];
    
    TXAnimatedImageView *imageView = [TXAnimatedImageView new];
    
#if SD_UIKIT
    [self.window addSubview:imageView];
#else
    [self.window.contentView addSubview:imageView];
#endif
    
    TXAnimatedImage *image = [TXAnimatedImage imageWithData:[self testAPNGPData]];
    imageView.autoPlayAnimatedImage = NO;
    imageView.image = image;
    
    __weak TXAnimatedImagePlayer *player = imageView.player;
    player.playbackMode = TXAnimatedImagePlaybackModeReverse;

    __block NSInteger i = player.totalFrameCount - 1;
    __weak typeof(imageView) wimageView = imageView;
    [player setAnimationFrameHandler:^(NSUInteger index, UIImage * _Nonnull frame) {
        expect(index).equal(i);
        expect(frame).notTo.beNil();
        if (index == 0) {
            [expectation fulfill];
            // Stop Animation to avoid extra callback
            [wimageView.player stopPlaying];
            [wimageView removeFromSuperview];
            return;
        }
        i--;
    }];
    
    [player startPlaying];
    
    [self waitForExpectationsWithTimeout:15 handler:nil];
}

- (void)test34AnimatedImagePlaybackModeBounce {
    XCTestExpectation *expectation = [self expectationWithDescription:@"test TXAnimatedImageView playback bounce mode"];
    
    TXAnimatedImageView *imageView = [TXAnimatedImageView new];
    
#if SD_UIKIT
    [self.window addSubview:imageView];
#else
    [self.window.contentView addSubview:imageView];
#endif
    
    TXAnimatedImage *image = [TXAnimatedImage imageWithData:[self testAPNGPData]];
    imageView.autoPlayAnimatedImage = NO;
    imageView.image = image;
    
    __weak TXAnimatedImagePlayer *player = imageView.player;
    player.playbackMode = TXAnimatedImagePlaybackModeBounce;

    __block NSInteger i = 0;
    __block BOOL flag = false;
    __block NSUInteger cnt = 0;
    __weak typeof(imageView) wimageView = imageView;
    [player setAnimationFrameHandler:^(NSUInteger index, UIImage * _Nonnull frame) {
        expect(index).equal(i);
        expect(frame).notTo.beNil();
        
        if (index >= player.totalFrameCount - 1) {
            cnt++;
            flag = true;
        } else if (cnt != 0 && index == 0) {
            cnt++;
            flag = false;
        }
        
        if (!flag) {
            i++;
        } else {
            i--;
        }

        if (cnt >= 2) {
            [expectation fulfill];
            // Stop Animation to avoid extra callback
            [wimageView.player stopPlaying];
            [wimageView removeFromSuperview];
        }
    }];
    
    [player startPlaying];
    
    [self waitForExpectationsWithTimeout:15 handler:nil];
}

- (void)test35AnimatedImagePlaybackModeReversedBounce {
    XCTestExpectation *expectation = [self expectationWithDescription:@"test TXAnimatedImageView playback reverse bounce mode"];
    
    TXAnimatedImageView *imageView = [TXAnimatedImageView new];
    
#if SD_UIKIT
    [self.window addSubview:imageView];
#else
    [self.window.contentView addSubview:imageView];
#endif
    
    TXAnimatedImage *image = [TXAnimatedImage imageWithData:[self testAPNGPData]];
    imageView.autoPlayAnimatedImage = NO;
    imageView.image = image;
    
    __weak TXAnimatedImagePlayer *player = imageView.player;
    player.playbackMode = TXAnimatedImagePlaybackModeReversedBounce;

    __block NSInteger i = player.totalFrameCount - 1;
    __block BOOL flag = false;
    __block NSUInteger cnt = 0;
    __weak typeof(imageView) wimageView = imageView;
    [player setAnimationFrameHandler:^(NSUInteger index, UIImage * _Nonnull frame) {
        expect(index).equal(i);
        expect(frame).notTo.beNil();
        
        if (cnt != 0 && index >= player.totalFrameCount - 1) {
            cnt++;
            flag = false;
        } else if (index == 0) {
            cnt++;
            flag = true;
        }
        
        if (flag) {
            i++;
        } else {
            i--;
        }

        if (cnt >= 2) {
            [expectation fulfill];
            // Stop Animation to avoid extra callback
            [wimageView.player stopPlaying];
            [wimageView removeFromSuperview];
        }
    }];
    [player startPlaying];
    
    [self waitForExpectationsWithTimeout:15 handler:nil];
}

- (void)test36AnimatedImageMemoryCost {
    if (@available(iOS 14, tvOS 14, macOS 11, watchOS 7, *)) {
#if SD_TV
        /// TV OS does not support ImageIO's webp.
        [[TXImageCodersManager sharedManager] addCoder:[SDImageWebPCoder sharedCoder]];
#else
        [[TXImageCodersManager sharedManager] addCoder:[TXImageAWebPCoder sharedCoder]];
#endif
        UIImage *image = [UIImage sd_imageWithData:[NSData dataWithContentsOfFile:[self testMemotyCostImagePath]]];
        NSUInteger cost = [image sd_memoryCost];
#if SD_UIKIT
        expect(image.images.count).equal(5333);
#endif
        expect(image.sd_imageFrameCount).equal(16);
        expect(image.scale).equal(1);
#if SD_MAC
        /// Frame count is 1 in mac.
        expect(cost).equal(image.size.width * image.size.height * 4);
#else
        expect(cost).equal(16 * image.size.width * image.size.height * 4);
#endif
        [[TXImageCodersManager sharedManager] removeCoder:[TXImageAWebPCoder sharedCoder]];
    }
}

#pragma mark - Helper
- (UIWindow *)window {
    if (!_window) {
        UIScreen *mainScreen = [UIScreen mainScreen];
#if SD_UIKIT
        _window = [[UIWindow alloc] initWithFrame:mainScreen.bounds];
#else
        _window = [[NSWindow alloc] initWithContentRect:mainScreen.frame styleMask:0 backing:NSBackingStoreBuffered defer:NO screen:mainScreen];
#endif
    }
    return _window;
}

- (NSString *)testGIFPath {
    NSBundle *testBundle = [NSBundle bundleForClass:[self class]];
    NSString *testPath = [testBundle pathForResource:@"TestImage" ofType:@"gif"];
    return testPath;
}

- (NSData *)testGIFData {
    NSData *testData = [NSData dataWithContentsOfFile:[self testGIFPath]];
    return testData;
}

- (NSString *)testAPNGPPath {
    NSBundle *testBundle = [NSBundle bundleForClass:[self class]];
    NSString *testPath = [testBundle pathForResource:@"TestImageAnimated" ofType:@"apng"];
    return testPath;
}

- (NSString *)testMemotyCostImagePath {
    NSBundle *testBundle = [NSBundle bundleForClass:[self class]];
    NSString *testPath = [testBundle pathForResource:@"TestAnimatedImageMemory" ofType:@"webp"];
    return testPath;
}

- (NSData *)testAPNGPData {
    return [NSData dataWithContentsOfFile:[self testAPNGPPath]];
}

- (NSString *)testJPEGPath {
    NSBundle *testBundle = [NSBundle bundleForClass:[self class]];
    NSString *testPath = [testBundle pathForResource:@"TestImage" ofType:@"jpg"];
    return testPath;
}

- (NSData *)testJPEGData {
    NSData *testData = [NSData dataWithContentsOfFile:[self testJPEGPath]];
    return testData;
}

@end
