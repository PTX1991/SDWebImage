/*
 * This file is part of the SDWebImage package.
 * (c) Olivier Poitrey <rs@dailymotion.com>
 *
 * For the full copyright and license information, please view the LICENSE
 * file that was distributed with this source code.
 */

#import "SDTestCase.h"
#import "SDWebImageTestTransformer.h"
#import "SDWebImageTestCache.h"
#import "SDWebImageTestLoader.h"

@interface TXWebImageManagerTests : SDTestCase

@end

@implementation TXWebImageManagerTests

- (void)test01ThatSharedManagerIsNotEqualToInitManager {
    TXWebImageManager *manager = [[TXWebImageManager alloc] init];
    expect(manager).toNot.equal([TXWebImageManager sharedManager]);
}

- (void)test02ThatDownloadInvokesCompletionBlockWithCorrectParamsAsync {
    __block XCTestExpectation *expectation = [self expectationWithDescription:@"Image download completes"];

    NSURL *originalImageURL = [NSURL URLWithString:kTestJPEGURL];
    
    [[TXWebImageManager sharedManager] loadImageWithURL:originalImageURL
                                                options:SDWebImageRefreshCached
                                               progress:nil
                                              completed:^(UIImage *image, NSData *data, NSError *error, TXImageCacheType cacheType, BOOL finished, NSURL *imageURL) {
        expect(image).toNot.beNil();
        expect(error).to.beNil();
        expect(originalImageURL).to.equal(imageURL);

        [expectation fulfill];
        expectation = nil;
    }];
    expect([[TXWebImageManager sharedManager] isRunning]).to.equal(YES);

    [self waitForExpectationsWithTimeout:kAsyncTestTimeout * 2 handler:nil];
}

- (void)test03ThatDownloadWithIncorrectURLInvokesCompletionBlockWithAnErrorAsync {
    __block XCTestExpectation *expectation = [self expectationWithDescription:@"Image download completes"];

    NSURL *originalImageURL = [NSURL URLWithString:@"http://static2.dmcdn.net/static/video/656/177/44771656:jpeg_preview_small.png"];
    
    [[TXWebImageManager sharedManager] loadImageWithURL:originalImageURL
                                                options:SDWebImageRefreshCached
                                               progress:nil
                                              completed:^(UIImage *image, NSData *data, NSError *error, TXImageCacheType cacheType, BOOL finished, NSURL *imageURL) {
        expect(image).to.beNil();
        expect(error).toNot.beNil();
        expect(originalImageURL).to.equal(imageURL);
        
        [expectation fulfill];
        expectation = nil;
    }];
    
    [self waitForExpectationsWithCommonTimeout];
}

- (void)test06CancellAll {
    XCTestExpectation *expectation = [self expectationWithDescription:@"Cancel should callback with error"];
    
    // need a bigger image here, that is why we don't use kTestJPEGURL
    // if the image is too small, it will get downloaded before we can cancel :)
    NSURL *url = [NSURL URLWithString:@"https://raw.githubusercontent.com/liyong03/YLGIFImage/master/YLGIFImageDemo/YLGIFImageDemo/joy.gif"];
    [[TXWebImageManager sharedManager] loadImageWithURL:url options:0 progress:nil completed:^(UIImage * _Nullable image, NSData * _Nullable data, NSError * _Nullable error, TXImageCacheType cacheType, BOOL finished, NSURL * _Nullable imageURL) {
        expect(error).notTo.beNil();
        expect(error.code).equal(TXWebImageErrorCancelled);
    }];
    
    [[TXWebImageManager sharedManager] cancelAll];
    
    // doesn't cancel immediately - since it uses dispatch async
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, kMinDelayNanosecond), dispatch_get_main_queue(), ^{
        expect([[TXWebImageManager sharedManager] isRunning]).to.equal(NO);
        [expectation fulfill];
    });
    
    [self waitForExpectationsWithTimeout:kAsyncTestTimeout * 2 handler:nil];
}

