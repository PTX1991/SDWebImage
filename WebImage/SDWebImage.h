/*
 * This file is part of the SDWebImage package.
 * (c) Olivier Poitrey <rs@dailymotion.com>
 * (c) Florent Vilmart
 *
 * For the full copyright and license information, please view the LICENSE
 * file that was distributed with this source code.
 */

#import <SDWebImage/TXWebImageCompat.h>

//! Project version number for SDWebImage.
FOUNDATION_EXPORT double SDWebImageVersionNumber;

//! Project version string for SDWebImage.
FOUNDATION_EXPORT const unsigned char SDWebImageVersionString[];

// In this header, you should import all the public headers of your framework using statements like #import <SDWebImage/PublicHeader.h>

#import <SDWebImage/TXWebImageManager.h>
#import <SDWebImage/TXWebImageCacheKeyFilter.h>
#import <SDWebImage/TXWebImageCacheSerializer.h>
#import <SDWebImage/TXImageCacheConfig.h>
#import <SDWebImage/TXImageCache.h>
#import <SDWebImage/TXMemoryCache.h>
#import <SDWebImage/TXDiskCache.h>
#import <SDWebImage/TXImageCacheDefine.h>
#import <SDWebImage/TXImageCachesManager.h>
#import <SDWebImage/UIView+WebCache.h>
#import <SDWebImage/UIImageView+WebCache.h>
#import <SDWebImage/UIImageView+HighlightedWebCache.h>
#import <SDWebImage/TXWebImageDownloaderConfig.h>
#import <SDWebImage/TXWebImageDownloaderOperation.h>
#import <SDWebImage/TXWebImageDownloaderRequestModifier.h>
#import <SDWebImage/TXWebImageDownloaderResponseModifier.h>
#import <SDWebImage/TXWebImageDownloaderDecryptor.h>
#import <SDWebImage/TXImageLoader.h>
#import <SDWebImage/TXImageLoadersManager.h>
#import <SDWebImage/UIButton+WebCache.h>
#import <SDWebImage/TXWebImagePrefetcher.h>
#import <SDWebImage/UIView+WebCacheOperation.h>
#import <SDWebImage/UIImage+Metadata.h>
#import <SDWebImage/UIImage+MultiFormat.h>
#import <SDWebImage/UIImage+MemoryCacheCost.h>
#import <SDWebImage/UIImage+ExtendedCacheData.h>
#import <SDWebImage/TXWebImageOperation.h>
#import <SDWebImage/TXWebImageDownloader.h>
#import <SDWebImage/TXWebImageTransition.h>
#import <SDWebImage/TXWebImageIndicator.h>
#import <SDWebImage/TXImageTransformer.h>
#import <SDWebImage/UIImage+Transform.h>
#import <SDWebImage/TXAnimatedImage.h>
#import <SDWebImage/TXAnimatedImageView.h>
#import <SDWebImage/TXAnimatedImageView+WebCache.h>
#import <SDWebImage/TXAnimatedImagePlayer.h>
#import <SDWebImage/TXImageCodersManager.h>
#import <SDWebImage/TXImageCoder.h>
#import <SDWebImage/TXImageAPNGCoder.h>
#import <SDWebImage/TXImageGIFCoder.h>
#import <SDWebImage/TXImageIOCoder.h>
#import <SDWebImage/TXImageFrame.h>
#import <SDWebImage/TXImageCoderHelper.h>
#import <SDWebImage/TXImageGraphics.h>
#import <SDWebImage/TXGraphicsImageRenderer.h>
#import <SDWebImage/UIImage+GIF.h>
#import <SDWebImage/UIImage+ForceDecode.h>
#import <SDWebImage/NSData+ImageContentType.h>
#import <SDWebImage/TXWebImageDefine.h>
#import <SDWebImage/TXWebImageError.h>
#import <SDWebImage/TXWebImageOptionsProcessor.h>
#import <SDWebImage/TXImageIOAnimatedCoder.h>
#import <SDWebImage/TXImageHEICCoder.h>
#import <SDWebImage/TXImageAWebPCoder.h>

// Mac
#if __has_include(<SDWebImage/NSImage+Compatibility.h>)
#import <SDWebImage/NSImage+Compatibility.h>
#endif
#if __has_include(<SDWebImage/NSButton+WebCache.h>)
#import <SDWebImage/NSButton+WebCache.h>
#endif
#if __has_include(<SDWebImage/TXAnimatedImageRep.h>)
#import <SDWebImage/TXAnimatedImageRep.h>
#endif

// MapKit
#if __has_include(<SDWebImage/MKAnnotationView+WebCache.h>)
#import <SDWebImage/MKAnnotationView+WebCache.h>
#endif
