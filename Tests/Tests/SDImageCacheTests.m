/*
 * This file is part of the SDWebImage package.
 * (c) Olivier Poitrey <rs@dailymotion.com>
 *
 * For the full copyright and license information, please view the LICENSE
 * file that was distributed with this source code.
 */

#import "SDTestCase.h"
#import "SDWebImageTestCoder.h"
#import "SDMockFileManager.h"
#import "SDWebImageTestCache.h"

static NSString *kTestImageKeyJPEG = @"TestImageKey.jpg";
static NSString *kTestImageKeyPNG = @"TestImageKey.png";

@interface TXImageCacheTests : SDTestCase <NSFileManagerDelegate>

@end

@implementation TXImageCacheTests

- (void)test01SharedImageCache {
    expect([TXImageCache sharedImageCache]).toNot.beNil();
}

- (void)test02Singleton{
    expect([TXImageCache sharedImageCache]).to.equal([TXImageCache sharedImageCache]);
}

- (void)test03ImageCacheCanBeInstantiated {
    TXImageCache *imageCache = [[TXImageCache alloc] init];
    expect(imageCache).toNot.equal([TXImageCache sharedImageCache]);
}

- (void)test04ClearDiskCache{
    XCTestExpectation *expectation = [self expectationWithDescription:@"Clear disk cache"];
    
    [[TXImageCache sharedImageCache] storeImage:[self testJPEGImage] forKey:kTestImageKeyJPEG completion:nil];
    [[TXImageCache sharedImageCache] clearDiskOnCompletion:^{
        expect([[TXImageCache sharedImageCache] imageFromMemoryCacheForKey:kTestImageKeyJPEG]).to.equal([self testJPEGImage]);
        [[TXImageCache sharedImageCache] diskImageExistsWithKey:kTestImageKeyJPEG completion:^(BOOL isInCache) {
            if (!isInCache) {
                [[TXImageCache sharedImageCache] calculateSizeWithCompletionBlock:^(NSUInteger fileCount, NSUInteger totalSize) {
                    expect(fileCount).to.equal(0);
                    [[TXImageCache sharedImageCache] removeImageForKey:kTestImageKeyJPEG withCompletion:^{
                        [expectation fulfill];
                    }];
                }];
            } else {
                XCTFail(@"Image should not be in cache");
            }
        }];
    }];
    [self waitForExpectationsWithCommonTimeout];
}

- (void)test05ClearMemoryCache{
    XCTestExpectation *expectation = [self expectationWithDescription:@"Clear memory cache"];
    
    [[TXImageCache sharedImageCache] storeImage:[self testJPEGImage] forKey:kTestImageKeyJPEG completion:^{
        [[TXImageCache sharedImageCache] clearMemory];
        expect([[TXImageCache sharedImageCache] imageFromMemoryCacheForKey:kTestImageKeyJPEG]).to.beNil;
        [[TXImageCache sharedImageCache] diskImageExistsWithKey:kTestImageKeyJPEG completion:^(BOOL isInCache) {
            if (isInCache) {
                [[TXImageCache sharedImageCache] removeImageForKey:kTestImageKeyJPEG withCompletion:^{
                    [expectation fulfill];
                }];
            } else {
                XCTFail(@"Image should be in cache");
            }
        }];
    }];
    [self waitForExpectationsWithCommonTimeout];
}

// Testing storeImage:forKey:
- (void)test06InsertionOfImage {
    XCTestExpectation *expectation = [self expectationWithDescription:@"storeImage forKey"];
    
    UIImage *image = [self testJPEGImage];
    [[TXImageCache sharedImageCache] storeImage:image forKey:kTestImageKeyJPEG completion:nil];
    expect([[TXImageCache sharedImageCache] imageFromMemoryCacheForKey:kTestImageKeyJPEG]).to.equal(image);
    [[TXImageCache sharedImageCache] diskImageExistsWithKey:kTestImageKeyJPEG completion:^(BOOL isInCache) {
        if (isInCache) {
            [[TXImageCache sharedImageCache] removeImageForKey:kTestImageKeyJPEG withCompletion:^{
                [expectation fulfill];
            }];
        } else {
            XCTFail(@"Image should be in cache");
        }
    }];
    [self waitForExpectationsWithCommonTimeout];
}

// Testing storeImage:forKey:toDisk:YES
- (void)test07InsertionOfImageForcingDiskStorage {
    XCTestExpectation *expectation = [self expectationWithDescription:@"storeImage forKey toDisk=YES"];
    
    UIImage *image = [self testJPEGImage];
    [[TXImageCache sharedImageCache] storeImage:image forKey:kTestImageKeyJPEG toDisk:YES completion:nil];
    expect([[TXImageCache sharedImageCache] imageFromMemoryCacheForKey:kTestImageKeyJPEG]).to.equal(image);
    [[TXImageCache sharedImageCache] diskImageExistsWithKey:kTestImageKeyJPEG completion:^(BOOL isInCache) {
        if (isInCache) {
            [[TXImageCache sharedImageCache] removeImageForKey:kTestImageKeyJPEG withCompletion:^{
                [expectation fulfill];
            }];
        } else {
            XCTFail(@"Image should be in cache");
        }
    }];
    [self waitForExpectationsWithCommonTimeout];
}

// Testing storeImage:forKey:toDisk:NO
- (void)test08InsertionOfImageOnlyInMemory {
    XCTestExpectation *expectation = [self expectationWithDescription:@"storeImage forKey toDisk=NO"];
    UIImage *image = [self testJPEGImage];
    [[TXImageCache sharedImageCache] storeImage:image forKey:kTestImageKeyJPEG toDisk:NO completion:nil];
    
    expect([[TXImageCache sharedImageCache] imageFromMemoryCacheForKey:kTestImageKeyJPEG]).to.equal([self testJPEGImage]);
    [[TXImageCache sharedImageCache] diskImageExistsWithKey:kTestImageKeyJPEG completion:^(BOOL isInCache) {
        if (!isInCache) {
            [expectation fulfill];
        } else {
            XCTFail(@"Image should not be in cache");
        }
    }];
    [[TXImageCache sharedImageCache] storeImageToMemory:image forKey:kTestImageKeyJPEG];
    [[TXImageCache sharedImageCache] clearMemory];
    expect([[TXImageCache sharedImageCache] imageFromMemoryCacheForKey:kTestImageKeyJPEG]).to.beNil();
    [self waitForExpectationsWithCommonTimeout];
}

- (void)test09RetrieveImageThroughNSOperation {
    XCTestExpectation *expectation = [self expectationWithDescription:@"queryCacheOperationForKey"];
    UIImage *imageForTesting = [self testJPEGImage];
    [[TXImageCache sharedImageCache] storeImage:imageForTesting forKey:kTestImageKeyJPEG completion:nil];
    NSOperation *operation = [[TXImageCache sharedImageCache] queryCacheOperationForKey:kTestImageKeyJPEG done:^(UIImage *image, NSData *data, TXImageCacheType cacheType) {
        expect(image).to.equal(imageForTesting);
        [[TXImageCache sharedImageCache] removeImageForKey:kTestImageKeyJPEG withCompletion:^{
            [expectation fulfill];
        }];
    }];
    expect(operation).toNot.beNil;
    [operation start];
    [self waitForExpectationsWithCommonTimeout];
}

