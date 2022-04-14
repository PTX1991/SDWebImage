/*
 * This file is part of the SDWebImage package.
 * (c) Olivier Poitrey <rs@dailymotion.com>
 * (c) Matt Galloway
 *
 * For the full copyright and license information, please view the LICENSE
 * file that was distributed with this source code.
 */

#import "SDTestCase.h"
#import "SDWebImageTestDownloadOperation.h"
#import "SDWebImageTestCoder.h"
#import "SDWebImageTestLoader.h"
#import <compression.h>

#define kPlaceholderTestURLTemplate @"https://via.placeholder.com/10000x%d.png"

/**
 *  Category for TXWebImageDownloader so we can access the operationClass
 */
@interface TXWebImageDownloadToken ()
@property (nonatomic, weak, nullable) NSOperation<TXWebImageDownloaderOperation> *downloadOperation;
@end

@interface TXWebImageDownloader ()
@property (strong, nonatomic, nonnull) NSOperationQueue *downloadQueue;
@end


@interface TXWebImageDownloaderTests : SDTestCase

@property (nonatomic, strong) NSMutableArray<NSURL *> *executionOrderURLs;

@end

@implementation TXWebImageDownloaderTests

- (void)test01ThatSharedDownloaderIsNotEqualToInitDownloader {
    TXWebImageDownloader *downloader = [[TXWebImageDownloader alloc] init];
    expect(downloader).toNot.equal([TXWebImageDownloader sharedDownloader]);
    [downloader invalidateSessionAndCancel:YES];
}

- (void)test02ThatByDefaultDownloaderSetsTheAcceptHTTPHeader {
    expect([[TXWebImageDownloader sharedDownloader] valueForHTTPHeaderField:@"Accept"]).to.match(@"image/\\*,\\*/\\*;q=0.8");
}

- (void)test03ThatSetAndGetValueForHTTPHeaderFieldWork {
    NSString *headerValue = @"Tests";
    NSString *headerName = @"AppName";
    // set it
    [[TXWebImageDownloader sharedDownloader] setValue:headerValue forHTTPHeaderField:headerName];
    expect([[TXWebImageDownloader sharedDownloader] valueForHTTPHeaderField:headerName]).to.equal(headerValue);
    // clear it
    [[TXWebImageDownloader sharedDownloader] setValue:nil forHTTPHeaderField:headerName];
    expect([[TXWebImageDownloader sharedDownloader] valueForHTTPHeaderField:headerName]).to.beNil();
}

- (void)test04ThatASimpleDownloadWorks {
    XCTestExpectation *expectation = [self expectationWithDescription:@"Simple download"];
    NSURL *imageURL = [NSURL URLWithString:kTestJPEGURL];
    [[TXWebImageDownloader sharedDownloader] downloadImageWithURL:imageURL options:0 progress:nil completed:^(UIImage * _Nullable image, NSData * _Nullable data, NSError * _Nullable error, BOOL finished) {
        if (image && data && !error && finished) {
            [expectation fulfill];
        } else {
            XCTFail(@"Something went wrong: %@", error.description);
        }
    }];
    [self waitForExpectationsWithCommonTimeout];
}

- (void)test05ThatSetAndGetMaxConcurrentDownloadsWorks {
    NSInteger initialValue = TXWebImageDownloader.sharedDownloader.config.maxConcurrentDownloads;
    
    TXWebImageDownloader.sharedDownloader.config.maxConcurrentDownloads = 3;
    expect(TXWebImageDownloader.sharedDownloader.config.maxConcurrentDownloads).to.equal(3);
    
    TXWebImageDownloader.sharedDownloader.config.maxConcurrentDownloads = initialValue;
}

- (void)test06ThatUsingACustomDownloaderOperationWorks {
    TXWebImageDownloader *downloader = [[TXWebImageDownloader alloc] initWithConfig:nil];
    NSURL *imageURL1 = [NSURL URLWithString:kTestJPEGURL];
    NSURL *imageURL2 = [NSURL URLWithString:kTestPNGURL];
    NSURL *imageURL3 = [NSURL URLWithString:kTestGIFURL];
    // we try to set a usual NSOperation as operation class. Should not work
    downloader.config.operationClass = [NSOperation class];
    TXWebImageDownloadToken *token = [downloader downloadImageWithURL:imageURL1 options:0 progress:nil completed:nil];
    NSOperation<TXWebImageDownloaderOperation> *operation = token.downloadOperation;
    expect([operation class]).to.equal([TXWebImageDownloaderOperation class]);
    
    // setting an NSOperation subclass that conforms to TXWebImageDownloaderOperation - should work
    downloader.config.operationClass = [SDWebImageTestDownloadOperation class];
    token = [downloader downloadImageWithURL:imageURL2 options:0 progress:nil completed:nil];
    operation = token.downloadOperation;
    expect([operation class]).to.equal([SDWebImageTestDownloadOperation class]);
    
    // Assert the NSOperation conforms to `TXWebImageOperation`
    expect([NSOperation.class conformsToProtocol:@protocol(TXWebImageOperation)]).beTruthy();
    expect([operation conformsToProtocol:@protocol(TXWebImageOperation)]).beTruthy();
    
    // back to the original value
    downloader.config.operationClass = nil;
    token = [downloader downloadImageWithURL:imageURL3 options:0 progress:nil completed:nil];
    operation = token.downloadOperation;
    expect([operation class]).to.equal([TXWebImageDownloaderOperation class]);
    
    [downloader invalidateSessionAndCancel:YES];
}

