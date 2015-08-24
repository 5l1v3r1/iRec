//
//  ScreenRecorder.m
//  iRec
//
//  Created by Anthony Agatiello on 2/18/15.
//
//

#import "ScreenRecorder.h"
#include <sys/time.h>
#include <dlfcn.h>
#include <mach/mach.h>

@implementation ScreenRecorder

#pragma mark - Initialization

- (instancetype)initWithFramerate:(CGFloat)framerate bitrate:(CGFloat)bitrate {
     if ((self = [super init])) {
         _framerate = framerate;
         _bitrate = bitrate;
         _videoQueue = dispatch_queue_create("video_queue", DISPATCH_QUEUE_SERIAL);
         NSAssert(_videoQueue, @"Unable to create video queue.");
         
         [self openFramebuffer];
    }
    return self;
}

#pragma mark - Open Framebuffer

- (void)openFramebuffer {
    void *IOKit = dlopen("/System/Library/Frameworks/IOKit.framework/Versions/A/IOKit", RTLD_LAZY);
    NSParameterAssert(IOKit);
    void *IOMobileFramebuffer = dlopen("/System/Library/PrivateFrameworks/IOMobileFramebuffer.framework/IOMobileFramebuffer", RTLD_LAZY);
    NSParameterAssert(IOMobileFramebuffer);
    
    mach_port_t *kIOMasterPortDefault = dlsym(IOKit, "kIOMasterPortDefault");
    NSParameterAssert(kIOMasterPortDefault);
    CFMutableDictionaryRef (*IOServiceMatching)(const char *name) = dlsym(IOKit, "IOServiceMatching");
    NSParameterAssert(IOServiceMatching);
    mach_port_t (*IOServiceGetMatchingService)(mach_port_t masterPort, CFDictionaryRef matching) = dlsym(IOKit, "IOServiceGetMatchingService");
    NSParameterAssert(IOServiceGetMatchingService);
    
    mach_port_t serviceMatching = IOServiceGetMatchingService(*kIOMasterPortDefault, IOServiceMatching("AppleCLCD"));
    if (!serviceMatching)
        serviceMatching = IOServiceGetMatchingService(*kIOMasterPortDefault, IOServiceMatching("AppleH1CLCD"));
    if (!serviceMatching)
        serviceMatching = IOServiceGetMatchingService(*kIOMasterPortDefault, IOServiceMatching("AppleM2CLCD"));
    if (!serviceMatching)
        serviceMatching = IOServiceGetMatchingService(*kIOMasterPortDefault, IOServiceMatching("AppleRGBOUT"));
    if (!serviceMatching)
        serviceMatching = IOServiceGetMatchingService(*kIOMasterPortDefault, IOServiceMatching("AppleMX31IPU"));
    if (!serviceMatching)
        serviceMatching = IOServiceGetMatchingService(*kIOMasterPortDefault, IOServiceMatching("AppleMobileCLCD"));
    if (!serviceMatching)
        serviceMatching = IOServiceGetMatchingService(*kIOMasterPortDefault, IOServiceMatching("IOMobileFramebuffer"));
    
    NSAssert(serviceMatching, @"Unable to get IOService matching display types.");
    
    mach_port_t *mach_task_self_ = dlsym(IOKit, "mach_task_self_");
    NSParameterAssert(*mach_task_self_);
    kern_return_t (*IOMobileFramebufferOpen)(mach_port_t service, task_port_t owningTask, unsigned int type, IOMobileFramebufferConnection *connection) = dlsym(IOMobileFramebuffer, "IOMobileFramebufferOpen");
    NSParameterAssert(IOMobileFramebufferOpen);
    kern_return_t (*IOMobileFramebufferGetMainDisplay)(IOMobileFramebufferConnection *connection) = dlsym(IOMobileFramebuffer, "IOMobileFramebufferGetMainDisplay");
    NSParameterAssert(IOMobileFramebufferGetMainDisplay);
    kern_return_t (*IOMobileFramebufferGetLayerDefaultSurface)(IOMobileFramebufferConnection connection, int surface, IOSurfaceRef *buffer) = dlsym(IOMobileFramebuffer, "IOMobileFramebufferGetLayerDefaultSurface");
    NSParameterAssert(IOMobileFramebufferGetLayerDefaultSurface);
    kern_return_t (*IOServiceClose)(mach_port_t service) = dlsym(IOKit, "IOServiceClose");
    NSParameterAssert(IOServiceClose);
    kern_return_t (*IOConnectRelease)(IOMobileFramebufferConnection connection) = dlsym(IOKit, "IOConnectRelease");
    NSParameterAssert(IOConnectRelease);
    kern_return_t (*IOServiceAuthorize)(mach_port_t service, uint32_t options) = dlsym(IOKit, "IOServiceAuthorize");
    
    if (IOServiceAuthorize) {
        NSParameterAssert(IOServiceAuthorize);
        IOServiceAuthorize(serviceMatching, kIOServiceInteractionAllowed);
    }
    
    IOMobileFramebufferOpen(serviceMatching, *mach_task_self_, 0, &_framebufferConnection);
    IOMobileFramebufferGetMainDisplay(&_framebufferConnection);
    IOMobileFramebufferGetLayerDefaultSurface(_framebufferConnection, 0, &_screenSurface);
    
    IOServiceClose(serviceMatching);
    IOConnectRelease(_framebufferConnection);
    
    dlclose(IOKit);
    dlclose(IOMobileFramebuffer);
}

