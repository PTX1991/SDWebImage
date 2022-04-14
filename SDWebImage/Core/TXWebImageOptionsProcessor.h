/*
 * This file is part of the SDWebImage package.
 * (c) Olivier Poitrey <rs@dailymotion.com>
 *
 * For the full copyright and license information, please view the LICENSE
 * file that was distributed with this source code.
 */

#import <Foundation/Foundation.h>
#import "TXWebImageCompat.h"
#import "TXWebImageDefine.h"

@class TXWebImageOptionsResult;

typedef TXWebImageOptionsResult * _Nullable(^TXWebImageOptionsProcessorBlock)(NSURL * _Nullable url, SDWebImageOptions options, SDWebImageContext * _Nullable context);

/**
 The options result contains both options and context.
 */
@interface TXWebImageOptionsResult : NSObject

/**
 WebCache options.
 */
@property (nonatomic, assign, readonly) SDWebImageOptions options;

/**
 Context options.
 */
@property (nonatomic, copy, readonly, nullable) SDWebImageContext *context;

/**
 Create a new options result.

 @param options options
 @param context context
 @return The options result contains both options and context.
 */
- (nonnull instancetype)initWithOptions:(SDWebImageOptions)options context:(nullable SDWebImageContext *)context;

@end

/**
 This is the protocol for options processor.
 Options processor can be used, to control the final result for individual image request's `SDWebImageOptions` and `SDWebImageContext`
 Implements the protocol to have a global control for each indivadual image request's option.
 */
@protocol TXWebImageOptionsProcessor <NSObject>

/**
 Return the processed options result for specify image URL, with its options and context

 @param url The URL to the image
 @param options A mask to specify options to use for this request
 @param context A context contains different options to perform specify changes or processes, see `SDWebImageContextOption`. This hold the extra objects which `options` enum can not hold.
 @return The processed result, contains both options and context
 */
- (nullable TXWebImageOptionsResult *)processedResultForURL:(nullable NSURL *)url
                                                    options:(SDWebImageOptions)options
                                                    context:(nullable SDWebImageContext *)context;

@end

/**
 A options processor class with block.
 */
@interface TXWebImageOptionsProcessor : NSObject<TXWebImageOptionsProcessor>

- (nonnull instancetype)initWithBlock:(nonnull TXWebImageOptionsProcessorBlock)block;
+ (nonnull instancetype)optionsProcessorWithBlock:(nonnull TXWebImageOptionsProcessorBlock)block;

@end