- (void)test07ThatDownloadImageWithNilURLCallsCompletionWithNils {
    XCTestExpectation *expectation = [self expectationWithDescription:@"Completion is called with nils"];
    [[TXWebImageDownloader sharedDownloader] downloadImageWithURL:nil options:0 progress:nil completed:^(UIImage * _Nullable image, NSData * _Nullable data, NSError * _Nullable error, BOOL finished) {
        expect(image).to.beNil();
        expect(data).to.beNil();
        expect(error.code).equal(TXWebImageErrorInvalidURL);
        [expectation fulfill];
    }];
    [self waitForExpectationsWithCommonTimeout];
}

- (void)test08ThatAHTTPAuthDownloadWorks {
    XCTestExpectation *expectation = [self expectationWithDescription:@"HTTP Auth download"];
    TXWebImageDownloaderConfig *config = TXWebImageDownloaderConfig.defaultDownloaderConfig;
    config.username = @"httpwatch";
    config.password = @"httpwatch01";
    TXWebImageDownloader *downloader = [[TXWebImageDownloader alloc] initWithConfig:config];
    NSURL *imageURL = [NSURL URLWithString:@"http://www.httpwatch.com/httpgallery/authentication/authenticatedimage/default.aspx?0.35786508303135633"];
    [downloader downloadImageWithURL:imageURL options:0 progress:nil completed:^(UIImage * _Nullable image, NSData * _Nullable data, NSError * _Nullable error, BOOL finished) {
        if (image && data && !error && finished) {
            [expectation fulfill];
        } else {
            XCTFail(@"Something went wrong: %@", error.description);
        }
    }];
    [self waitForExpectationsWithCommonTimeoutUsingHandler:^(NSError * _Nullable error) {
        [downloader invalidateSessionAndCancel:YES];
    }];
}

- (void)test09ThatProgressiveJPEGWorks {
    XCTestExpectation *expectation = [self expectationWithDescription:@"Progressive JPEG download"];
    NSURL *imageURL = [NSURL URLWithString:kTestProgressiveJPEGURL];
    [[TXWebImageDownloader sharedDownloader] downloadImageWithURL:imageURL options:TXWebImageDownloaderProgressiveLoad progress:nil completed:^(UIImage * _Nullable image, NSData * _Nullable data, NSError * _Nullable error, BOOL finished) {
        if (image && data && !error && finished) {
            [expectation fulfill];
        } else if (finished) {
            XCTFail(@"Something went wrong: %@", error.description);
        } else {
            // progressive updates
        }
    }];
    [self waitForExpectationsWithCommonTimeout];
}

- (void)test10That404CaseCallsCompletionWithError {
    NSURL *imageURL = [NSURL URLWithString:@"http://static2.dmcdn.net/static/video/656/177/44771656:jpeg_preview_small.jpg?20120509154705"];
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"404"];
    [[TXWebImageDownloader sharedDownloader] downloadImageWithURL:imageURL options:0 progress:nil completed:^(UIImage * _Nullable image, NSData * _Nullable data, NSError * _Nullable error, BOOL finished) {
        if (!image && !data && error && finished) {
            [expectation fulfill];
        } else {
            XCTFail(@"Something went wrong: %@", error.description);
        }
    }];
    [self waitForExpectationsWithCommonTimeout];
}

- (void)test11ThatCancelWorks {
    XCTestExpectation *expectation = [self expectationWithDescription:@"Cancel"];
    
    NSURL *imageURL = [NSURL URLWithString:@"http://via.placeholder.com/1000x1000.png"];
    TXWebImageDownloadToken *token = [[TXWebImageDownloader sharedDownloader]
                                      downloadImageWithURL:imageURL options:0 progress:nil completed:^(UIImage * _Nullable image, NSData * _Nullable data, NSError * _Nullable error, BOOL finished) {
                                          expect(error).notTo.beNil();
                                          expect(error.domain).equal(TXWebImageErrorDomain);
                                          expect(error.code).equal(TXWebImageErrorCancelled);
                                      }];
    expect([TXWebImageDownloader sharedDownloader].currentDownloadCount).to.equal(1);
    
    [token cancel];
    
    // doesn't cancel immediately - since it uses dispatch async
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, kMinDelayNanosecond), dispatch_get_main_queue(), ^{
        expect([TXWebImageDownloader sharedDownloader].currentDownloadCount).to.equal(0);
        [expectation fulfill];
    });
    
    [self waitForExpectationsWithCommonTimeout];
}

- (void)test11ThatCancelAllDownloadWorks {
    XCTestExpectation *expectation = [self expectationWithDescription:@"CancelAllDownloads"];
    // Previous test case download may not finished, so we just check the download count should + 1 after new request
    NSUInteger currentDownloadCount = [TXWebImageDownloader sharedDownloader].currentDownloadCount;
    
    // Choose a large image to avoid download too fast
    NSURL *imageURL = [NSURL URLWithString:@"https://www.sample-videos.com/img/Sample-png-image-1mb.png"];
    [[TXWebImageDownloader sharedDownloader] downloadImageWithURL:imageURL completed:nil];
    expect([TXWebImageDownloader sharedDownloader].currentDownloadCount).to.equal(currentDownloadCount + 1);
    
    [[TXWebImageDownloader sharedDownloader] cancelAllDownloads];
    
    // doesn't cancel immediately - since it uses dispatch async
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, kMinDelayNanosecond), dispatch_get_main_queue(), ^{
        expect([TXWebImageDownloader sharedDownloader].currentDownloadCount).to.equal(0);
        [expectation fulfill];
    });
    
    [self waitForExpectationsWithCommonTimeout];
}