#pragma mark - Initialize Recorder

- (void)setupVideoRecordingObjects {
    NSAssert(_videoWriter, @"There is no video writer...WHAT?!");
    [_videoWriter setMovieTimeScale:_framerate];
    
    NSMutableDictionary * compressionProperties = [NSMutableDictionary dictionary];
    [compressionProperties setObject: [NSNumber numberWithInt:_bitrate * 1000] forKey: AVVideoAverageBitRateKey];
    [compressionProperties setObject: [NSNumber numberWithInt:_framerate] forKey: AVVideoMaxKeyFrameIntervalKey];
    [compressionProperties setObject: AVVideoProfileLevelH264HighAutoLevel forKey: AVVideoProfileLevelKey];
    
    CGRect screenBounds = [[UIScreen mainScreen] bounds];
    CGFloat screenScale = [[UIScreen mainScreen] scale];
    CGSize screenSize = CGSizeMake((screenBounds.size.width * screenScale), (screenBounds.size.height * screenScale));
    
    NSInteger screenWidth = screenSize.width;
    NSInteger screenHeight = screenSize.height;
    
    NSMutableDictionary *outputSettings = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                                           AVVideoCodecH264, AVVideoCodecKey,
                                           [NSNumber numberWithUnsignedLong:screenWidth], AVVideoWidthKey,
                                           [NSNumber numberWithUnsignedLong:screenHeight], AVVideoHeightKey,
                                           compressionProperties, AVVideoCompressionPropertiesKey,
                                           nil];
    
    NSAssert([_videoWriter canApplyOutputSettings:outputSettings forMediaType:AVMediaTypeVideo], @"Strange error: AVVideoWriter isn't accepting our output settings.");
    
    _videoWriterInput = [AVAssetWriterInput assetWriterInputWithMediaType:AVMediaTypeVideo outputSettings:outputSettings];
    [_videoWriterInput setMediaTimeScale:_framerate];
    NSAssert([_videoWriter canAddInput:_videoWriterInput], @"Strange error: AVVideoWriter doesn't want our input.");
    [_videoWriter addInput:_videoWriterInput];
    
    size_t bytesPerRow = CVPixelBufferGetBytesPerRow(_pixelBuffer);
    OSType pixelFormat = CVPixelBufferGetPixelFormatType(_pixelBuffer);
    
    NSDictionary *bufferAttributes = [NSDictionary dictionaryWithObjectsAndKeys:
                                      [NSNumber numberWithInt:pixelFormat], kCVPixelBufferPixelFormatTypeKey,
                                      [NSNumber numberWithUnsignedLong:screenWidth], kCVPixelBufferWidthKey,
                                      [NSNumber numberWithUnsignedLong:screenHeight], kCVPixelBufferHeightKey,
                                      [NSNumber numberWithUnsignedLong:bytesPerRow], kCVPixelBufferBytesPerRowAlignmentKey,
                                      kCFAllocatorDefault, kCVPixelBufferMemoryAllocatorKey,
                                      nil];
    
    _pixelBufferAdaptor = [[AVAssetWriterInputPixelBufferAdaptor alloc]initWithAssetWriterInput:_videoWriterInput sourcePixelBufferAttributes:bufferAttributes];
    [_videoWriterInput setExpectsMediaDataInRealTime:YES];
    
    [_videoWriter addInput:_videoWriterInput];
    [_videoWriter startWriting];
    [_videoWriter startSessionAtSourceTime:kCMTimeZero];
}

