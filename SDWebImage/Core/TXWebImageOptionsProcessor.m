/*
 * This file is part of the SDWebImage package.
 * (c) Olivier Poitrey <rs@dailymotion.com>
 *
 * For the full copyright and license information, please view the LICENSE
 * file that was distributed with this source code.
 */

#import "TXWebImageOptionsProcessor.h"

@interface TXWebImageOptionsResult ()

@property (nonatomic, assign) SDWebImageOptions options;
@property (nonatomic, copy, nullable) SDWebImageContext *context;

@end

@implementation TXWebImageOptionsResult

- (instancetype)initWithOptions:(SDWebImageOptions)options context:(SDWebImageContext *)context {
    self = [super init];
    if (self) {
        self.options = options;
        self.context = context;
    }
    return self;
}

@end

@interface TXWebImageOptionsProcessor ()

@property (nonatomic, copy, nonnull) TXWebImageOptionsProcessorBlock block;

@end

@implementation TXWebImageOptionsProcessor

- (instancetype)initWithBlock:(TXWebImageOptionsProcessorBlock)block {
    self = [super init];
    if (self) {
        self.block = block;
    }
    return self;
}

+ (instancetype)optionsProcessorWithBlock:(TXWebImageOptionsProcessorBlock)block {
    TXWebImageOptionsProcessor *optionsProcessor = [[TXWebImageOptionsProcessor alloc] initWithBlock:block];
    return optionsProcessor;
}

- (TXWebImageOptionsResult *)processedResultForURL:(NSURL *)url options:(SDWebImageOptions)options context:(SDWebImageContext *)context {
    if (!self.block) {
        return nil;
    }
    return self.block(url, options, context);
}

@end