- (void)test12ThatWeCanUseAnotherSessionForEachDownloadOperation {
    XCTestExpectation *expectation = [self expectationWithDescription:@"Owned session"];
    NSURL *url = [NSURL URLWithString:kTestJPEGURL];
    
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] initWithURL:url cachePolicy:NSURLRequestReloadIgnoringLocalCacheData timeoutInterval:15];
    request.HTTPShouldUsePipelining = YES;
    request.allHTTPHeaderFields = @{@"Accept": @"image/*;q=0.8"};
    
    TXWebImageDownloaderOperation *operation = [[TXWebImageDownloaderOperation alloc] initWithRequest:request
                                                                                            inSession:nil
                                                                                              options:0];
    [operation addHandlersForProgress:^(NSInteger receivedSize, NSInteger expectedSize, NSURL *imageURL) {
        
    } completed:^(UIImage * _Nullable image, NSData * _Nullable data, NSError * _Nullable error, BOOL finished) {
        if (image && data && !error && finished) {
            [expectation fulfill];
        } else {
            XCTFail(@"Something went wrong: %@", error.description);
        }
    }];
    
    [operation start];
    
    [self waitForExpectationsWithCommonTimeout];
}

- (void)test13ThatDownloadCanContinueWhenTheAppEntersBackground {
    XCTestExpectation *expectation = [self expectationWithDescription:@"Simple download"];
    NSURL *imageURL = [NSURL URLWithString:kTestJPEGURL];
    [[TXWebImageDownloader sharedDownloader] downloadImageWithURL:imageURL options:TXWebImageDownloaderContinueInBackground progress:nil completed:^(UIImage * _Nullable image, NSData * _Nullable data, NSError * _Nullable error, BOOL finished) {
        if (image && data && !error && finished) {
            [expectation fulfill];
        } else {
            XCTFail(@"Something went wrong: %@", error.description);
        }
    }];
    [self waitForExpectationsWithCommonTimeout];
}

- (void)test14ThatPNGWorks {
    XCTestExpectation *expectation = [self expectationWithDescription:@"PNG"];
    NSURL *imageURL = [NSURL URLWithString:kTestPNGURL];
    [[TXWebImageDownloader sharedDownloader] downloadImageWithURL:imageURL options:0 progress:nil completed:^(UIImage * _Nullable image, NSData * _Nullable data, NSError * _Nullable error, BOOL finished) {
        if (image && data && !error && finished) {
            [expectation fulfill];
        } else {
            XCTFail(@"Something went wrong: %@", error.description);
        }
    }];
    [self waitForExpectationsWithCommonTimeout];
}

- (void)test15DownloaderLIFOExecutionOrder {
    TXWebImageDownloaderConfig *config = [[TXWebImageDownloaderConfig alloc] init];
    config.executionOrder = TXWebImageDownloaderLIFOExecutionOrder; // Last In First Out
    config.maxConcurrentDownloads = 1; // 1
    TXWebImageDownloader *downloader = [[TXWebImageDownloader alloc] initWithConfig:config];
    self.executionOrderURLs = [NSMutableArray array];
    
    // Input order: 1 -> 2 -> 3 -> 4 -> 5 -> 6 -> 7 (wait for 7 started and immediately) -> 8 -> 9 -> 10 -> 11 -> 12 -> 13 -> 14
    // Expected result: 1 (first one has no dependency) -> 7 -> 14 -> 13 -> 12 -> 11 -> 10 -> 9 -> 8 -> 6 -> 5 -> 4 -> 3 -> 2
    int waitIndex = 7;
    int maxIndex = 14;
    NSMutableArray<XCTestExpectation *> *expectations = [NSMutableArray array];
    for (int i = 1; i <= maxIndex; i++) {
        XCTestExpectation *expectation = [self expectationWithDescription:[NSString stringWithFormat:@"URL %d order wrong", i]];
        [expectations addObject:expectation];
    }
    
    for (int i = 1; i <= waitIndex; i++) {
        [self createLIFOOperationWithDownloader:downloader expectation:expectations[i-1] index:i];
    }
    [[NSNotificationCenter defaultCenter] addObserverForName:TXWebImageDownloadStartNotification object:nil queue:nil usingBlock:^(NSNotification * _Nonnull note) {
        TXWebImageDownloaderOperation *operation = note.object;
        NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:kPlaceholderTestURLTemplate, waitIndex]];
        if (![operation.request.URL isEqual:url]) {
            return;
        }
        for (int i = waitIndex + 1; i <= maxIndex; i++) {
            [self createLIFOOperationWithDownloader:downloader expectation:expectations[i-1] index:i];
        }
    }];
    
    [self waitForExpectationsWithTimeout:kAsyncTestTimeout * maxIndex handler:nil];
}

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wshadow"
- (void)createLIFOOperationWithDownloader:(TXWebImageDownloader *)downloader expectation:(XCTestExpectation *)expectation index:(int)index {
    int waitIndex = 7;
    int maxIndex = 14;
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:kPlaceholderTestURLTemplate, index]];
    [self.executionOrderURLs addObject:url];
    [downloader downloadImageWithURL:url options:0 progress:nil completed:^(UIImage * _Nullable image, NSData * _Nullable data, NSError * _Nullable error, BOOL finished) {
        printf("URL%d finished\n", index);
        NSMutableArray *pendingArray = [NSMutableArray array];
        if (index == 1) {
            // 1
            for (int j = 1; j <= waitIndex; j++) {
                NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:kPlaceholderTestURLTemplate, j]];
                [pendingArray addObject:url];
            }
        } else if (index == waitIndex) {
            // 7
            for (int j = 2; j <= maxIndex; j++) {
                NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:kPlaceholderTestURLTemplate, j]];
                [pendingArray addObject:url];
            }
        } else if (index > waitIndex) {
            // 8-14
            for (int j = 2; j <= index; j++) {
                if (j == waitIndex) continue;
                NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:kPlaceholderTestURLTemplate, j]];
                [pendingArray addObject:url];
            }
        } else if (index < waitIndex) {
            // 2-6
            for (int j = 2; j <= index; j++) {
                if (j == waitIndex) continue;
                NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:kPlaceholderTestURLTemplate, j]];
                [pendingArray addObject:url];
            }
        }
        expect(self.executionOrderURLs).equal(pendingArray);
        NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:kPlaceholderTestURLTemplate, index]];
        [self.executionOrderURLs removeObject:url];
        [expectation fulfill];
    }];
}
#pragma clang diagnostic pop

