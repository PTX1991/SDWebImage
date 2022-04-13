/*
 * This file is part of the SDWebImage package.
 * (c) Olivier Poitrey <rs@dailymotion.com>
 * (c) Matt Galloway
 *
 * For the full copyright and license information, please view the LICENSE
 * file that was distributed with this source code.
 */

#import <Foundation/Foundation.h>
#import <SDWebImage/TXWebImageDownloaderOperation.h>

/**
 *  A class that fits the NSOperation+TXWebImageDownloaderOperation requirement so we can test
 */
@interface SDWebImageTestDownloadOperation : NSOperation <TXWebImageDownloaderOperation>

@property (nonatomic, strong, nullable) NSURLRequest *request;
@property (nonatomic, strong, nullable) NSURLResponse *response;

@end