- (void)test07ThatLoadImageWithSDWebImageRefreshCachedWorks {
    XCTestExpectation *expectation = [self expectationWithDescription:@"Image download twice with SDWebImageRefresh failed"];
    NSURL *originalImageURL = [NSURL URLWithString:@"http://via.placeholder.com/10x10.png"];
    __block BOOL firstCompletion = NO;
    [[TXWebImageManager sharedManager] loadImageWithURL:originalImageURL options:SDWebImageRefreshCached progress:nil completed:^(UIImage * _Nullable image, NSData * _Nullable data, NSError * _Nullable error, TXImageCacheType cacheType, BOOL finished, NSURL * _Nullable imageURL) {
        expect(image).toNot.beNil();
        expect(error).to.beNil();
        // #1993, load image with SDWebImageRefreshCached twice should not fail if the first time success.
        
        // Because we call completion before remove the operation from queue, so need a dispatch to avoid get the same operation again. Attention this trap.
        // One way to solve this is use another `NSURL instance` because we use `NSURL` as key but not `NSString`. However, this is implementation detail and no guarantee in the future.
        dispatch_async(dispatch_get_main_queue(), ^{
            NSURL *newImageURL = [NSURL URLWithString:@"http://via.placeholder.com/10x10.png"];
            [[TXWebImageManager sharedManager] loadImageWithURL:newImageURL options:SDWebImageRefreshCached progress:nil completed:^(UIImage * _Nullable image2, NSData * _Nullable data2, NSError * _Nullable error2, TXImageCacheType cacheType2, BOOL finished2, NSURL * _Nullable imageURL2) {
                expect(image2).toNot.beNil();
                expect(error2).to.beNil();
                if (!firstCompletion) {
                    firstCompletion = YES;
                    [expectation fulfill];
                }
            }];
        });
    }];
    
    [self waitForExpectationsWithTimeout:kAsyncTestTimeout * 2 handler:nil];
}

- (void)test08ThatImageTransformerWork {
    XCTestExpectation *expectation = [self expectationWithDescription:@"Image transformer work"];
    NSURL *url = [NSURL URLWithString:kTestJPEGURL];
    SDWebImageTestTransformer *transformer = [[SDWebImageTestTransformer alloc] init];
    
    transformer.testImage = [[UIImage alloc] initWithContentsOfFile:[self testJPEGPath]];
    TXWebImageManager *manager = [[TXWebImageManager alloc] initWithCache:[TXImageCache sharedImageCache] loader:[TXWebImageDownloader sharedDownloader]];
    manager.transformer = transformer;
    [[TXImageCache sharedImageCache] removeImageForKey:kTestJPEGURL withCompletion:^{
        [manager loadImageWithURL:url options:SDWebImageTransformAnimatedImage | SDWebImageTransformVectorImage progress:nil completed:^(UIImage * _Nullable image, NSData * _Nullable data, NSError * _Nullable error, TXImageCacheType cacheType, BOOL finished, NSURL * _Nullable imageURL) {
            expect(image).equal(transformer.testImage);
            [expectation fulfill];
        }];
    }];
    
    [self waitForExpectationsWithCommonTimeout];
}

- (void)test09ThatCacheKeyFilterWork {
    XCTestExpectation *expectation = [self expectationWithDescription:@"Cache key filter work"];
    NSURL *url = [NSURL URLWithString:kTestJPEGURL];
    
    NSString *cacheKey = @"kTestJPEGURL";
    TXWebImageCacheKeyFilter *cacheKeyFilter = [TXWebImageCacheKeyFilter cacheKeyFilterWithBlock:^NSString * _Nullable(NSURL * _Nonnull imageURL) {
        if ([url isEqual:imageURL]) {
            return cacheKey;
        } else {
            return url.absoluteString;
        }
    }];
    
    TXWebImageManager *manager = [[TXWebImageManager alloc] initWithCache:[TXImageCache sharedImageCache] loader:[TXWebImageDownloader sharedDownloader]];
    manager.cacheKeyFilter = cacheKeyFilter;
    // Check download and retrieve custom cache key
    [manager loadImageWithURL:url options:0 context:@{SDWebImageContextStoreCacheType : @(TXImageCacheTypeMemory)} progress:nil completed:^(UIImage * _Nullable image, NSData * _Nullable data, NSError * _Nullable error, TXImageCacheType cacheType, BOOL finished, NSURL * _Nullable imageURL) {
        expect(cacheType).equal(TXImageCacheTypeNone);
        
        // Check memory cache exist
        [manager.imageCache containsImageForKey:cacheKey cacheType:TXImageCacheTypeMemory completion:^(TXImageCacheType containsCacheType) {
            expect(containsCacheType).equal(TXImageCacheTypeMemory);
            
            [expectation fulfill];
        }];
    }];
    
    [self waitForExpectationsWithCommonTimeout];
}

