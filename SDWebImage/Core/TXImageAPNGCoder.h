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
 Built in coder using ImageIO that supports APNG encoding/decoding
 */
@interface TXImageAPNGCoder : TXImageIOAnimatedCoder <SDProgressiveImageCoder, TXAnimatedImageCoder>

@property (nonatomic, class, readonly, nonnull) TXImageAPNGCoder *sharedCoder;

@end