- (void)test10RemoveImageForKeyWithCompletion {
    XCTestExpectation *expectation = [self expectationWithDescription:@"removeImageForKey"];
    [[TXImageCache sharedImageCache] storeImage:[self testJPEGImage] forKey:kTestImageKeyJPEG completion:nil];
    [[TXImageCache sharedImageCache] removeImageForKey:kTestImageKeyJPEG withCompletion:^{
        expect([[TXImageCache sharedImageCache] imageFromDiskCacheForKey:kTestImageKeyJPEG]).to.beNil;
        expect([[TXImageCache sharedImageCache] imageFromMemoryCacheForKey:kTestImageKeyJPEG]).to.beNil;
        [expectation fulfill];
    }];
    [self waitForExpectationsWithCommonTimeout];
}

- (void)test11RemoveImageforKeyNotFromDiskWithCompletion{
    XCTestExpectation *expectation = [self expectationWithDescription:@"removeImageForKey fromDisk:NO"];
    [[TXImageCache sharedImageCache] storeImage:[self testJPEGImage] forKey:kTestImageKeyJPEG completion:nil];
    [[TXImageCache sharedImageCache] removeImageForKey:kTestImageKeyJPEG fromDisk:NO withCompletion:^{
        expect([[TXImageCache sharedImageCache] imageFromDiskCacheForKey:kTestImageKeyJPEG]).toNot.beNil;
        expect([[TXImageCache sharedImageCache] imageFromMemoryCacheForKey:kTestImageKeyJPEG]).to.beNil;
        [expectation fulfill];
    }];
    [self waitForExpectationsWithCommonTimeout];
}

- (void)test12RemoveImageforKeyFromDiskWithCompletion{
    XCTestExpectation *expectation = [self expectationWithDescription:@"removeImageForKey fromDisk:YES"];
    [[TXImageCache sharedImageCache] storeImage:[self testJPEGImage] forKey:kTestImageKeyJPEG completion:nil];
    [[TXImageCache sharedImageCache] removeImageForKey:kTestImageKeyJPEG fromDisk:YES withCompletion:^{
        expect([[TXImageCache sharedImageCache] imageFromDiskCacheForKey:kTestImageKeyJPEG]).to.beNil;
        expect([[TXImageCache sharedImageCache] imageFromMemoryCacheForKey:kTestImageKeyJPEG]).to.beNil;
        [expectation fulfill];
    }];
    [self waitForExpectationsWithCommonTimeout];
}

- (void)test13DeleteOldFiles {
    XCTestExpectation *expectation = [self expectationWithDescription:@"deleteOldFiles"];
    [TXImageCache sharedImageCache].config.maxDiskAge = 1; // 1 second to mark all as out-dated
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [[TXImageCache sharedImageCache] deleteOldFilesWithCompletionBlock:^{
            expect(TXImageCache.sharedImageCache.totalDiskCount).equal(0);
            [expectation fulfill];
        }];
    });
    [self waitForExpectationsWithCommonTimeout];
}

- (void)test14QueryCacheFirstFrameOnlyHitMemoryCache {
    NSString *key = kTestGIFURL;
    UIImage *animatedImage = [self testGIFImage];
    [[TXImageCache sharedImageCache] storeImageToMemory:animatedImage forKey:key];
    [[TXImageCache sharedImageCache] queryCacheOperationForKey:key done:^(UIImage * _Nullable image, NSData * _Nullable data, TXImageCacheType cacheType) {
        expect(cacheType).equal(TXImageCacheTypeMemory);
        expect(image.sd_isAnimated).beTruthy();
        expect(image == animatedImage).beTruthy();
    }];
    [[TXImageCache sharedImageCache] queryCacheOperationForKey:key options:TXImageCacheDecodeFirstFrameOnly done:^(UIImage * _Nullable image, NSData * _Nullable data, TXImageCacheType cacheType) {
        expect(cacheType).equal(TXImageCacheTypeMemory);
        expect(image.sd_isAnimated).beFalsy();
        expect(image == animatedImage).beFalsy();
    }];
    [[TXImageCache sharedImageCache] removeImageFromMemoryForKey:kTestGIFURL];
}

- (void)test20InitialCacheSize{
    expect([[TXImageCache sharedImageCache] totalDiskSize]).to.equal(0);
}

- (void)test21InitialDiskCount{
    XCTestExpectation *expectation = [self expectationWithDescription:@"getDiskCount"];
    [[TXImageCache sharedImageCache] storeImage:[self testJPEGImage] forKey:kTestImageKeyJPEG completion:^{
        expect([[TXImageCache sharedImageCache] totalDiskCount]).to.equal(1);
        [[TXImageCache sharedImageCache] removeImageForKey:kTestImageKeyJPEG withCompletion:^{
            [expectation fulfill];
        }];
    }];
    [self waitForExpectationsWithCommonTimeout];
}

- (void)test31CachePathForAnyKey{
    NSString *path = [[TXImageCache sharedImageCache] cachePathForKey:kTestImageKeyJPEG];
    expect(path).toNot.beNil;
}

- (void)test32CachePathForNilKey{
    NSString *path = [[TXImageCache sharedImageCache] cachePathForKey:nil];
    expect(path).to.beNil;
}

- (void)test33CachePathForExistingKey{
    XCTestExpectation *expectation = [self expectationWithDescription:@"cachePathForKey inPath"];
    [[TXImageCache sharedImageCache] storeImage:[self testJPEGImage] forKey:kTestImageKeyJPEG completion:^{
        NSString *path = [[TXImageCache sharedImageCache] cachePathForKey:kTestImageKeyJPEG];
        expect(path).notTo.beNil;
        [[TXImageCache sharedImageCache] removeImageForKey:kTestImageKeyJPEG withCompletion:^{
            [expectation fulfill];
        }];
    }];
    [self waitForExpectationsWithCommonTimeout];
}

- (void)test34CachePathForSimpleKeyWithExtension {
    NSString *cachePath = [[TXImageCache sharedImageCache] cachePathForKey:kTestJPEGURL];
    expect(cachePath).toNot.beNil();
    expect([cachePath pathExtension]).to.equal(@"jpg");
}

- (void)test35CachePathForKeyWithDotButNoExtension {
    NSString *urlString = @"https://maps.googleapis.com/maps/api/staticmap?center=48.8566,2.3522&format=png&maptype=roadmap&scale=2&size=375x200&zoom=15";
    NSString *cachePath = [[TXImageCache sharedImageCache] cachePathForKey:urlString];
    expect(cachePath).toNot.beNil();
    expect([cachePath pathExtension]).to.equal(@"");
}