- (void)test10ThatCacheSerializerWork {
    XCTestExpectation *expectation = [self expectationWithDescription:@"Cache serializer work"];
    NSURL *url = [NSURL URLWithString:kTestJPEGURL];
    __block NSData *imageData;
    
    TXWebImageCacheSerializer *cacheSerializer = [TXWebImageCacheSerializer cacheSerializerWithBlock:^NSData * _Nullable(UIImage * _Nonnull image, NSData * _Nullable data, NSURL * _Nullable imageURL) {
        imageData = [image sd_imageDataAsFormat:SDImageFormatPNG];
        return imageData;
    }];
    
    TXWebImageManager *manager = [[TXWebImageManager alloc] initWithCache:[TXImageCache sharedImageCache] loader:[TXWebImageDownloader sharedDownloader]];
    manager.cacheSerializer = cacheSerializer;
    // Check download and store custom disk data
    [[TXImageCache sharedImageCache] removeImageForKey:kTestJPEGURL withCompletion:^{
        [manager loadImageWithURL:url options:0 progress:nil completed:^(UIImage * _Nullable image, NSData * _Nullable data, NSError * _Nullable error, TXImageCacheType cacheType, BOOL finished, NSURL * _Nullable imageURL) {
            // Dispatch to let store disk finish
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, kMinDelayNanosecond), dispatch_get_main_queue(), ^{
                NSData *diskImageData = [[TXImageCache sharedImageCache] diskImageDataForKey:kTestJPEGURL];
                expect(diskImageData).equal(imageData); // disk data equal to serializer data
                
                [expectation fulfill];
            });
        }];
    }];
    
    [self waitForExpectationsWithCommonTimeout];
}

- (void)test11ThatOptionsProcessorWork {
    XCTestExpectation *expectation = [self expectationWithDescription:@"Options processor work"];
    __block BOOL optionsProcessorCalled = NO;
    
    TXWebImageManager *manager = [[TXWebImageManager alloc] initWithCache:[TXImageCache sharedImageCache] loader:[TXWebImageDownloader sharedDownloader]];
    manager.optionsProcessor = [TXWebImageOptionsProcessor optionsProcessorWithBlock:^SDWebImageOptionsResult * _Nullable(NSURL * _Nonnull url, SDWebImageOptions options, SDWebImageContext * _Nullable context) {
        if ([url.absoluteString isEqualToString:kTestPNGURL]) {
            optionsProcessorCalled = YES;
            return [[SDWebImageOptionsResult alloc] initWithOptions:0 context:@{SDWebImageContextImageScaleFactor : @(3)}];
        } else {
            return nil;
        }
    }];
    
    NSURL *url = [NSURL URLWithString:kTestPNGURL];
    [[TXImageCache sharedImageCache] removeImageForKey:kTestPNGURL withCompletion:^{
        [manager loadImageWithURL:url options:0 progress:nil completed:^(UIImage * _Nullable image, NSData * _Nullable data, NSError * _Nullable error, TXImageCacheType cacheType, BOOL finished, NSURL * _Nullable imageURL) {
            expect(image.scale).equal(3);
            expect(optionsProcessorCalled).beTruthy();
            
            [expectation fulfill];
        }];
    }];
    
    [self waitForExpectationsWithCommonTimeout];
}