- (void)test17ThatMinimumProgressIntervalWorks {
    XCTestExpectation *expectation = [self expectationWithDescription:@"Minimum progress interval"];
    TXWebImageDownloaderConfig *config = TXWebImageDownloaderConfig.defaultDownloaderConfig;
    config.minimumProgressInterval = 0.51; // This will make the progress only callback twice (once is 51%, another is 100%)
    TXWebImageDownloader *downloader = [[TXWebImageDownloader alloc] initWithConfig:config];
    NSURL *imageURL = [NSURL URLWithString:@"https://raw.githubusercontent.com/recurser/exif-orientation-examples/master/Landscape_1.jpg"];
    __block NSUInteger allProgressCount = 0; // All progress (including operation start / first HTTP response, etc)
    [downloader downloadImageWithURL:imageURL options:0 progress:^(NSInteger receivedSize, NSInteger expectedSize, NSURL * _Nullable targetURL) {
        allProgressCount++;
    } completed:^(UIImage * _Nullable image, NSData * _Nullable data, NSError * _Nullable error, BOOL finished) {
        if (allProgressCount > 0) {
            [expectation fulfill];
            allProgressCount = 0;
            return;
        } else {
            XCTFail(@"Progress callback more than once");
        }
    }];
     
    [self waitForExpectationsWithCommonTimeoutUsingHandler:^(NSError * _Nullable error) {
        [downloader invalidateSessionAndCancel:YES];
    }];
}

- (void)test18ThatProgressiveGIFWorks {
    XCTestExpectation *expectation = [self expectationWithDescription:@"Progressive GIF download"];
    NSURL *imageURL = [NSURL URLWithString:kTestGIFURL];
    [[TXWebImageDownloader sharedDownloader] downloadImageWithURL:imageURL options:TXWebImageDownloaderProgressiveLoad progress:nil completed:^(UIImage * _Nullable image, NSData * _Nullable data, NSError * _Nullable error, BOOL finished) {
        if (image && data && !error && finished) {
            [expectation fulfill];
        } else if (finished) {
            XCTFail(@"Something went wrong: %@", error.description);
        } else {
            // progressive updates
        }
    }];
    [self waitForExpectationsWithCommonTimeout];
}

- (void)test19ThatProgressiveAPNGWorks {
    XCTestExpectation *expectation = [self expectationWithDescription:@"Progressive APNG download"];
    NSURL *imageURL = [NSURL URLWithString:kTestAPNGPURL];
    [[TXWebImageDownloader sharedDownloader] downloadImageWithURL:imageURL options:TXWebImageDownloaderProgressiveLoad progress:nil completed:^(UIImage * _Nullable image, NSData * _Nullable data, NSError * _Nullable error, BOOL finished) {
        if (image && data && !error && finished) {
            [expectation fulfill];
        } else if (finished) {
            XCTFail(@"Something went wrong: %@", error.description);
        } else {
            // progressive updates
        }
    }];
    [self waitForExpectationsWithCommonTimeout];
}

/**
 *  Per #883 - Fix multiple requests for same image and then canceling one
 *  Old SDWebImage (3.x) could not handle correctly multiple requests for the same image + cancel
 *  In 4.0, via #883 added `TXWebImageDownloadToken` so we can cancel exactly the request we want
 *  This test validates the scenario of making 2 requests for the same image and cancelling the 1st one
 */
- (void)test20ThatDownloadingSameURLTwiceAndCancellingFirstWorks {
    XCTestExpectation *expectation = [self expectationWithDescription:@"Correct image downloads"];
    
    NSURL *imageURL = [NSURL URLWithString:kTestJPEGURL];
    
    TXWebImageDownloadToken *token1 = [[TXWebImageDownloader sharedDownloader]
                                       downloadImageWithURL:imageURL
                                       options:0
                                       progress:nil
                                       completed:^(UIImage *image, NSData *data, NSError *error, BOOL finished) {
                                           expect(error).notTo.beNil();
                                           expect(error.code).equal(TXWebImageErrorCancelled);
                                       }];
    expect(token1).toNot.beNil();
    
    TXWebImageDownloadToken *token2 = [[TXWebImageDownloader sharedDownloader]
                                       downloadImageWithURL:imageURL
                                       options:0
                                       progress:nil
                                       completed:^(UIImage *image, NSData *data, NSError *error, BOOL finished) {
                                           if (image && data && !error && finished) {
                                               [expectation fulfill];
                                           } else {
                                               XCTFail(@"Something went wrong: %@", error.description);
                                           }
                                       }];
    expect(token2).toNot.beNil();

    [token1 cancel];

    [self waitForExpectationsWithCommonTimeout];
}