- (void)test36CachePathForKeyWithURLQueryParams {
    NSString *urlString = @"https://imggen.alicdn.com/3b11cea896a9438329d85abfb07b30a8.jpg?aid=tanx&tid=1166&m=%7B%22img_url%22%3A%22https%3A%2F%2Fgma.alicdn.com%2Fbao%2Fuploaded%2Fi4%2F1695306010722305097%2FTB2S2KjkHtlpuFjSspoXXbcDpXa_%21%210-saturn_solar.jpg_sum.jpg%22%2C%22title%22%3A%22%E6%A4%8D%E7%89%A9%E8%94%B7%E8%96%87%E7%8E%AB%E7%91%B0%E8%8A%B1%22%2C%22promot_name%22%3A%22%22%2C%22itemid%22%3A%22546038044448%22%7D&e=cb88dab197bfaa19804f6ec796ca906dab536b88fe6d4475795c7ee661a7ede1&size=640x246";
    NSString *cachePath = [[TXImageCache sharedImageCache] cachePathForKey:urlString];
    expect(cachePath).toNot.beNil();
    expect([cachePath pathExtension]).to.equal(@"jpg");
}

- (void)test37CachePathForKeyWithTooLongExtension {
    NSString *urlString = @"https://imggen.alicdn.com/3b11cea896a9438329d85abfb07b30a8.jpgasaaaaaaaaaaaaaaaaaaaajjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjaaaaaaaaaaaaaaaaajjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjj";
    NSString *cachePath = [[TXImageCache sharedImageCache] cachePathForKey:urlString];
    expect(cachePath).toNot.beNil();
    expect([cachePath pathExtension]).to.equal(@"");
}

- (void)test40InsertionOfImageData {
    XCTestExpectation *expectation = [self expectationWithDescription:@"Insertion of image data works"];
    
    UIImage *image = [[UIImage alloc] initWithContentsOfFile:[self testJPEGPath]];
    NSData *imageData = [image sd_imageDataAsFormat:SDImageFormatJPEG];
    [[TXImageCache sharedImageCache] storeImageDataToDisk:imageData forKey:kTestImageKeyJPEG];
    
    expect([[TXImageCache sharedImageCache] diskImageDataExistsWithKey:kTestImageKeyJPEG]).beTruthy();
    UIImage *storedImageFromMemory = [[TXImageCache sharedImageCache] imageFromMemoryCacheForKey:kTestImageKeyJPEG];
    expect(storedImageFromMemory).to.equal(nil);
    
    NSString *cachePath = [[TXImageCache sharedImageCache] cachePathForKey:kTestImageKeyJPEG];
    UIImage *cachedImage = [[UIImage alloc] initWithContentsOfFile:cachePath];
    NSData *storedImageData = [cachedImage sd_imageDataAsFormat:SDImageFormatJPEG];
    expect(storedImageData.length).to.beGreaterThan(0);
    expect(cachedImage.size).to.equal(image.size);
    // can't directly compare image and cachedImage because apparently there are some slight differences, even though the image is the same
    
    [[TXImageCache sharedImageCache] diskImageExistsWithKey:kTestImageKeyJPEG completion:^(BOOL isInCache) {
        expect(isInCache).to.equal(YES);
        
        [[TXImageCache sharedImageCache] removeImageForKey:kTestImageKeyJPEG withCompletion:^{
            [expectation fulfill];
        }];
    }];
    
    [self waitForExpectationsWithCommonTimeout];
}

- (void)test41ThatCustomDecoderWorksForImageCache {
    XCTestExpectation *expectation = [self expectationWithDescription:@"Custom decoder for TXImageCache not works"];
    TXImageCache *cache = [[TXImageCache alloc] initWithNamespace:@"TestDecode"];
    SDWebImageTestCoder *testDecoder = [[SDWebImageTestCoder alloc] init];
    [[TXImageCodersManager sharedManager] addCoder:testDecoder];
    NSString * testImagePath = [[NSBundle bundleForClass:[self class]] pathForResource:@"TestImage" ofType:@"png"];
    UIImage *image = [[UIImage alloc] initWithContentsOfFile:testImagePath];
    NSString *key = @"TestPNGImageEncodedToDataAndRetrieveToJPEG";
    
    [cache storeImage:image imageData:nil forKey:key toDisk:YES completion:^{
        [cache clearMemory];
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wundeclared-selector"
        SEL diskImageDataBySearchingAllPathsForKey = @selector(diskImageDataBySearchingAllPathsForKey:);
#pragma clang diagnostic pop
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
        NSData *data = [cache performSelector:diskImageDataBySearchingAllPathsForKey withObject:key];
#pragma clang diagnostic pop
        NSString *str1 = @"TestEncode";
        NSString *str2 = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        if (![str1 isEqualToString:str2]) {
            XCTFail(@"Custom decoder not work for TXImageCache, check -[SDWebImageTestDecoder encodedDataWithImage:format:]");
        }
        
        UIImage *diskCacheImage = [cache imageFromDiskCacheForKey:key];
        
        // Decoded result is JPEG
        NSString * decodedImagePath = [[NSBundle bundleForClass:[self class]] pathForResource:@"TestImage" ofType:@"jpg"];
        UIImage *testJPEGImage = [[UIImage alloc] initWithContentsOfFile:decodedImagePath];
        
        NSData *data1 = [testJPEGImage sd_imageDataAsFormat:SDImageFormatPNG];
        NSData *data2 = [diskCacheImage sd_imageDataAsFormat:SDImageFormatPNG];
        
        if (![data1 isEqualToData:data2]) {
            XCTFail(@"Custom decoder not work for TXImageCache, check -[SDWebImageTestDecoder decodedImageWithData:]");
        }
        
        [[TXImageCodersManager sharedManager] removeCoder:testDecoder];
        
        [[TXImageCache sharedImageCache] removeImageForKey:key withCompletion:^{
            [expectation fulfill];
        }];
    }];
    
    [self waitForExpectationsWithCommonTimeout];
}

- (void)test41StoreImageDataToDiskWithCustomFileManager {
    NSData *imageData = [NSData dataWithContentsOfFile:[self testJPEGPath]];
    NSError *targetError = [NSError errorWithDomain:NSCocoaErrorDomain code:NSFileWriteNoPermissionError userInfo:nil];
    
    SDMockFileManager *fileManager = [[SDMockFileManager alloc] init];
    fileManager.mockSelectors = @{NSStringFromSelector(@selector(createDirectoryAtPath:withIntermediateDirectories:attributes:error:)) : targetError};
    expect(fileManager.lastError).to.beNil();
    
    TXImageCacheConfig *config = [TXImageCacheConfig new];
    config.fileManager = fileManager;
    // This disk cache path creation will be mocked with error.
    TXImageCache *cache = [[TXImageCache alloc] initWithNamespace:@"test" diskCacheDirectory:@"/" config:config];
    [cache storeImageDataToDisk:imageData
                         forKey:kTestImageKeyJPEG];
    expect(fileManager.lastError).equal(targetError);
}