#pragma mark - Start Recording

- (void)startRecording {
    NSError *error = nil;
    _videoWriter = [[AVAssetWriter alloc] initWithURL:[NSURL fileURLWithPath:_videoPath] fileType:AVFileTypeMPEG4 error:&error];
    
    //Better safe than sorry
    NSAssert(_videoPath, @"You're telling me to record but not where to put the result. How am I supposed to know where to put this frickin' video? :(");
    NSAssert(!_recording, @"Trying to start recording, but we're already recording?!!?!");
    
    [self setupVideoRecordingObjects];
    _recording = YES;
    
    NSLog(@"Recorder started.");
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        struct timeval currentTime, lastSnapshot;
        lastSnapshot.tv_sec = lastSnapshot.tv_usec = 0;
        unsigned int frame = 0;
        int msBeforeNextCapture = 1000 / _framerate;
        
        while (_recording) {
            gettimeofday(&currentTime, NULL);
            currentTime.tv_usec /= 1000;
            unsigned long long delta = ((1000 * currentTime.tv_sec + currentTime.tv_usec) - (1000 * lastSnapshot.tv_sec + lastSnapshot.tv_usec));
            
            if (delta >= msBeforeNextCapture) {
                CMTime presentTime = CMTimeMake(frame, _framerate);
                [self saveFrame:presentTime];
                frame++;
                lastSnapshot = currentTime;
            }
        }
        dispatch_async(_videoQueue, ^{
            [self recordingDone];
        });
    });
}

#pragma mark - Capture Frame

- (void)saveFrame:(CMTime)frame {
    void *CoreVideo = dlopen("/System/Library/Frameworks/CoreVideo.framework/CoreVideo", RTLD_LAZY);
    NSParameterAssert(CoreVideo);
    IOSurfaceRef (*CVPixelBufferGetIOSurface)(CVPixelBufferRef pixelBuffer) = dlsym(CoreVideo, "CVPixelBufferGetIOSurface");
    NSParameterAssert(CVPixelBufferGetIOSurface);
    
    if (!_screenSurface) {
        _screenSurface = CVPixelBufferGetIOSurface(_pixelBuffer);
        NSAssert(_screenSurface, @"Error creating the IOSurface.");
    }
    
    CVReturn (*CVPixelBufferCreateWithIOSurface)(CFAllocatorRef allocator, IOSurfaceRef surface, CFDictionaryRef pixelBufferAttributes, CVPixelBufferRef *pixelBufferOut) = dlsym(CoreVideo, "CVPixelBufferCreateWithIOSurface");
    NSParameterAssert(CVPixelBufferCreateWithIOSurface);

    CFDictionaryRef bufferAttributes = CFBridgingRetain(@{(id)kCVPixelBufferIOSurfacePropertiesKey : @{}});
    CVPixelBufferCreateWithIOSurface(kCFAllocatorDefault, _screenSurface, bufferAttributes, &_pixelBuffer);
    NSAssert(_pixelBuffer, @"Why isn't the pixel buffer created?!");
    dlclose(CoreVideo);
    
    NSLock *pixelBufferLock = [[NSLock alloc] init];
    NSAssert(pixelBufferLock, @"Why isn't there a pixel buffer lock?!");
    
    dispatch_async(_videoQueue, ^{
        while(!_videoWriterInput.readyForMoreMediaData)
            usleep(1000);
            [pixelBufferLock lock];
            [_pixelBufferAdaptor appendPixelBuffer:_pixelBuffer withPresentationTime:frame];
            [pixelBufferLock unlock];
    });
}

#pragma mark - Stop & Finalize Recorder

- (void)stopRecording {
    NSLog(@"Recorder stopped.");
    [self setRecording:NO];
}

- (void)recordingDone {
    [_videoWriterInput markAsFinished];
    [_videoWriter finishWritingWithCompletionHandler:^{}];
}

#pragma mark - Release Objects

- (void)dealloc {
    CFRelease(_screenSurface);
    _screenSurface = NULL;
    CFRelease(_framebufferConnection);
    _framebufferConnection = NULL;
    CVPixelBufferRelease(_pixelBuffer);
    _pixelBuffer = NULL;
    _videoWriter = nil;
    _videoWriterInput = nil;
    _pixelBufferAdaptor = nil;
    _videoQueue = nil;
    _videoPath = nil;
}

@end