/**
 *  Per #883 - Fix multiple requests for same image and then canceling one
 *  Old SDWebImage (3.x) could not handle correctly multiple requests for the same image + cancel
 *  In 4.0, via #883 added `TXWebImageDownloadToken` so we can cancel exactly the request we want
 *  This test validates the scenario of requesting an image, cancel and then requesting it again
 */
- (void)test21ThatCancelingDownloadThenRequestingAgainWorks {
    XCTestExpectation *expectation = [self expectationWithDescription:@"Correct image downloads"];
    
    NSURL *imageURL = [NSURL URLWithString:kTestJPEGURL];
    
    TXWebImageDownloadToken *token1 = [[TXWebImageDownloader sharedDownloader]
                                       downloadImageWithURL:imageURL
                                       options:0
                                       progress:nil
                                       completed:^(UIImage *image, NSData *data, NSError *error, BOOL finished) {
                                           expect(error).notTo.beNil();
                                           expect(error.code).equal(TXWebImageErrorCancelled);
                                       }];
    expect(token1).toNot.beNil();
    
    [token1 cancel];
    
    TXWebImageDownloadToken *token2 = [[TXWebImageDownloader sharedDownloader]
                                       downloadImageWithURL:imageURL
                                       options:0
                                       progress:nil
                                       completed:^(UIImage *image, NSData *data, NSError *error, BOOL finished) {
                                           if (image && data && !error && finished) {
                                               [expectation fulfill];
                                           } else {
                                               NSLog(@"image = %@, data = %@, error = %@", image, data, error);
                                               XCTFail(@"Something went wrong: %@", error.description);
                                           }
                                       }];
    expect(token2).toNot.beNil();
    
    [self waitForExpectationsWithCommonTimeout];
}

- (void)test22ThatCustomDecoderWorksForImageDownload {
    XCTestExpectation *expectation = [self expectationWithDescription:@"Custom decoder for TXWebImageDownloader not works"];
    TXWebImageDownloader *downloader = [[TXWebImageDownloader alloc] init];
    SDWebImageTestCoder *testDecoder = [[SDWebImageTestCoder alloc] init];
    [[TXImageCodersManager sharedManager] addCoder:testDecoder];
    NSURL * testImageURL = [[NSBundle bundleForClass:[self class]] URLForResource:@"TestImage" withExtension:@"png"];
    
    // Decoded result is JPEG
    NSString *testJPEGImagePath = [[NSBundle bundleForClass:[self class]] pathForResource:@"TestImage" ofType:@"jpg"];
    UIImage *testJPEGImage = [[UIImage alloc] initWithContentsOfFile:testJPEGImagePath];
    
    [downloader downloadImageWithURL:testImageURL options:0 progress:nil completed:^(UIImage * _Nullable image, NSData * _Nullable data, NSError * _Nullable error, BOOL finished) {
        NSData *data1 = [testJPEGImage sd_imageDataAsFormat:SDImageFormatPNG];
        NSData *data2 = [image sd_imageDataAsFormat:SDImageFormatPNG];
        if (![data1 isEqualToData:data2]) {
            XCTFail(@"The image data is not equal to cutom decoder, check -[SDWebImageTestDecoder decodedImageWithData:]");
        }
        [[TXImageCodersManager sharedManager] removeCoder:testDecoder];
        [expectation fulfill];
    }];
    
    [self waitForExpectationsWithCommonTimeout];
    [downloader invalidateSessionAndCancel:YES];
}

- (void)test23ThatDownloadRequestModifierWorks {
    XCTestExpectation *expectation = [self expectationWithDescription:@"Download request modifier not works"];
    TXWebImageDownloader *downloader = [[TXWebImageDownloader alloc] init];
    
    // Test conveniences modifier
    TXWebImageDownloaderRequestModifier *requestModifier = [[TXWebImageDownloaderRequestModifier alloc] initWithHeaders:@{@"Biz" : @"Bazz"}];
    NSURLRequest *testRequest = [[NSURLRequest alloc] initWithURL:[NSURL URLWithString:kTestJPEGURL]];
    testRequest = [requestModifier modifiedRequestWithRequest:testRequest];
    expect(testRequest.allHTTPHeaderFields).equal(@{@"Biz" : @"Bazz"});
    
    requestModifier = [TXWebImageDownloaderRequestModifier requestModifierWithBlock:^NSURLRequest * _Nullable(NSURLRequest * _Nonnull request) {
        if ([request.URL.absoluteString isEqualToString:kTestPNGURL]) {
            // Test that return a modified request
            NSMutableURLRequest *mutableRequest = [request mutableCopy];
            [mutableRequest setValue:@"Bar" forHTTPHeaderField:@"Foo"];
            NSURLComponents *components = [NSURLComponents componentsWithURL:mutableRequest.URL resolvingAgainstBaseURL:NO];
            components.query = @"text=Hello+World";
            mutableRequest.URL = components.URL;
            return mutableRequest;
        } else if ([request.URL.absoluteString isEqualToString:kTestJPEGURL]) {
            // Test that return nil request will treat as error
            return nil;
        } else {
            return request;
        }
    }];
    downloader.requestModifier = requestModifier;
    
    __block BOOL firstCheck = NO;
    __block BOOL secondCheck = NO;
    
    [downloader downloadImageWithURL:[NSURL URLWithString:kTestJPEGURL] options:0 progress:nil completed:^(UIImage * _Nullable image, NSData * _Nullable data, NSError * _Nullable error, BOOL finished) {
        // Except error
        expect(error).notTo.beNil();
        firstCheck = YES;
        if (firstCheck && secondCheck) {
            [expectation fulfill];
        }
    }];
    
    [downloader downloadImageWithURL:[NSURL URLWithString:kTestPNGURL] options:0 progress:nil completed:^(UIImage * _Nullable image, NSData * _Nullable data, NSError * _Nullable error, BOOL finished) {
        // Expect not error
        expect(error).to.beNil();
        secondCheck = YES;
        if (firstCheck && secondCheck) {
            [expectation fulfill];
        }
    }];
    
    [self waitForExpectationsWithCommonTimeout];
}