- (void)test41MatchAnimatedImageClassWorks {
    XCTestExpectation *expectation = [self expectationWithDescription:@"MatchAnimatedImageClass option should work"];
    UIImage *image = [[UIImage alloc] initWithContentsOfFile:self.testGIFPath];
    
    NSString *kAnimatedImageKey = @"kAnimatedImageKey";
    
    // Store UIImage into cache
    [[TXImageCache sharedImageCache] storeImageToMemory:image forKey:kAnimatedImageKey];
    
    // `MatchAnimatedImageClass` will cause query failed because class does not match
    [TXImageCache.sharedImageCache queryCacheOperationForKey:kAnimatedImageKey options:TXImageCacheMatchAnimatedImageClass context:@{SDWebImageContextAnimatedImageClass : TXAnimatedImage.class} done:^(UIImage * _Nullable image1, NSData * _Nullable data1, TXImageCacheType cacheType1) {
        expect(image1).beNil();
        // This should query success with UIImage
        [TXImageCache.sharedImageCache queryCacheOperationForKey:kAnimatedImageKey options:0 context:@{SDWebImageContextAnimatedImageClass : TXAnimatedImage.class} done:^(UIImage * _Nullable image2, NSData * _Nullable data2, TXImageCacheType cacheType2) {
            expect(image2).notTo.beNil();
            expect(image2).equal(image);
            
            [expectation fulfill];
        }];
    }];
    
    // Test sync version API `imageFromCacheForKey` as well
    expect([TXImageCache.sharedImageCache imageFromCacheForKey:kAnimatedImageKey options:TXImageCacheMatchAnimatedImageClass context:@{SDWebImageContextAnimatedImageClass : TXAnimatedImage.class}]).beNil();
    expect([TXImageCache.sharedImageCache imageFromCacheForKey:kAnimatedImageKey options:0 context:@{SDWebImageContextAnimatedImageClass : TXAnimatedImage.class}]).notTo.beNil();
    
    [self waitForExpectationsWithCommonTimeout];
}

- (void)test42StoreCacheWithImageAndFormatWithoutImageData {
    XCTestExpectation *expectation1 = [self expectationWithDescription:@"StoreImage UIImage without sd_imageFormat should use PNG for alpha channel"];
    XCTestExpectation *expectation2 = [self expectationWithDescription:@"StoreImage UIImage without sd_imageFormat should use JPEG for non-alpha channel"];
    XCTestExpectation *expectation3 = [self expectationWithDescription:@"StoreImage UIImage/UIAnimatedImage with sd_imageFormat should use that format"];
    XCTestExpectation *expectation4 = [self expectationWithDescription:@"StoreImage TXAnimatedImage should use animatedImageData"];
    XCTestExpectation *expectation5 = [self expectationWithDescription:@"StoreImage UIAnimatedImage without sd_imageFormat should use GIF"];
    
    NSString *kAnimatedImageKey1 = @"kAnimatedImageKey1";
    NSString *kAnimatedImageKey2 = @"kAnimatedImageKey2";
    NSString *kAnimatedImageKey3 = @"kAnimatedImageKey3";
    NSString *kAnimatedImageKey4 = @"kAnimatedImageKey4";
    NSString *kAnimatedImageKey5 = @"kAnimatedImageKey5";
    
    // Case 1: UIImage without `sd_imageFormat` should use PNG for alpha channel
    NSData *pngData = [NSData dataWithContentsOfFile:[self testPNGPath]];
    UIImage *pngImage = [UIImage sd_imageWithData:pngData];
    expect(pngImage.sd_isAnimated).beFalsy();
    expect(pngImage.sd_imageFormat).equal(SDImageFormatPNG);
    // Remove sd_imageFormat
    pngImage.sd_imageFormat = SDImageFormatUndefined;
    // Check alpha channel
    expect([TXImageCoderHelper CGImageContainsAlpha:pngImage.CGImage]).beTruthy();
    
    [TXImageCache.sharedImageCache storeImage:pngImage forKey:kAnimatedImageKey1 toDisk:YES completion:^{
        UIImage *diskImage = [TXImageCache.sharedImageCache imageFromDiskCacheForKey:kAnimatedImageKey1];
        // Should save to PNG
        expect(diskImage.sd_isAnimated).beFalsy();
        expect(diskImage.sd_imageFormat).equal(SDImageFormatPNG);
        [expectation1 fulfill];
    }];
    
    // Case 2: UIImage without `sd_imageFormat` should use JPEG for non-alpha channel
    TXGraphicsImageRendererFormat *format = [TXGraphicsImageRendererFormat preferredFormat];
    format.opaque = YES;
    TXGraphicsImageRenderer *renderer = [[TXGraphicsImageRenderer alloc] initWithSize:pngImage.size format:format];
    // Non-alpha image, also test `TXGraphicsImageRenderer` behavior here :)
    UIImage *nonAlphaImage = [renderer imageWithActions:^(CGContextRef  _Nonnull context) {
        [pngImage drawInRect:CGRectMake(0, 0, pngImage.size.width, pngImage.size.height)];
    }];
    expect(nonAlphaImage).notTo.beNil();
    expect([TXImageCoderHelper CGImageContainsAlpha:nonAlphaImage.CGImage]).beFalsy();
    
    [TXImageCache.sharedImageCache storeImage:nonAlphaImage forKey:kAnimatedImageKey2 toDisk:YES completion:^{
        UIImage *diskImage = [TXImageCache.sharedImageCache imageFromDiskCacheForKey:kAnimatedImageKey2];
        // Should save to JPEG
        expect(diskImage.sd_isAnimated).beFalsy();
        expect(diskImage.sd_imageFormat).equal(SDImageFormatJPEG);
        [expectation2 fulfill];
    }];
    
    NSData *gifData = [NSData dataWithContentsOfFile:[self testGIFPath]];
    UIImage *gifImage = [UIImage sd_imageWithData:gifData]; // UIAnimatedImage
    expect(gifImage.sd_isAnimated).beTruthy();
    expect(gifImage.sd_imageFormat).equal(SDImageFormatGIF);
    
    // Case 3: UIImage with `sd_imageFormat` should use that format
    [TXImageCache.sharedImageCache storeImage:gifImage forKey:kAnimatedImageKey3 toDisk:YES completion:^{
        UIImage *diskImage = [TXImageCache.sharedImageCache imageFromDiskCacheForKey:kAnimatedImageKey3];
        // Should save to GIF
        expect(diskImage.sd_isAnimated).beTruthy();
        expect(diskImage.sd_imageFormat).equal(SDImageFormatGIF);
        [expectation3 fulfill];
    }];
    
    // Case 4: TXAnimatedImage should use `animatedImageData`
    TXAnimatedImage *animatedImage = [TXAnimatedImage imageWithData:gifData];
    expect(animatedImage.animatedImageData).notTo.beNil();
    [TXImageCache.sharedImageCache storeImage:animatedImage forKey:kAnimatedImageKey4 toDisk:YES completion:^{
        NSData *data = [TXImageCache.sharedImageCache diskImageDataForKey:kAnimatedImageKey4];
        // Should save with animatedImageData
        expect(data).equal(animatedImage.animatedImageData);
        [expectation4 fulfill];
    }];
    
    // Case 5: UIAnimatedImage without sd_imageFormat should use GIF not APNG
    NSData *apngData = [NSData dataWithContentsOfFile:[self testAPNGPath]];
    UIImage *apngImage = [UIImage sd_imageWithData:apngData];
    expect(apngImage.sd_isAnimated).beTruthy();
    expect(apngImage.sd_imageFormat).equal(SDImageFormatPNG);
    // Remove sd_imageFormat
    apngImage.sd_imageFormat = SDImageFormatUndefined;
    
    [TXImageCache.sharedImageCache storeImage:apngImage forKey:kAnimatedImageKey5 toDisk:YES completion:^{
        UIImage *diskImage = [TXImageCache.sharedImageCache imageFromDiskCacheForKey:kAnimatedImageKey5];
        // Should save to GIF
        expect(diskImage.sd_isAnimated).beTruthy();
        expect(diskImage.sd_imageFormat).equal(SDImageFormatGIF);
        [expectation5 fulfill];
    }];
    
    [self waitForExpectationsWithCommonTimeout];
}

