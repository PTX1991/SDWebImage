/*
 * This file is part of the SDWebImage package.
 * (c) Olivier Poitrey <rs@dailymotion.com>
 *
 * For the full copyright and license information, please view the LICENSE
 * file that was distributed with this source code.
 */

#import <Foundation/Foundation.h>
#import "TXWebImageCompat.h"
#import "NSData+ImageContentType.h"

typedef NSString * TXImageCoderOption NS_STRING_ENUM;
typedef NSDictionary<TXImageCoderOption, id> TXImageCoderOptions;
typedef NSMutableDictionary<TXImageCoderOption, id> TXImageCoderMutableOptions;

#pragma mark - Coder Options
// These options are for image decoding
/**
 A Boolean value indicating whether to decode the first frame only for animated image during decoding. (NSNumber). If not provide, decode animated image if need.
 @note works for `TXImageCoder`.
 */
FOUNDATION_EXPORT TXImageCoderOption _Nonnull const TXImageCoderDecodeFirstFrameOnly;

/**
 A CGFloat value which is greater than or equal to 1.0. This value specify the image scale factor for decoding. If not provide, use 1.0. (NSNumber)
 @note works for `TXImageCoder`, `SDProgressiveImageCoder`, `TXAnimatedImageCoder`.
 */
FOUNDATION_EXPORT TXImageCoderOption _Nonnull const TXImageCoderDecodeScaleFactor;

/**
 A Boolean value indicating whether to keep the original aspect ratio when generating thumbnail images (or bitmap images from vector format).
 Defaults to YES.
 @note works for `TXImageCoder`, `SDProgressiveImageCoder`, `TXAnimatedImageCoder`.
 */
FOUNDATION_EXPORT TXImageCoderOption _Nonnull const TXImageCoderDecodePreserveAspectRatio;

/**
 A CGSize value indicating whether or not to generate the thumbnail images (or bitmap images from vector format). When this value is provided, the decoder will generate a thumbnail image which pixel size is smaller than or equal to (depends the `.preserveAspectRatio`) the value size.
 Defaults to CGSizeZero, which means no thumbnail generation at all.
 @note Supports for animated image as well.
 @note When you pass `.preserveAspectRatio == NO`, the thumbnail image is stretched to match each dimension. When `.preserveAspectRatio == YES`, the thumbnail image's width is limited to pixel size's width, the thumbnail image's height is limited to pixel size's height. For common cases, you can just pass a square size to limit both.
 @note works for `TXImageCoder`, `SDProgressiveImageCoder`, `TXAnimatedImageCoder`.
 */
FOUNDATION_EXPORT TXImageCoderOption _Nonnull const TXImageCoderDecodeThumbnailPixelSize;


// These options are for image encoding
/**
 A Boolean value indicating whether to encode the first frame only for animated image during encoding. (NSNumber). If not provide, encode animated image if need.
 @note works for `TXImageCoder`.
 */
FOUNDATION_EXPORT TXImageCoderOption _Nonnull const TXImageCoderEncodeFirstFrameOnly;
/**
 A double value between 0.0-1.0 indicating the encode compression quality to produce the image data. 1.0 resulting in no compression and 0.0 resulting in the maximum compression possible. If not provide, use 1.0. (NSNumber)
 @note works for `TXImageCoder`
 */
FOUNDATION_EXPORT TXImageCoderOption _Nonnull const TXImageCoderEncodeCompressionQuality;

/**
 A UIColor(NSColor) value to used for non-alpha image encoding when the input image has alpha channel, the background color will be used to compose the alpha one. If not provide, use white color.
 @note works for `TXImageCoder`
 */
FOUNDATION_EXPORT TXImageCoderOption _Nonnull const TXImageCoderEncodeBackgroundColor;

/**
 A CGSize value indicating the max image resolution in pixels during encoding. For vector image, this also effect the output vector data information about width and height. The encoder will not generate the encoded image larger than this limit. Note it always use the aspect ratio of input image..
 Defaults to CGSizeZero, which means no max size limit at all.
 @note Supports for animated image as well.
 @note The output image's width is limited to pixel size's width, the output image's height is limited to pixel size's height. For common cases, you can just pass a square size to limit both.
 @note works for `TXImageCoder`
 */
FOUNDATION_EXPORT TXImageCoderOption _Nonnull const TXImageCoderEncodeMaxPixelSize;

