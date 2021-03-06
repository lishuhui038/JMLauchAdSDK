//
//  UIImageView+JMWebCache.m
//  JMLaunchAdFramework
//
//  Created by JM on 2020/6/17.
//  Copyright © 2020 JM. All rights reserved.
//

#import "UIImageView+JMWebCache.h"
#import "objc/runtime.h"
#import <CommonCrypto/CommonDigest.h>
#import <ImageIO/ImageIO.h>
#import <MobileCoreServices/MobileCoreServices.h>

#ifdef DEBUG
#define DebugLog(...) NSLog(__VA_ARGS__)
#else
#define DebugLog(...)
#endif

static char imageURLKey;


#pragma mark ---缓冲目录
@implementation JMWebImageDownloader

+ (NSString *)cacheImagePath{
    NSString *path =[NSHomeDirectory() stringByAppendingPathComponent:@"Library/JMLaunchAdCache"];
    [self checkDirectory:path];
    return path;
}


#pragma mark - 检查目录
+ (void)checkDirectory:(NSString *)path{
    NSFileManager *fileManager = [NSFileManager defaultManager];
    BOOL isDir;
    if (![fileManager fileExistsAtPath:path isDirectory:&isDir]) { //判断是否为文件夹
        [self createBaseDirectoryAtPath:path];
    } else {
        if (!isDir) {
            NSError *error = nil;
            [fileManager removeItemAtPath:path error:&error];
            [self createBaseDirectoryAtPath:path];
        }
    }
}


#pragma mark - 得到图片缓冲
+(UIImage *)getCacheImageWithURL:(NSURL *)url{
    if(!url) return nil;
    NSString *directoryPath = [self cacheImagePath];
    NSString *path = [NSString stringWithFormat:@"%@/%@",
                      directoryPath,[self md5String:url.absoluteString]];
    return [UIImage jm_gifWithData:[NSData dataWithContentsOfFile:path]];
}


#pragma mark - 刷新图片缓冲
+(void)saveImage:(NSData *)data imageURL:(NSURL *)url{
    NSString *path = [NSString stringWithFormat:@"%@/%@",[self cacheImagePath],[self md5String:url.absoluteString]];
    if (data) {
        BOOL isOk = [[NSFileManager defaultManager] createFileAtPath:path contents:data attributes:nil];
        if (!isOk) DebugLog(@"cache file error for URL: %@", url);
    }
}


#pragma mark - 在目录创建文件
+ (void)createBaseDirectoryAtPath:(NSString *)path {
    __autoreleasing NSError *error = nil;
    [[NSFileManager defaultManager] createDirectoryAtPath:path withIntermediateDirectories:YES
                                               attributes:nil error:&error];
    if (error) {
        DebugLog(@"create cache directory failed, error = %@", error);
    } else {
        DebugLog(@"LaunchAdCachePath:%@",path);
        // 标记无需备份目录
        NSURL *url = [NSURL fileURLWithPath:path];
        NSError *error = nil;
        [url setResourceValue:[NSNumber numberWithBool:YES] forKey:NSURLIsExcludedFromBackupKey error:&error];
        if (error) {
            DebugLog(@"error to set do not backup attribute, error = %@", error);
        }
    }
}


#pragma mark - URL MD5
+ (NSString *)md5String:(NSString *)string {
    if(string == nil || [string length] == 0)  return nil;
    const char *value = [string UTF8String];
    unsigned char outputBuffer[CC_MD5_DIGEST_LENGTH];
    CC_MD5(value, (CC_LONG)strlen(value), outputBuffer);
    NSMutableString *outputString = [[NSMutableString alloc] initWithCapacity:CC_MD5_DIGEST_LENGTH * 2];
    for(NSInteger count = 0; count < CC_MD5_DIGEST_LENGTH; count++){
        [outputString appendFormat:@"%02x",outputBuffer[count]];
    }
    return outputString;
}


@end


#pragma mark ---
@implementation UIImage(GIF)