- (void)test43CustomDefaultCacheDirectory {
    NSArray<NSString *> *paths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
    NSString *testDirectory = [paths.firstObject stringByAppendingPathComponent:@"CustomDefaultCacheDirectory"];
    NSString *defaultDirectory = [paths.firstObject stringByAppendingPathComponent:@"com.hackemist.TXImageCache"];
    NSString *namespace = @"Test";
    
    // Default cache path
    expect(TXImageCache.defaultDiskCacheDirectory).equal(defaultDirectory);
    TXImageCache *cache1 = [[TXImageCache alloc] initWithNamespace:namespace];
    expect(cache1.diskCachePath).equal([defaultDirectory stringByAppendingPathComponent:namespace]);
    // Custom cache path
    TXImageCache.defaultDiskCacheDirectory = testDirectory;
    TXImageCache *cache2 = [[TXImageCache alloc] initWithNamespace:namespace];
    expect(cache2.diskCachePath).equal([testDirectory stringByAppendingPathComponent:namespace]);
    // Check reset
    TXImageCache.defaultDiskCacheDirectory = nil;
    expect(TXImageCache.defaultDiskCacheDirectory).equal(defaultDirectory);
}

#pragma mark - TXMemoryCache & TXDiskCache
- (void)test42CustomMemoryCache {
    TXImageCacheConfig *config = [[TXImageCacheConfig alloc] init];
    config.memoryCacheClass = [SDWebImageTestMemoryCache class];
    NSString *nameSpace = @"SDWebImageTestMemoryCache";
    TXImageCache *cache = [[TXImageCache alloc] initWithNamespace:nameSpace diskCacheDirectory:nil config:config];
    SDWebImageTestMemoryCache *memCache = cache.memoryCache;
    expect([memCache isKindOfClass:[SDWebImageTestMemoryCache class]]).to.beTruthy();
}

- (void)test43CustomDiskCache {
    TXImageCacheConfig *config = [[TXImageCacheConfig alloc] init];
    config.diskCacheClass = [SDWebImageTestDiskCache class];
    NSString *nameSpace = @"SDWebImageTestDiskCache";
    TXImageCache *cache = [[TXImageCache alloc] initWithNamespace:nameSpace diskCacheDirectory:nil config:config];
    SDWebImageTestDiskCache *diskCache = cache.diskCache;
    expect([diskCache isKindOfClass:[SDWebImageTestDiskCache class]]).to.beTruthy();
}

- (void)test44DiskCacheMigrationFromOldVersion {
    TXImageCacheConfig *config = [[TXImageCacheConfig alloc] init];
    NSFileManager *fileManager = [[NSFileManager alloc] init];
    config.fileManager = fileManager;
    
    // Fake to store a.png into old path
    NSString *newDefaultPath = [[[self userCacheDirectory] stringByAppendingPathComponent:@"com.hackemist.TXImageCache"] stringByAppendingPathComponent:@"default"];
    NSString *oldDefaultPath = [[[self userCacheDirectory] stringByAppendingPathComponent:@"default"] stringByAppendingPathComponent:@"com.hackemist.SDWebImageCache.default"];
    [fileManager createDirectoryAtPath:oldDefaultPath withIntermediateDirectories:YES attributes:nil error:nil];
    [fileManager createFileAtPath:[oldDefaultPath stringByAppendingPathComponent:@"a.png"] contents:[NSData dataWithContentsOfFile:[self testPNGPath]] attributes:nil];
    // Call migration
    TXDiskCache *diskCache = [[TXDiskCache alloc] initWithCachePath:newDefaultPath config:config];
    [diskCache moveCacheDirectoryFromPath:oldDefaultPath toPath:newDefaultPath];
    
    // Expect a.png into new path
    BOOL exist = [fileManager fileExistsAtPath:[newDefaultPath stringByAppendingPathComponent:@"a.png"]];
    expect(exist).beTruthy();
}

- (void)test45DiskCacheRemoveExpiredData {
    NSString *cachePath = [[self userCacheDirectory] stringByAppendingPathComponent:@"disk"];
    TXImageCacheConfig *config = TXImageCacheConfig.defaultCacheConfig;
    config.maxDiskAge = 1; // 1 second
    config.maxDiskSize = 10; // 10 KB
    TXDiskCache *diskCache = [[TXDiskCache alloc] initWithCachePath:cachePath config:config];
    [diskCache removeAllData];
    expect(diskCache.totalSize).equal(0);
    expect(diskCache.totalCount).equal(0);
    // 20KB -> maxDiskSize
    NSUInteger length = 20;
    void *bytes = malloc(length);
    NSData *data = [NSData dataWithBytes:bytes length:length];
    free(bytes);
    [diskCache setData:data forKey:@"20KB"];
    expect(diskCache.totalSize).equal(length);
    expect(diskCache.totalCount).equal(1);
    [diskCache removeExpiredData];
    expect(diskCache.totalSize).equal(0);
    expect(diskCache.totalCount).equal(0);
    // 1KB with 5s -> maxDiskAge
    XCTestExpectation *expectation = [self expectationWithDescription:@"TXDiskCache removeExpireData timeout"];
    length = 1;
    bytes = malloc(length);
    data = [NSData dataWithBytes:bytes length:length];
    free(bytes);
    [diskCache setData:data forKey:@"1KB"];
    expect(diskCache.totalSize).equal(length);
    expect(diskCache.totalCount).equal(1);
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [diskCache removeExpiredData];
        expect(diskCache.totalSize).equal(0);
        expect(diskCache.totalCount).equal(0);
        [expectation fulfill];
    });
    [self waitForExpectationsWithTimeout:5 handler:nil];
}

