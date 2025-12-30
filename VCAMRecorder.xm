#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>
#import "VCAMGlobals.h"

@interface VCAMRecorder : NSObject
+ (void)startRecording;
+ (void)stopRecording;
@end

@implementation VCAMRecorder
static AVAssetWriter *writer = nil;
static AVAssetWriterInput *input = nil;

+ (void)startRecording {
    if (writer) return;

    NSString *path = [NSTemporaryDirectory() stringByAppendingPathComponent:@"vcam_output.mp4"];
    writer = [AVAssetWriter assetWriterWithURL:[NSURL fileURLWithPath:path] fileType:AVFileTypeMPEG4 error:nil];

    input = [AVAssetWriterInput assetWriterInputWithMediaType:AVMediaTypeVideo outputSettings:@{
        AVVideoCodecKey: AVVideoCodecTypeH264,
        AVVideoWidthKey: @(UIScreen.mainScreen.bounds.size.width),
        AVVideoHeightKey: @(UIScreen.mainScreen.bounds.size.height)
    }];

    [writer addInput:input];
    [writer startWriting];
    [writer startSessionAtSourceTime:kCMTimeZero];
}

+ (void)stopRecording {
    [input markAsFinished];
    [writer finishWritingWithCompletionHandler:^{
        NSLog(@"[VCAMRecorder] Recording saved to %@", writer.outputURL);
        writer = nil;
        input = nil;
    }];
}
@end