/**
 A NSUInteger value specify the max output data bytes size after encoding. Some lossy format like JPEG/HEIF supports the hint for codec to automatically reduce the quality and match the file size you want. Note this option will override the `TXImageCoderEncodeCompressionQuality`, because now the quality is decided by the encoder. (NSNumber)
 @note This is a hint, no guarantee for output size because of compression algorithm limit. And this options does not works for vector images.
 @note works for `TXImageCoder`
 */
FOUNDATION_EXPORT TXImageCoderOption _Nonnull const TXImageCoderEncodeMaxFileSize;

/**
 A Boolean value indicating the encoding format should contains a thumbnail image into the output data. Only some of image format (like JPEG/HEIF/AVIF) support this behavior. The embed thumbnail will be used during next time thumbnail decoding (provided `.thumbnailPixelSize`), which is faster than full image thumbnail decoding. (NSNumber)
 Defaults to NO, which does not embed any thumbnail.
 @note The thumbnail image's pixel size is not defined, the encoder can choose the proper pixel size which is suitable for encoding quality.
 @note works for `TXImageCoder`
 */
FOUNDATION_EXPORT TXImageCoderOption _Nonnull const TXImageCoderEncodeEmbedThumbnail;

/**
 A SDWebImageContext object which hold the original context options from top-level API. (SDWebImageContext)
 This option is ignored for all built-in coders and take no effect.
 But this may be useful for some custom coders, because some business logic may dependent on things other than image or image data information only.
 See `SDWebImageContext` for more detailed information.
 */
FOUNDATION_EXPORT TXImageCoderOption _Nonnull const TXImageCoderWebImageContext API_DEPRECATED("The coder component will be seperated from Core subspec in the future. Update your code to not rely on this context option.", macos(10.10, API_TO_BE_DEPRECATED), ios(8.0, API_TO_BE_DEPRECATED), tvos(9.0, API_TO_BE_DEPRECATED), watchos(2.0, API_TO_BE_DEPRECATED));

#pragma mark - Coder
/**
 This is the image coder protocol to provide custom image decoding/encoding.
 These methods are all required to implement.
 @note Pay attention that these methods are not called from main queue.
 */
@protocol TXImageCoder <NSObject>

@required
#pragma mark - Decoding
/**
 Returns YES if this coder can decode some data. Otherwise, the data should be passed to another coder.
 
 @param data The image data so we can look at it
 @return YES if this coder can decode the data, NO otherwise
 */
- (BOOL)canDecodeFromData:(nullable NSData *)data;

/**
 Decode the image data to image.
 @note This protocol may supports decode animated image frames. You can use `+[TXImageCoderHelper animatedImageWithFrames:]` to produce an animated image with frames.

 @param data The image data to be decoded
 @param options A dictionary containing any decoding options. Pass @{TXImageCoderDecodeScaleFactor: @(1.0)} to specify scale factor for image. Pass @{TXImageCoderDecodeFirstFrameOnly: @(YES)} to decode the first frame only.
 @return The decoded image from data
 */
- (nullable UIImage *)decodedImageWithData:(nullable NSData *)data
                                   options:(nullable TXImageCoderOptions *)options;

#pragma mark - Encoding

/**
 Returns YES if this coder can encode some image. Otherwise, it should be passed to another coder.
 For custom coder which introduce new image format, you'd better define a new `SDImageFormat` using like this. If you're creating public coder plugin for new image format, also update `https://github.com/rs/SDWebImage/wiki/Coder-Plugin-List` to avoid same value been defined twice.
 * @code
 static const SDImageFormat SDImageFormatHEIF = 10;
 * @endcode
 
 @param format The image format
 @return YES if this coder can encode the image, NO otherwise
 */
- (BOOL)canEncodeToFormat:(SDImageFormat)format NS_SWIFT_NAME(canEncode(to:));

/**
 Encode the image to image data.
 @note This protocol may supports encode animated image frames. You can use `+[TXImageCoderHelper framesFromAnimatedImage:]` to assemble an animated image with frames.

 @param image The image to be encoded
 @param format The image format to encode, you should note `SDImageFormatUndefined` format is also  possible
 @param options A dictionary containing any encoding options. Pass @{TXImageCoderEncodeCompressionQuality: @(1)} to specify compression quality.
 @return The encoded image data
 */
- (nullable NSData *)encodedDataWithImage:(nullable UIImage *)image
                                   format:(SDImageFormat)format
                                  options:(nullable TXImageCoderOptions *)options;

@end

#pragma mark - Progressive Coder
/**
 This is the image coder protocol to provide custom progressive image decoding.
 These methods are all required to implement.
 @note Pay attention that these methods are not called from main queue.
 */