#if SD_UIKIT
- (void)test46MemoryCacheWeakCache {
    TXMemoryCache *memoryCache = [[TXMemoryCache alloc] init];
    memoryCache.config.shouldUseWeakMemoryCache = NO;
    memoryCache.config.maxMemoryCost = 10;
    memoryCache.config.maxMemoryCount = 5;
    expect(memoryCache.countLimit).equal(5);
    expect(memoryCache.totalCostLimit).equal(10);
    // Don't use weak cache
    NSObject *object = [NSObject new];
    [memoryCache setObject:object forKey:@"1"];
    [[NSNotificationCenter defaultCenter] postNotificationName:UIApplicationDidReceiveMemoryWarningNotification object:nil];
    NSObject *cachedObject = [memoryCache objectForKey:@"1"];
    expect(cachedObject).beNil();
    // Use weak cache
    memoryCache.config.shouldUseWeakMemoryCache = YES;
    object = [NSObject new];
    [memoryCache setObject:object forKey:@"1"];
    [[NSNotificationCenter defaultCenter] postNotificationName:UIApplicationDidReceiveMemoryWarningNotification object:nil];
    cachedObject = [memoryCache objectForKey:@"1"];
    expect(object).equal(cachedObject);
}
#endif

- (void)test47DiskCacheExtendedData {
    XCTestExpectation *expectation = [self expectationWithDescription:@"TXImageCache extended data read/write works"];
    UIImage *image = [self testPNGImage];
    NSDictionary *extendedObject = @{@"Test" : @"Object"};
    image.sd_extendedObject = extendedObject;
    [TXImageCache.sharedImageCache removeImageFromMemoryForKey:kTestImageKeyPNG];
    [TXImageCache.sharedImageCache removeImageFromDiskForKey:kTestImageKeyPNG];
    // Write extended data
    [TXImageCache.sharedImageCache storeImage:image forKey:kTestImageKeyPNG completion:^{
        NSData *extendedData = [TXImageCache.sharedImageCache.diskCache extendedDataForKey:kTestImageKeyPNG];
        expect(extendedData).toNot.beNil();
        // Read extended data
        UIImage *newImage = [TXImageCache.sharedImageCache imageFromDiskCacheForKey:kTestImageKeyPNG];
        id newExtendedObject = newImage.sd_extendedObject;
        expect(extendedObject).equal(newExtendedObject);
        // Remove extended data
        [TXImageCache.sharedImageCache.diskCache setExtendedData:nil forKey:kTestImageKeyPNG];
        [expectation fulfill];
    }];
    [self waitForExpectationsWithCommonTimeout];
}

#pragma mark - TXImageCache & TXImageCachesManager
- (void)test49TXImageCacheQueryOp {
    XCTestExpectation *expectation = [self expectationWithDescription:@"TXImageCache query op works"];
    NSData *imageData = [[TXImageCodersManager sharedManager] encodedDataWithImage:[self testJPEGImage] format:SDImageFormatJPEG options:nil];
    [[TXImageCache sharedImageCache] storeImageDataToDisk:imageData forKey:kTestImageKeyJPEG];
    
    [[TXImageCachesManager sharedManager] queryImageForKey:kTestImageKeyJPEG options:0 context:@{SDWebImageContextStoreCacheType : @(TXImageCacheTypeDisk)} cacheType:TXImageCacheTypeAll completion:^(UIImage * _Nullable image, NSData * _Nullable data, TXImageCacheType cacheType) {
        expect(image).notTo.beNil();
        expect([[TXImageCache sharedImageCache] imageFromMemoryCacheForKey:kTestImageKeyJPEG]).beNil();
        [expectation fulfill];
    }];
    [self waitForExpectationsWithCommonTimeout];
}

- (void)test50TXImageCacheQueryOp {
    XCTestExpectation *expectation = [self expectationWithDescription:@"TXImageCache query op works"];
    [[TXImageCache sharedImageCache] storeImage:[self testJPEGImage] forKey:kTestImageKeyJPEG toDisk:NO completion:nil];
    [[TXImageCachesManager sharedManager] queryImageForKey:kTestImageKeyJPEG options:0 context:nil cacheType:TXImageCacheTypeAll completion:^(UIImage * _Nullable image, NSData * _Nullable data, TXImageCacheType cacheType) {
        expect(image).notTo.beNil();
        [expectation fulfill];
    }];
    [self waitForExpectationsWithCommonTimeout];
}

- (void)test51TXImageCacheStoreOp {
    XCTestExpectation *expectation = [self expectationWithDescription:@"TXImageCache store op works"];
    [[TXImageCachesManager sharedManager] storeImage:[self testJPEGImage] imageData:nil forKey:kTestImageKeyJPEG cacheType:TXImageCacheTypeAll completion:^{
        UIImage *image = [[TXImageCache sharedImageCache] imageFromMemoryCacheForKey:kTestImageKeyJPEG];
        expect(image).notTo.beNil();
        [[TXImageCache sharedImageCache] diskImageExistsWithKey:kTestImageKeyJPEG completion:^(BOOL isInCache) {
            expect(isInCache).to.beTruthy();
            [expectation fulfill];
        }];
    }];
    [self waitForExpectationsWithCommonTimeout];
}

- (void)test52TXImageCacheRemoveOp {
    XCTestExpectation *expectation = [self expectationWithDescription:@"TXImageCache remove op works"];
    [[TXImageCachesManager sharedManager] removeImageForKey:kTestImageKeyJPEG cacheType:TXImageCacheTypeDisk completion:^{
        UIImage *memoryImage = [[TXImageCache sharedImageCache] imageFromMemoryCacheForKey:kTestImageKeyJPEG];
        expect(memoryImage).notTo.beNil();
        [[TXImageCache sharedImageCache] diskImageExistsWithKey:kTestImageKeyJPEG completion:^(BOOL isInCache) {
            expect(isInCache).to.beFalsy();
            [expectation fulfill];
        }];
    }];
    [self waitForExpectationsWithCommonTimeout];
}

- (void)test53TXImageCacheContainsOp {
    XCTestExpectation *expectation = [self expectationWithDescription:@"TXImageCache contains op works"];
    [[TXImageCachesManager sharedManager] containsImageForKey:kTestImageKeyJPEG cacheType:TXImageCacheTypeAll completion:^(TXImageCacheType containsCacheType) {
        expect(containsCacheType).equal(TXImageCacheTypeMemory);
        [expectation fulfill];
    }];
    [self waitForExpectationsWithCommonTimeout];
}

- (void)test54TXImageCacheClearOp {
    XCTestExpectation *expectation = [self expectationWithDescription:@"TXImageCache clear op works"];
    [[TXImageCachesManager sharedManager] clearWithCacheType:TXImageCacheTypeAll completion:^{
        UIImage *memoryImage = [[TXImageCache sharedImageCache] imageFromMemoryCacheForKey:kTestImageKeyJPEG];
        expect(memoryImage).to.beNil();
        [[TXImageCache sharedImageCache] diskImageExistsWithKey:kTestImageKeyJPEG completion:^(BOOL isInCache) {
            expect(isInCache).to.beFalsy();
            [expectation fulfill];
        }];
    }];
    [self waitForExpectationsWithCommonTimeout];
}