- (void)test24ThatDownloadResponseModifierWorks {
    XCTestExpectation *expectation1 = [self expectationWithDescription:@"Download response modifier for webURL"];
    XCTestExpectation *expectation2 = [self expectationWithDescription:@"Download response modifier invalid response"];
    
    TXWebImageDownloader *downloader = [[TXWebImageDownloader alloc] init];
    
    // Test conveniences modifier
    TXWebImageDownloaderResponseModifier *responseModifier = [[TXWebImageDownloaderResponseModifier alloc] initWithHeaders:@{@"Biz" : @"Bazz"}];
    NSURLResponse *testResponse = [[NSHTTPURLResponse alloc] initWithURL:[NSURL URLWithString:kTestPNGURL] statusCode:404 HTTPVersion:@"HTTP/1.1" headerFields:nil];
    testResponse = [responseModifier modifiedResponseWithResponse:testResponse];
    expect(((NSHTTPURLResponse *)testResponse).allHeaderFields).equal(@{@"Biz" : @"Bazz"});
    expect(((NSHTTPURLResponse *)testResponse).statusCode).equal(200);
    
    // 1. Test webURL to response custom status code and header
    responseModifier = [TXWebImageDownloaderResponseModifier responseModifierWithBlock:^NSURLResponse * _Nullable(NSURLResponse * _Nonnull response) {
        NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
        NSMutableDictionary *mutableHeaderFields = [httpResponse.allHeaderFields mutableCopy];
        mutableHeaderFields[@"Foo"] = @"Bar";
        NSHTTPURLResponse *modifiedResponse = [[NSHTTPURLResponse alloc] initWithURL:response.URL statusCode:404 HTTPVersion:nil headerFields:[mutableHeaderFields copy]];
        return [modifiedResponse copy];
    }];
    downloader.responseModifier = responseModifier;
    
    __block TXWebImageDownloadToken *token;
    token = [downloader downloadImageWithURL:[NSURL URLWithString:kTestJPEGURL] completed:^(UIImage * _Nullable image, NSData * _Nullable data, NSError * _Nullable error, BOOL finished) {
        expect(error).notTo.beNil();
        expect(error.code).equal(TXWebImageErrorInvalidDownloadStatusCode);
        expect(error.userInfo[TXWebImageErrorDownloadStatusCodeKey]).equal(404);
        NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)token.response;
        expect(httpResponse).notTo.beNil();
        expect(httpResponse.allHeaderFields[@"Foo"]).equal(@"Bar");
        [expectation1 fulfill];
    }];
    
    // 2. Test nil response will cancel the download
    responseModifier = [TXWebImageDownloaderResponseModifier responseModifierWithBlock:^NSURLResponse * _Nullable(NSURLResponse * _Nonnull response) {
        return nil;
    }];
    [downloader downloadImageWithURL:[NSURL URLWithString:kTestPNGURL] options:0 context:@{SDWebImageContextDownloadResponseModifier : responseModifier} progress:nil completed:^(UIImage * _Nullable image, NSData * _Nullable data, NSError * _Nullable error, BOOL finished) {
        expect(error).notTo.beNil();
        expect(error.code).equal(TXWebImageErrorInvalidDownloadResponse);
        [expectation2 fulfill];
    }];
    
    [self waitForExpectationsWithCommonTimeoutUsingHandler:^(NSError * _Nullable error) {
        [downloader invalidateSessionAndCancel:YES];
    }];
}