- (void)test12ThatStoreCacheTypeWork {
    XCTestExpectation *expectation = [self expectationWithDescription:@"Image store cache type (including transformer) work"];
    
    // Use a fresh manager && cache to avoid get effected by other test cases
    TXImageCache *cache = [[TXImageCache alloc] initWithNamespace:@"SDWebImageStoreCacheType"];
    [cache clearDiskOnCompletion:nil];
    TXWebImageManager *manager = [[TXWebImageManager alloc] initWithCache:cache loader:TXWebImageDownloader.sharedDownloader];
    SDWebImageTestTransformer *transformer = [[SDWebImageTestTransformer alloc] init];
    transformer.testImage = [[UIImage alloc] initWithContentsOfFile:[self testJPEGPath]];
    manager.transformer = transformer;
    
    // test: original image -> disk only, transformed image -> memory only
    SDWebImageContext *context = @{SDWebImageContextOriginalStoreCacheType : @(TXImageCacheTypeDisk), SDWebImageContextStoreCacheType : @(TXImageCacheTypeMemory)};
    NSURL *url = [NSURL URLWithString:kTestAPNGPURL];
    NSString *originalKey = [manager cacheKeyForURL:url];
    NSString *transformedKey = [manager cacheKeyForURL:url context:context];
    
    [manager loadImageWithURL:url options:SDWebImageTransformAnimatedImage context:context progress:nil completed:^(UIImage * _Nullable image, NSData * _Nullable data, NSError * _Nullable error, TXImageCacheType cacheType, BOOL finished, NSURL * _Nullable imageURL) {
        expect(image).equal(transformer.testImage);
        // the transformed image should not inherite any attribute from original one
        expect(image.sd_imageFormat).equal(SDImageFormatJPEG);
        expect(image.sd_isAnimated).beFalsy();
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 2*kMinDelayNanosecond), dispatch_get_main_queue(), ^{
            // original -> disk only
            UIImage *originalImage = [cache imageFromMemoryCacheForKey:originalKey];
            expect(originalImage).beNil();
            NSData *originalData = [cache diskImageDataForKey:originalKey];
            expect(originalData).notTo.beNil();
            originalImage = [UIImage sd_imageWithData:originalData];
            expect(originalImage).notTo.beNil();
            expect(originalImage.sd_imageFormat).equal(SDImageFormatPNG);
            expect(originalImage.sd_isAnimated).beTruthy();
            // transformed -> memory only
            [manager.imageCache containsImageForKey:transformedKey cacheType:TXImageCacheTypeAll completion:^(TXImageCacheType transformedCacheType) {
                expect(transformedCacheType).equal(TXImageCacheTypeMemory);
                [cache clearDiskOnCompletion:nil];
                [expectation fulfill];
            }];
        });
    }];
    
    [self waitForExpectationsWithCommonTimeout];
}

- (void)test13ThatScaleDownLargeImageUseThumbnailDecoding {
    XCTestExpectation *expectation = [self expectationWithDescription:@"SDWebImageScaleDownLargeImages should translate to thumbnail decoding"];
    NSURL *originalImageURL = [NSURL URLWithString:@"http://via.placeholder.com/3999x3999.png"]; // Max size for this API
    NSUInteger defaultLimitBytes = TXImageCoderHelper.defaultScaleDownLimitBytes;
    TXImageCoderHelper.defaultScaleDownLimitBytes = 1000 * 1000 * 4; // Limit 1000x1000 pixel
    // From v5.5.0, the `SDWebImageScaleDownLargeImages` translate to `SDWebImageContextImageThumbnailPixelSize`, and works for progressive loading
    [TXWebImageManager.sharedManager loadImageWithURL:originalImageURL options:SDWebImageScaleDownLargeImages | SDWebImageProgressiveLoad progress:nil completed:^(UIImage * _Nullable image, NSData * _Nullable data, NSError * _Nullable error, TXImageCacheType cacheType, BOOL finished, NSURL * _Nullable imageURL) {
        expect(image).notTo.beNil();
        expect(image.size).equal(CGSizeMake(1000, 1000));
        if (finished) {
            expect(image.sd_isIncremental).beFalsy();
            [expectation fulfill];
        } else {
            expect(image.sd_isIncremental).beTruthy();
        }
    }];
    
    [self waitForExpectationsWithCommonTimeoutUsingHandler:^(NSError * _Nullable error) {
        TXImageCoderHelper.defaultScaleDownLimitBytes = defaultLimitBytes;
    }];
}

- (void)test13ThatScaleDownLargeImageEXIFOrientationImage {
    XCTestExpectation *expectation = [self expectationWithDescription:@"SDWebImageScaleDownLargeImages works on EXIF orientation image"];
    NSURL *originalImageURL = [NSURL URLWithString:@"https://raw.githubusercontent.com/recurser/exif-orientation-examples/master/Landscape_2.jpg"];
    [TXWebImageManager.sharedManager loadImageWithURL:originalImageURL options:SDWebImageScaleDownLargeImages | SDWebImageAvoidDecodeImage progress:nil completed:^(UIImage * _Nullable image, NSData * _Nullable data, NSError * _Nullable error, TXImageCacheType cacheType, BOOL finished, NSURL * _Nullable imageURL) {
        expect(image).notTo.beNil();
#if SD_UIKIT
        UIImageOrientation orientation = [TXImageCoderHelper imageOrientationFromEXIFOrientation:kCGImagePropertyOrientationUpMirrored];
        expect(image.imageOrientation).equal(orientation);
#endif
        if (finished) {
            expect(image.sd_isIncremental).beFalsy();
            [expectation fulfill];
        } else {
            expect(image.sd_isIncremental).beTruthy();
        }
    }];
    
    [self waitForExpectationsWithCommonTimeout];
}