+ (UIImage *)jm_gifWithData:(NSData *)data{
    if (!data) {
        return nil;
    }
    UIImage *gifImage;
    CGImageSourceRef imgSource = CGImageSourceCreateWithData((CFDataRef)data, NULL);
    if (imgSource == NULL) {
        fprintf(stderr, "Image source is NULL\n");
    } else {
        CFStringRef imgType = CGImageSourceGetType(imgSource);
        // make sure the image's format is GIF
        if ([(__bridge NSString *)imgType isEqualToString:(NSString *)kUTTypeGIF]) {
            // how many frames in the gif image
            size_t frameCount = CGImageSourceGetCount(imgSource);
            NSMutableArray *frames = [NSMutableArray arrayWithCapacity:frameCount];
            NSTimeInterval animationDuration = 0.0;
            for (size_t i = 0; i < frameCount; i++) {
                CFDictionaryRef propertyDic = CGImageSourceCopyPropertiesAtIndex(imgSource, i, NULL);
                // change the animation duration
                CFDictionaryRef gifDic = CFDictionaryGetValue(propertyDic, kCGImagePropertyGIFDictionary);
                CFStringRef delayTimeRef = CFDictionaryGetValue(gifDic, kCGImagePropertyGIFDelayTime);
                animationDuration += [(__bridge NSString *)delayTimeRef doubleValue];
                CFRelease(propertyDic);
                CGImageRef imgRef = CGImageSourceCreateImageAtIndex(imgSource, i, NULL);
                if (imgRef) {
                    [frames addObject:[UIImage imageWithCGImage:imgRef scale:[UIScreen mainScreen].scale orientation:UIImageOrientationUp]];
                    CGImageRelease(imgRef);
                }
            }
            gifImage = [UIImage animatedImageWithImages:frames duration:animationDuration];
        } else {
            gifImage = [[UIImage alloc] initWithData:data];
        }
        CFRelease(imgSource);
    }
    return gifImage;
}

@end


#pragma mark ---
@implementation UIImageView (JMWebCache)


#pragma mark - AssociatedObject
- (NSURL *)jm_imageURL{
    return objc_getAssociatedObject(self, &imageURLKey);
}


#pragma mark - WebCache
- (void)jm_setImageWithURL:(NSURL *)url placeholderImage:(UIImage *)placeholderImage completed:(JMWebImageCompletionBlock)completedBlock{
    [self jm_setImageWithURL:url placeholderImage:placeholderImage options:JMWebImageDefault completed:completedBlock];
}


- (void)jm_setImageWithURL:(NSURL *)url placeholderImage:(UIImage *)placeholderImage options:(JMWebImageOptions)options completed:(JMWebImageCompletionBlock)completedBlock{
    if (placeholderImage) self.image = placeholderImage;
    if (url) {
        __weak typeof(self)weakSelf = self;
        objc_setAssociatedObject(self, &imageURLKey, url, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        if(!options) options = JMWebImageDefault;
        //只加载,不缓存
        if(options&JMWebImageOnlyLoad){
            [self dispatch_async:url result:^(UIImage *image, NSURL *url, NSData *data) {
                weakSelf.image = image;
                if(image&&completedBlock) completedBlock(image, url);
            }];
            return;
        }
        //有缓存,读取缓存,不重新加载,没缓存先加载,并缓存
        UIImage *image = [JMWebImageDownloader getCacheImageWithURL:url];
        if(image&&completedBlock){
            weakSelf.image = image;
            if(image&&completedBlock) completedBlock(image,url);
            if(options&JMWebImageDefault) return;
        }
        //先读缓存,再加载刷新图片和缓存
        [self dispatch_async:url result:^(UIImage *image, NSURL *url, NSData *data) {
            weakSelf.image = image;
            if(image&&completedBlock) completedBlock(image,url);
            [JMWebImageDownloader saveImage:data imageURL:url];
        }];
    }
}


#pragma mark - 异步加载图片
- (void)dispatch_async:(NSURL *)url result:(JMDispatch_asyncBlock)result{
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSData *data = [NSData dataWithContentsOfURL:url];
        UIImage *image = [UIImage jm_gifWithData:data];
        dispatch_async(dispatch_get_main_queue(), ^{
            if (result) result(image,url, data);
        });
    });
}

@end