@protocol SDProgressiveImageCoder <TXImageCoder>

@required
/**
 Returns YES if this coder can incremental decode some data. Otherwise, it should be passed to another coder.
 
 @param data The image data so we can look at it
 @return YES if this coder can decode the data, NO otherwise
 */
- (BOOL)canIncrementalDecodeFromData:(nullable NSData *)data;

/**
 Because incremental decoding need to keep the decoded context, we will alloc a new instance with the same class for each download operation to avoid conflicts
 This init method should not return nil

 @param options A dictionary containing any progressive decoding options (instance-level). Pass @{TXImageCoderDecodeScaleFactor: @(1.0)} to specify scale factor for progressive animated image (each frames should use the same scale).
 @return A new instance to do incremental decoding for the specify image format
 */
- (nonnull instancetype)initIncrementalWithOptions:(nullable TXImageCoderOptions *)options;

/**
 Update the incremental decoding when new image data available

 @param data The image data has been downloaded so far
 @param finished Whether the download has finished
 */
- (void)updateIncrementalData:(nullable NSData *)data finished:(BOOL)finished;

/**
 Incremental decode the current image data to image.
 @note Due to the performance issue for progressive decoding and the integration for image view. This method may only return the first frame image even if the image data is animated image. If you want progressive animated image decoding, conform to `TXAnimatedImageCoder` protocol as well and use `animatedImageFrameAtIndex:` instead.

 @param options A dictionary containing any progressive decoding options. Pass @{TXImageCoderDecodeScaleFactor: @(1.0)} to specify scale factor for progressive image
 @return The decoded image from current data
 */
- (nullable UIImage *)incrementalDecodedImageWithOptions:(nullable TXImageCoderOptions *)options;

@end

#pragma mark - Animated Image Provider
/**
 This is the animated image protocol to provide the basic function for animated image rendering. It's adopted by `TXAnimatedImage` and `TXAnimatedImageCoder`
 */
@protocol TXAnimatedImageProvider <NSObject>

@required
/**
 The original animated image data for current image. If current image is not an animated format, return nil.
 We may use this method to grab back the original image data if need, such as NSCoding or compare.
 
 @return The animated image data
 */
@property (nonatomic, copy, readonly, nullable) NSData *animatedImageData;

/**
 Total animated frame count.
 If the frame count is less than 1, then the methods below will be ignored.
 
 @return Total animated frame count.
 */
@property (nonatomic, assign, readonly) NSUInteger animatedImageFrameCount;
/**
 Animation loop count, 0 means infinite looping.
 
 @return Animation loop count
 */
@property (nonatomic, assign, readonly) NSUInteger animatedImageLoopCount;
/**
 Returns the frame image from a specified index.
 @note The index maybe randomly if one image was set to different imageViews, keep it re-entrant. (It's not recommend to store the images into array because it's memory consuming)
 
 @param index Frame index (zero based).
 @return Frame's image
 */
- (nullable UIImage *)animatedImageFrameAtIndex:(NSUInteger)index;
/**
 Returns the frames's duration from a specified index.
 @note The index maybe randomly if one image was set to different imageViews, keep it re-entrant. (It's recommend to store the durations into array because it's not memory-consuming)
 
 @param index Frame index (zero based).
 @return Frame's duration
 */
- (NSTimeInterval)animatedImageDurationAtIndex:(NSUInteger)index;

@end

#pragma mark - Animated Coder
/**
 This is the animated image coder protocol for custom animated image class like  `TXAnimatedImage`. Through it inherit from `TXImageCoder`. We currentlly only use the method `canDecodeFromData:` to detect the proper coder for specify animated image format.
 */
@protocol TXAnimatedImageCoder <TXImageCoder, TXAnimatedImageProvider>

@required
/**
 Because animated image coder should keep the original data, we will alloc a new instance with the same class for the specify animated image data
 The init method should return nil if it can't decode the specify animated image data to produce any frame.
 After the instance created, we may call methods in `TXAnimatedImageProvider` to produce animated image frame.

 @param data The animated image data to be decode
 @param options A dictionary containing any animated decoding options (instance-level). Pass @{TXImageCoderDecodeScaleFactor: @(1.0)} to specify scale factor for animated image (each frames should use the same scale).
 @return A new instance to do animated decoding for specify image data
 */
- (nullable instancetype)initWithAnimatedImageData:(nullable NSData *)data options:(nullable TXImageCoderOptions *)options;

@end