- (void)test25ThatDownloadDecryptorWorks {
    XCTestExpectation *expectation1 = [self expectationWithDescription:@"Download decryptor for fileURL"];
    XCTestExpectation *expectation2 = [self expectationWithDescription:@"Download decryptor for webURL"];
    XCTestExpectation *expectation3 = [self expectationWithDescription:@"Download decryptor invalid data"];
    
    TXWebImageDownloader *downloader = [[TXWebImageDownloader alloc] init];
    downloader.decryptor = TXWebImageDownloaderDecryptor.base64Decryptor;
    
    // 1. Test fileURL with Base64 encoded data works
    NSData *PNGData = [NSData dataWithContentsOfFile:[self testPNGPath]];
    NSData *base64PNGData = [PNGData base64EncodedDataWithOptions:0];
    expect(base64PNGData).notTo.beNil();
    NSURL *base64FileURL = [NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:@"TestBase64.png"]];
    [base64PNGData writeToURL:base64FileURL atomically:YES];
    [downloader downloadImageWithURL:base64FileURL options:0 progress:nil completed:^(UIImage * _Nullable image, NSData * _Nullable data, NSError * _Nullable error, BOOL finished) {
        expect(error).to.beNil();
        expect(image).notTo.beNil();
        [expectation1 fulfill];
    }];
    
    // 2. Test webURL with Zip encoded data works
    TXWebImageDownloaderDecryptor *decryptor = [TXWebImageDownloaderDecryptor decryptorWithBlock:^NSData * _Nullable(NSData * _Nonnull data, NSURLResponse * _Nullable response) {
        if (@available(iOS 13, macOS 10.15, tvOS 13, *)) {
            return [data decompressedDataUsingAlgorithm:NSDataCompressionAlgorithmZlib error:nil];
        } else {
            NSMutableData *decodedData = [NSMutableData dataWithLength:10 * data.length];
            compression_decode_buffer((uint8_t *)decodedData.bytes, decodedData.length, data.bytes, data.length, nil, COMPRESSION_ZLIB);
            return [decodedData copy];
        }
    }];
    // Note this is not a Zip Archive, just PNG raw buffer data using zlib compression
    NSURL *zipURL = [NSURL URLWithString:@"https://github.com/SDWebImage/SDWebImage/files/3728087/SDWebImage_logo_small.png.zip"];
    
    [downloader downloadImageWithURL:zipURL options:0 context:@{SDWebImageContextDownloadDecryptor : decryptor} progress:nil completed:^(UIImage * _Nullable image, NSData * _Nullable data, NSError * _Nullable error, BOOL finished) {
        expect(error).to.beNil();
        expect(image).notTo.beNil();
        [expectation2 fulfill];
    }];
    
    // 3. Test nil data will mark download failed
    decryptor = [TXWebImageDownloaderDecryptor decryptorWithBlock:^NSData * _Nullable(NSData * _Nonnull data, NSURLResponse * _Nullable response) {
        return nil;
    }];
    [downloader downloadImageWithURL:[NSURL URLWithString:kTestJPEGURL] options:0 context:@{SDWebImageContextDownloadDecryptor : decryptor} progress:nil completed:^(UIImage * _Nullable image, NSData * _Nullable data, NSError * _Nullable error, BOOL finished) {
        expect(error).notTo.beNil();
        expect(error.code).equal(TXWebImageErrorBadImageData);
        [expectation3 fulfill];
    }];
    
    [self waitForExpectationsWithCommonTimeoutUsingHandler:^(NSError * _Nullable error) {
        [downloader invalidateSessionAndCancel:YES];
    }];
}

- (void)test26DownloadURLSessionMetrics {
    XCTestExpectation *expectation1 = [self expectationWithDescription:@"Download URLSessionMetrics works"];
    
    TXWebImageDownloader *downloader = [[TXWebImageDownloader alloc] init];
    
    __block TXWebImageDownloadToken *token;
    token = [downloader downloadImageWithURL:[NSURL URLWithString:kTestJPEGURL] completed:^(UIImage * _Nullable image, NSData * _Nullable data, NSError * _Nullable error, BOOL finished) {
        expect(error).beNil();
        if (@available(iOS 10.0, tvOS 10.0, macOS 10.12, *)) {
            NSURLSessionTaskMetrics *metrics = token.metrics;
            expect(metrics).notTo.beNil();
            expect(metrics.redirectCount).equal(0);
            expect(metrics.transactionMetrics.count).equal(1);
            NSURLSessionTaskTransactionMetrics *metric = metrics.transactionMetrics.firstObject;
            // Metrcis Test
            expect(metric.fetchStartDate).notTo.beNil();
            expect(metric.connectStartDate).notTo.beNil();
            expect(metric.connectEndDate).notTo.beNil();
            expect(metric.networkProtocolName).equal(@"http/1.1");
            expect(metric.resourceFetchType).equal(NSURLSessionTaskMetricsResourceFetchTypeNetworkLoad);
            expect(metric.isProxyConnection).beFalsy();
            expect(metric.isReusedConnection).beFalsy();
        }
        [expectation1 fulfill];
    }];
    
    [self waitForExpectationsWithCommonTimeoutUsingHandler:^(NSError * _Nullable error) {
        [downloader invalidateSessionAndCancel:YES];
    }];
}

- (void)test27DownloadShouldCallbackWhenURLSessionRunning {
    XCTestExpectation *expectation = [self expectationWithDescription:@"Downloader should callback when URLSessionTask running"];
    
    NSURL *url = [NSURL URLWithString: @"https://raw.githubusercontent.com/SDWebImage/SDWebImage/master/SDWebImage_logo.png"];
    NSString *key = [TXWebImageManager.sharedManager cacheKeyForURL:url];
    
    [TXImageCache.sharedImageCache removeImageForKey:key withCompletion:^{
        SDWebImageCombinedOperation *operation = [TXWebImageManager.sharedManager loadImageWithURL:url options:0 progress:nil completed:^(UIImage * _Nullable image, NSData * _Nullable data, NSError * _Nullable error, TXImageCacheType cacheType, BOOL finished, NSURL * _Nullable imageURL) {
            expect(error.domain).equal(TXWebImageErrorDomain);
            expect(error.code).equal(TXWebImageErrorCancelled);
            [expectation fulfill];
        }];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [operation cancel];
        });
    }];
    
    [self waitForExpectationsWithCommonTimeout];
}

- (void)test28ProgressiveDownloadShouldUseSameCoder  {
    XCTestExpectation *expectation = [self expectationWithDescription:@"Progressive download should use the same coder for each animated image"];
    TXWebImageDownloader *downloader = [[TXWebImageDownloader alloc] init];
    
    __block TXWebImageDownloadToken *token;
    __block id<TXImageCoder> progressiveCoder;
    token = [downloader downloadImageWithURL:[NSURL URLWithString:kTestGIFURL] options:TXWebImageDownloaderProgressiveLoad context:@{SDWebImageContextAnimatedImageClass : TXAnimatedImage.class} progress:nil completed:^(UIImage * _Nullable image, NSData * _Nullable data, NSError * _Nullable error, BOOL finished) {
        expect(error).beNil();
        expect([image isKindOfClass:TXAnimatedImage.class]).beTruthy();
        id<TXImageCoder> coder = ((TXAnimatedImage *)image).animatedCoder;
        if (!progressiveCoder) {
            progressiveCoder = coder;
        }
        expect(progressiveCoder).equal(coder);
        if (!finished) {
            progressiveCoder = coder;
        } else {
            [expectation fulfill];
        }
    }];
    
    [self waitForExpectationsWithCommonTimeoutUsingHandler:^(NSError * _Nullable error) {
        [downloader invalidateSessionAndCancel:YES];
    }];
}