- (void)test55TXImageCachesManagerOperationPolicySimple {
    TXImageCachesManager *cachesManager = [[TXImageCachesManager alloc] init];
    TXImageCache *cache1 = [[TXImageCache alloc] initWithNamespace:@"cache1"];
    TXImageCache *cache2 = [[TXImageCache alloc] initWithNamespace:@"cache2"];
    cachesManager.caches = @[cache1, cache2];
    
    [[NSFileManager defaultManager] removeItemAtPath:cache1.diskCachePath error:nil];
    [[NSFileManager defaultManager] removeItemAtPath:cache2.diskCachePath error:nil];
    
    // LowestOnly
    cachesManager.queryOperationPolicy = TXImageCachesManagerOperationPolicyLowestOnly;
    cachesManager.storeOperationPolicy = TXImageCachesManagerOperationPolicyLowestOnly;
    cachesManager.removeOperationPolicy = TXImageCachesManagerOperationPolicyLowestOnly;
    cachesManager.containsOperationPolicy = TXImageCachesManagerOperationPolicyLowestOnly;
    cachesManager.clearOperationPolicy = TXImageCachesManagerOperationPolicyLowestOnly;
    [cachesManager queryImageForKey:kTestImageKeyJPEG options:0 context:nil cacheType:TXImageCacheTypeAll completion:^(UIImage * _Nullable image, NSData * _Nullable data, TXImageCacheType cacheType) {
        expect(image).to.beNil();
    }];
    [cachesManager storeImage:[self testJPEGImage] imageData:nil forKey:kTestImageKeyJPEG cacheType:TXImageCacheTypeMemory completion:nil];
    // Check Logic works, cache1 only
    UIImage *memoryImage1 = [cache1 imageFromMemoryCacheForKey:kTestImageKeyJPEG];
    expect(memoryImage1).equal([self testJPEGImage]);
    [cachesManager containsImageForKey:kTestImageKeyJPEG cacheType:TXImageCacheTypeMemory completion:^(TXImageCacheType containsCacheType) {
        expect(containsCacheType).equal(TXImageCacheTypeMemory);
    }];
    [cachesManager removeImageForKey:kTestImageKeyJPEG cacheType:TXImageCacheTypeMemory completion:nil];
    [cachesManager clearWithCacheType:TXImageCacheTypeMemory completion:nil];
    
    // HighestOnly
    cachesManager.queryOperationPolicy = TXImageCachesManagerOperationPolicyHighestOnly;
    cachesManager.storeOperationPolicy = TXImageCachesManagerOperationPolicyHighestOnly;
    cachesManager.removeOperationPolicy = TXImageCachesManagerOperationPolicyHighestOnly;
    cachesManager.containsOperationPolicy = TXImageCachesManagerOperationPolicyHighestOnly;
    cachesManager.clearOperationPolicy = TXImageCachesManagerOperationPolicyHighestOnly;
    [cachesManager queryImageForKey:kTestImageKeyPNG options:0 context:nil cacheType:TXImageCacheTypeAll completion:^(UIImage * _Nullable image, NSData * _Nullable data, TXImageCacheType cacheType) {
        expect(image).to.beNil();
    }];
    [cachesManager storeImage:[self testPNGImage] imageData:nil forKey:kTestImageKeyPNG cacheType:TXImageCacheTypeMemory completion:nil];
    // Check Logic works, cache2 only
    UIImage *memoryImage2 = [cache2 imageFromMemoryCacheForKey:kTestImageKeyPNG];
    expect(memoryImage2).equal([self testPNGImage]);
    [cachesManager containsImageForKey:kTestImageKeyPNG cacheType:TXImageCacheTypeMemory completion:^(TXImageCacheType containsCacheType) {
        expect(containsCacheType).equal(TXImageCacheTypeMemory);
    }];
    [cachesManager removeImageForKey:kTestImageKeyPNG cacheType:TXImageCacheTypeMemory completion:nil];
    [cachesManager clearWithCacheType:TXImageCacheTypeMemory completion:nil];
}

- (void)test56TXImageCachesManagerOperationPolicyConcurrent {
    XCTestExpectation *expectation = [self expectationWithDescription:@"TXImageCachesManager operation cocurrent policy works"];
    TXImageCachesManager *cachesManager = [[TXImageCachesManager alloc] init];
    TXImageCache *cache1 = [[TXImageCache alloc] initWithNamespace:@"cache1"];
    TXImageCache *cache2 = [[TXImageCache alloc] initWithNamespace:@"cache2"];
    cachesManager.caches = @[cache1, cache2];
    
    [[NSFileManager defaultManager] removeItemAtPath:cache1.diskCachePath error:nil];
    [[NSFileManager defaultManager] removeItemAtPath:cache2.diskCachePath error:nil];
    
    NSString *kConcurrentTestImageKey = @"kConcurrentTestImageKey";
    
    // Cocurrent
    // Check all concurrent op
    cachesManager.queryOperationPolicy = TXImageCachesManagerOperationPolicyConcurrent;
    cachesManager.storeOperationPolicy = TXImageCachesManagerOperationPolicyConcurrent;
    cachesManager.removeOperationPolicy = TXImageCachesManagerOperationPolicyConcurrent;
    cachesManager.containsOperationPolicy = TXImageCachesManagerOperationPolicyConcurrent;
    cachesManager.clearOperationPolicy = TXImageCachesManagerOperationPolicyConcurrent;
    [cachesManager queryImageForKey:kConcurrentTestImageKey options:0 context:nil cacheType:TXImageCacheTypeAll completion:nil];
    [cachesManager storeImage:[self testJPEGImage] imageData:nil forKey:kConcurrentTestImageKey cacheType:TXImageCacheTypeMemory completion:nil];
    [cachesManager removeImageForKey:kConcurrentTestImageKey cacheType:TXImageCacheTypeMemory completion:nil];
    [cachesManager clearWithCacheType:TXImageCacheTypeMemory completion:nil];
    
    // Check Logic works, check cache1(memory+JPEG) & cache2(disk+PNG) at the same time. Cache1(memory) is fast and hit.
    [cache1 storeImage:[self testJPEGImage] forKey:kConcurrentTestImageKey toDisk:NO completion:nil];
    [cache2 storeImage:[self testPNGImage] forKey:kConcurrentTestImageKey toDisk:YES completion:^{
        UIImage *memoryImage1 = [cache1 imageFromMemoryCacheForKey:kConcurrentTestImageKey];
        expect(memoryImage1).notTo.beNil();
        [cache2 removeImageFromMemoryForKey:kConcurrentTestImageKey];
        [cachesManager containsImageForKey:kConcurrentTestImageKey cacheType:TXImageCacheTypeAll completion:^(TXImageCacheType containsCacheType) {
            // Cache1 hit
            expect(containsCacheType).equal(TXImageCacheTypeMemory);
            [expectation fulfill];
        }];
    }];
    
    [self waitForExpectationsWithCommonTimeout];
}

