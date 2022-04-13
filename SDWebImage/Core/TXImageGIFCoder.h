/*
 * This file is part of the SDWebImage package.
 * (c) Olivier Poitrey <rs@dailymotion.com>
 *
 * For the full copyright and license information, please view the LICENSE
 * file that was distributed with this source code.
 */

#import <Foundation/Foundation.h>
#import "TXImageIOAnimatedCoder.h"

/**
 Built in coder using ImageIO that supports animated GIF encoding/decoding
 @note `TXImageIOCoder` supports GIF but only as static (will use the 1st frame).
 @note Use `TXImageGIFCoder` for fully animated GIFs. For `UIImageView`, it will produce animated `UIImage`(`NSImage` on macOS) for rendering. For `TXAnimatedImageView`, it will use `TXAnimatedImage` for rendering.
 @note The recommended approach for animated GIFs is using `TXAnimatedImage` with `TXAnimatedImageView`. It's more performant than `UIImageView` for GIF displaying(especially on memory usage)
 */
@interface TXImageGIFCoder : TXImageIOAnimatedCoder <SDProgressiveImageCoder, TXAnimatedImageCoder>

@property (nonatomic, class, readonly, nonnull) TXImageGIFCoder *sharedCoder;

@end