- (void)test14ThatCustomCacheAndLoaderWorks {
    XCTestExpectation *expectation = [self expectationWithDescription:@"Custom Cache and Loader during manger query"];
    NSURL *url = [NSURL URLWithString:@"http://via.placeholder.com/100x100.png"];
    SDWebImageContext *context = @{
        SDWebImageContextImageCache : SDWebImageTestCache.sharedCache,
        SDWebImageContextImageLoader : SDWebImageTestLoader.sharedLoader
    };
    [SDWebImageTestCache.sharedCache clearWithCacheType:TXImageCacheTypeAll completion:nil];
    [TXWebImageManager.sharedManager loadImageWithURL:url options:SDWebImageWaitStoreCache context:context progress:nil completed:^(UIImage * _Nullable image, NSData * _Nullable data, NSError * _Nullable error, TXImageCacheType cacheType, BOOL finished, NSURL * _Nullable imageURL) {
        expect(image).notTo.beNil();
        expect(image.size.width).equal(100);
        expect(image.size.height).equal(100);
        expect(data).notTo.beNil();
        NSString *cacheKey = [TXWebImageManager.sharedManager cacheKeyForURL:imageURL];
        // Check Disk Cache (SDWebImageWaitStoreCache behavior)
        [SDWebImageTestCache.sharedCache containsImageForKey:cacheKey cacheType:TXImageCacheTypeDisk completion:^(TXImageCacheType containsCacheType) {
            expect(containsCacheType).equal(TXImageCacheTypeDisk);
            [expectation fulfill];
        }];
    }];
    
    [self waitForExpectationsWithCommonTimeout];
}

- (void)test15ThatQueryCacheTypeWork {
    XCTestExpectation *expectation = [self expectationWithDescription:@"Image query cache type works"];
    NSURL *url = [NSURL URLWithString:@"http://via.placeholder.com/101x101.png"];
    NSString *key = [TXWebImageManager.sharedManager cacheKeyForURL:url];
    NSData *testImageData = [NSData dataWithContentsOfFile:[self testJPEGPath]];
    [TXImageCache.sharedImageCache storeImageDataToDisk:testImageData forKey:key];
    
    // Query memory first
    [TXWebImageManager.sharedManager loadImageWithURL:url options:SDWebImageFromCacheOnly context:@{SDWebImageContextQueryCacheType : @(TXImageCacheTypeMemory)} progress:nil completed:^(UIImage * _Nullable image, NSData * _Nullable data, NSError * _Nullable error, TXImageCacheType cacheType, BOOL finished, NSURL * _Nullable imageURL) {
        expect(image).beNil();
        expect(cacheType).equal(TXImageCacheTypeNone);
        // Query disk secondly
        [TXWebImageManager.sharedManager loadImageWithURL:url options:SDWebImageFromCacheOnly context:@{SDWebImageContextQueryCacheType : @(TXImageCacheTypeDisk)} progress:nil completed:^(UIImage * _Nullable image2, NSData * _Nullable data2, NSError * _Nullable error2, TXImageCacheType cacheType2, BOOL finished2, NSURL * _Nullable imageURL2) {
            expect(image2).notTo.beNil();
            expect(cacheType2).equal(TXImageCacheTypeDisk);
            [TXImageCache.sharedImageCache removeImageFromDiskForKey:key];
            [expectation fulfill];
        }];
    }];
    
    [self waitForExpectationsWithCommonTimeout];
}