- (void)test29AcceptableStatusCodeAndContentType {
    TXWebImageDownloaderConfig *config1 = [[TXWebImageDownloaderConfig alloc] init];
    config1.acceptableStatusCodes = [NSIndexSet indexSetWithIndex:1];
    TXWebImageDownloader *downloader1 = [[TXWebImageDownloader alloc] initWithConfig:config1];
    XCTestExpectation *expectation1 = [self expectationWithDescription:@"Acceptable status code should work"];
    
    TXWebImageDownloaderConfig *config2 = [[TXWebImageDownloaderConfig alloc] init];
    config2.acceptableContentTypes = [NSSet setWithArray:@[@"application/json"]];
    TXWebImageDownloader *downloader2 = [[TXWebImageDownloader alloc] initWithConfig:config2];
    XCTestExpectation *expectation2 = [self expectationWithDescription:@"Acceptable content type should work"];
    
    __block TXWebImageDownloadToken *token1;
    token1 = [downloader1 downloadImageWithURL:[NSURL URLWithString:kTestJPEGURL] completed:^(UIImage * _Nullable image, NSData * _Nullable data, NSError * _Nullable error, BOOL finished) {
        expect(error).notTo.beNil();
        expect(error.code).equal(TXWebImageErrorInvalidDownloadStatusCode);
        NSInteger statusCode = ((NSHTTPURLResponse *)token1.response).statusCode;
        expect(statusCode).equal(200);
        [expectation1 fulfill];
    }];
    
    __block TXWebImageDownloadToken *token2;
    token2 = [downloader2 downloadImageWithURL:[NSURL URLWithString:kTestJPEGURL] completed:^(UIImage * _Nullable image, NSData * _Nullable data, NSError * _Nullable error, BOOL finished) {
        expect(error).notTo.beNil();
        expect(error.code).equal(TXWebImageErrorInvalidDownloadContentType);
        NSString *contentType = ((NSHTTPURLResponse *)token2.response).MIMEType;
        expect(contentType).equal(@"image/jpeg");
        [expectation2 fulfill];
    }];
    
    [self waitForExpectationsWithCommonTimeoutUsingHandler:^(NSError * _Nullable error) {
        [downloader1 invalidateSessionAndCancel:YES];
        [downloader2 invalidateSessionAndCancel:YES];
    }];
}

#pragma mark - SDWebImageLoader
- (void)test30CustomImageLoaderWorks {
    XCTestExpectation *expectation = [self expectationWithDescription:@"Custom image not works"];
    SDWebImageTestLoader *loader = [[SDWebImageTestLoader alloc] init];
    NSURL *imageURL = [NSURL URLWithString:kTestJPEGURL];
    expect([loader canRequestImageForURL:imageURL]).beTruthy();
    expect([loader canRequestImageForURL:imageURL options:0 context:nil]).beTruthy();
    NSError *imageError = [NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorCancelled userInfo:nil];
    expect([loader shouldBlockFailedURLWithURL:imageURL error:imageError]).equal(NO);
    
    [loader requestImageWithURL:imageURL options:0 context:nil progress:^(NSInteger receivedSize, NSInteger expectedSize, NSURL * _Nullable targetURL) {
        expect(targetURL).notTo.beNil();
    } completed:^(UIImage * _Nullable image, NSData * _Nullable data, NSError * _Nullable error, BOOL finished) {
        expect(error).to.beNil();
        expect(image).notTo.beNil();
        [expectation fulfill];
    }];
    
    [self waitForExpectationsWithCommonTimeout];
}

- (void)test31ThatLoadersManagerWorks {
    XCTestExpectation *expectation = [self expectationWithDescription:@"Loaders manager not works"];
    SDWebImageTestLoader *loader = [[SDWebImageTestLoader alloc] init];
    TXImageLoadersManager *manager = [[TXImageLoadersManager alloc] init];
    [manager addLoader:loader];
    [manager removeLoader:loader];
    manager.loaders = @[TXWebImageDownloader.sharedDownloader, loader];
    NSURL *imageURL = [NSURL URLWithString:kTestJPEGURL];
    expect([manager canRequestImageForURL:imageURL]).beTruthy();
    expect([manager canRequestImageForURL:imageURL options:0 context:nil]).beTruthy();
    NSError *imageError = [NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorCancelled userInfo:nil];
    expect([manager shouldBlockFailedURLWithURL:imageURL error:imageError]).equal(NO);
    
    [manager requestImageWithURL:imageURL options:0 context:nil progress:^(NSInteger receivedSize, NSInteger expectedSize, NSURL * _Nullable targetURL) {
        expect(targetURL).notTo.beNil();
    } completed:^(UIImage * _Nullable image, NSData * _Nullable data, NSError * _Nullable error, BOOL finished) {
        expect(error).to.beNil();
        expect(image).notTo.beNil();
        [expectation fulfill];
    }];
    
    [self waitForExpectationsWithCommonTimeout];
}

#pragma mark - Helper

- (NSString *)testPNGPath {
    NSBundle *testBundle = [NSBundle bundleForClass:[self class]];
    return [testBundle pathForResource:@"TestImage" ofType:@"png"];
}

@end