- (void)test57TXImageCachesManagerOperationPolicySerial {
    XCTestExpectation *expectation = [self expectationWithDescription:@"TXImageCachesManager operation serial policy works"];
    TXImageCachesManager *cachesManager = [[TXImageCachesManager alloc] init];
    TXImageCache *cache1 = [[TXImageCache alloc] initWithNamespace:@"cache1"];
    TXImageCache *cache2 = [[TXImageCache alloc] initWithNamespace:@"cache2"];
    cachesManager.caches = @[cache1, cache2];
    
    [[NSFileManager defaultManager] removeItemAtPath:cache1.diskCachePath error:nil];
    [[NSFileManager defaultManager] removeItemAtPath:cache2.diskCachePath error:nil];
    
    NSString *kSerialTestImageKey = @"kSerialTestImageKey";
    
    // Serial
    // Check all serial op
    cachesManager.queryOperationPolicy = TXImageCachesManagerOperationPolicySerial;
    cachesManager.storeOperationPolicy = TXImageCachesManagerOperationPolicySerial;
    cachesManager.removeOperationPolicy = TXImageCachesManagerOperationPolicySerial;
    cachesManager.containsOperationPolicy = TXImageCachesManagerOperationPolicySerial;
    cachesManager.clearOperationPolicy = TXImageCachesManagerOperationPolicySerial;
    [cachesManager queryImageForKey:kSerialTestImageKey options:0 context:nil cacheType:TXImageCacheTypeAll completion:nil];
    [cachesManager storeImage:[self testJPEGImage] imageData:nil forKey:kSerialTestImageKey cacheType:TXImageCacheTypeMemory completion:nil];
    [cachesManager removeImageForKey:kSerialTestImageKey cacheType:TXImageCacheTypeMemory completion:nil];
    [cachesManager clearWithCacheType:TXImageCacheTypeMemory completion:nil];
    
    // Check Logic work, from cache2(disk+PNG) -> cache1(memory+JPEG). Cache2(disk) is slow but hit.
    [cache1 storeImage:[self testJPEGImage] forKey:kSerialTestImageKey toDisk:NO completion:nil];
    [cache2 storeImage:[self testPNGImage] forKey:kSerialTestImageKey toDisk:YES completion:^{
        UIImage *memoryImage1 = [cache1 imageFromMemoryCacheForKey:kSerialTestImageKey];
        expect(memoryImage1).notTo.beNil();
        [cache2 removeImageFromMemoryForKey:kSerialTestImageKey];
        [cachesManager containsImageForKey:kSerialTestImageKey cacheType:TXImageCacheTypeAll completion:^(TXImageCacheType containsCacheType) {
            // Cache2 hit
            expect(containsCacheType).equal(TXImageCacheTypeDisk);
            [expectation fulfill];
        }];
    }];
    
    [self waitForExpectationsWithCommonTimeout];
}

- (void)test58CustomImageCache {
    NSString *cachePath = [[self userCacheDirectory] stringByAppendingPathComponent:@"custom"];
    TXImageCacheConfig *config = [[TXImageCacheConfig alloc] init];
    SDWebImageTestCache *cache = [[SDWebImageTestCache alloc] initWithCachePath:cachePath config:config];
    expect(cache.memoryCache).notTo.beNil();
    expect(cache.diskCache).notTo.beNil();
    
    // Clear
    [cache clearWithCacheType:TXImageCacheTypeAll completion:nil];
    // Store
    UIImage *image1 = self.testJPEGImage;
    NSString *key1 = @"testJPEGImage";
    [cache storeImage:image1 imageData:nil forKey:key1 cacheType:TXImageCacheTypeAll completion:nil];
    // Contain
    [cache containsImageForKey:key1 cacheType:TXImageCacheTypeAll completion:^(TXImageCacheType containsCacheType) {
        expect(containsCacheType).equal(TXImageCacheTypeMemory);
    }];
    // Query
    [cache queryImageForKey:key1 options:0 context:nil cacheType:TXImageCacheTypeAll completion:^(UIImage * _Nullable image, NSData * _Nullable data, TXImageCacheType cacheType) {
        expect(image).equal(image1);
        expect(data).beNil();
        expect(cacheType).equal(TXImageCacheTypeMemory);
    }];
    // Remove
    [cache removeImageForKey:key1 cacheType:TXImageCacheTypeAll completion:nil];
    // Contain
    [cache containsImageForKey:key1 cacheType:TXImageCacheTypeAll completion:^(TXImageCacheType containsCacheType) {
        expect(containsCacheType).equal(TXImageCacheTypeNone);
    }];
    // Clear
    [cache clearWithCacheType:TXImageCacheTypeAll completion:nil];
    NSArray<NSString *> *cacheFiles = [cache.diskCache.fileManager contentsOfDirectoryAtPath:cachePath error:nil];
    expect(cacheFiles.count).equal(0);
}

#pragma mark Helper methods

- (UIImage *)testJPEGImage {
    static UIImage *reusableImage = nil;
    if (!reusableImage) {
        reusableImage = [[UIImage alloc] initWithContentsOfFile:[self testJPEGPath]];
    }
    return reusableImage;
}

- (UIImage *)testPNGImage {
    static UIImage *reusableImage = nil;
    if (!reusableImage) {
        reusableImage = [[UIImage alloc] initWithContentsOfFile:[self testPNGPath]];
    }
    return reusableImage;
}

- (UIImage *)testGIFImage {
    static UIImage *reusableImage = nil;
    if (!reusableImage) {
        NSData *data = [NSData dataWithContentsOfFile:[self testGIFPath]];
        reusableImage = [UIImage sd_imageWithData:data];
    }
    return reusableImage;
}

- (UIImage *)testAPNGImage {
    static UIImage *reusableImage = nil;
    if (!reusableImage) {
        NSData *data = [NSData dataWithContentsOfFile:[self testAPNGPath]];
        reusableImage = [UIImage sd_imageWithData:data];
    }
    return reusableImage;
}

- (NSString *)testJPEGPath {
    NSBundle *testBundle = [NSBundle bundleForClass:[self class]];
    return [testBundle pathForResource:@"TestImage" ofType:@"jpg"];
}

- (NSString *)testPNGPath {
    NSBundle *testBundle = [NSBundle bundleForClass:[self class]];
    return [testBundle pathForResource:@"TestImage" ofType:@"png"];
}

- (NSString *)testGIFPath {
    NSBundle *testBundle = [NSBundle bundleForClass:[self class]];
    NSString *testPath = [testBundle pathForResource:@"TestImage" ofType:@"gif"];
    return testPath;
}

- (NSString *)testAPNGPath {
    NSBundle *testBundle = [NSBundle bundleForClass:[self class]];
    NSString *testPath = [testBundle pathForResource:@"TestImageAnimated" ofType:@"apng"];
    return testPath;
}

- (nullable NSString *)userCacheDirectory {
    NSArray<NSString *> *paths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
    return paths.firstObject;
}

@end