- (void)test15ThatOriginalQueryCacheTypeWork {
    XCTestExpectation *expectation = [self expectationWithDescription:@"Image original query cache type with transformer works"];
    NSURL *url = [NSURL URLWithString:@"http://via.placeholder.com/102x102.png"];
    SDWebImageTestTransformer *transformer = [[SDWebImageTestTransformer alloc] init];
    transformer.testImage = [[UIImage alloc] initWithContentsOfFile:[self testJPEGPath]];
    NSString *originalKey = [TXWebImageManager.sharedManager cacheKeyForURL:url];
    NSString *transformedKey = [TXWebImageManager.sharedManager cacheKeyForURL:url context:@{SDWebImageContextImageTransformer : transformer}];
    
    [[TXWebImageManager sharedManager] loadImageWithURL:url options:0 context:@{SDWebImageContextImageTransformer : transformer, SDWebImageContextOriginalStoreCacheType : @(TXImageCacheTypeAll)} progress:nil completed:^(UIImage * _Nullable image, NSData * _Nullable data, NSError * _Nullable error, TXImageCacheType cacheType, BOOL finished, NSURL * _Nullable imageURL) {
        // Get the transformed image
        expect(image).equal(transformer.testImage);
        // Now, the original image is stored into memory/disk cache
        UIImage *originalImage = [TXImageCache.sharedImageCache imageFromMemoryCacheForKey:originalKey];
        expect(originalImage.size).equal(CGSizeMake(102, 102));
        // Query again with original cache type, which should not trigger any download
        UIImage *transformedImage = [TXImageCache.sharedImageCache imageFromMemoryCacheForKey:transformedKey];
        expect(image).equal(transformedImage);
        [TXImageCache.sharedImageCache removeImageFromDiskForKey:transformedKey];
        [TXImageCache.sharedImageCache removeImageFromMemoryForKey:transformedKey];
        [TXWebImageManager.sharedManager loadImageWithURL:url options:SDWebImageFromCacheOnly context:@{SDWebImageContextImageTransformer : transformer, SDWebImageContextOriginalQueryCacheType : @(TXImageCacheTypeAll)} progress:nil completed:^(UIImage * _Nullable image2, NSData * _Nullable data2, NSError * _Nullable error2, TXImageCacheType cacheType2, BOOL finished2, NSURL * _Nullable imageURL2) {
            // Get the transformed image
            expect(image2).equal(transformer.testImage);
            [TXImageCache.sharedImageCache removeImageFromMemoryForKey:originalKey];
            [TXImageCache.sharedImageCache removeImageFromDiskForKey:originalKey];
            [expectation fulfill];
        }];
    }];
    
    [self waitForExpectationsWithCommonTimeout];
}

- (void)test16ThatTransformerUseDifferentCacheForOriginalAndTransformedImage {
    XCTestExpectation *expectation = [self expectationWithDescription:@"Image transformer use different cache instance for original image and transformed image works"];
    NSURL *url = [NSURL URLWithString:@"http://via.placeholder.com/103x103.png"];
    SDWebImageTestTransformer *transformer = [[SDWebImageTestTransformer alloc] init];
    transformer.testImage = [[UIImage alloc] initWithContentsOfFile:[self testJPEGPath]];
    NSString *originalKey = [TXWebImageManager.sharedManager cacheKeyForURL:url];
    NSString *transformedKey = [TXWebImageManager.sharedManager cacheKeyForURL:url context:@{SDWebImageContextImageTransformer : transformer}];
    
    TXImageCache *transformerCache = [[TXImageCache alloc] initWithNamespace:@"TransformerCache"];
    TXImageCache *originalCache = [[TXImageCache alloc] initWithNamespace:@"OriginalCache"];
    
    [[TXWebImageManager sharedManager] loadImageWithURL:url options:SDWebImageWaitStoreCache context:
     @{SDWebImageContextImageTransformer : transformer,
       SDWebImageContextOriginalImageCache : originalCache,
       SDWebImageContextImageCache : transformerCache,
       SDWebImageContextOriginalStoreCacheType: @(TXImageCacheTypeMemory),
       SDWebImageContextStoreCacheType: @(TXImageCacheTypeMemory)} progress:nil completed:^(UIImage * _Nullable image, NSData * _Nullable data, NSError * _Nullable error, TXImageCacheType cacheType, BOOL finished, NSURL * _Nullable imageURL) {
        // Get the transformed image
        expect(image).equal(transformer.testImage);
        // Now, the original image is stored into originalCache
        UIImage *originalImage = [originalCache imageFromMemoryCacheForKey:originalKey];
        expect(originalImage.size).equal(CGSizeMake(103, 103));
        expect([transformerCache imageFromMemoryCacheForKey:originalKey]).beNil();
        
        // The transformed image is stored into transformerCache
        UIImage *transformedImage = [transformerCache imageFromMemoryCacheForKey:transformedKey];
        expect(image).equal(transformedImage);
        expect([originalCache imageFromMemoryCacheForKey:transformedKey]).beNil();
        
        [originalCache clearWithCacheType:TXImageCacheTypeAll completion:nil];
        [transformerCache clearWithCacheType:TXImageCacheTypeAll completion:nil];
        
        [expectation fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:kAsyncTestTimeout * 10 handler:nil];
}

- (NSString *)testJPEGPath {
    NSBundle *testBundle = [NSBundle bundleForClass:[self class]];
    return [testBundle pathForResource:@"TestImage" ofType:@"jpg"];
}

@end
