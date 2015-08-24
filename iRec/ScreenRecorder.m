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
         _pixelBufferLock = [[NSLock alloc] init];
         NSAssert(_pixelBufferLock, @"Why isn't there a pixel buffer lock?!");
         
         [self openFramebuffer];
         [self setupScreenSurface];
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

#pragma mark - Setup Surface

- (void)setupScreenSurface {
    _IOSurface = dlopen("/System/Library/PrivateFrameworks/IOSurface.framework/IOSurface", RTLD_LAZY);
    NSParameterAssert(_IOSurface);
    
    size_t (*IOSurfaceGetBytesPerRow)(IOSurfaceRef buffer) = dlsym(_IOSurface, "IOSurfaceGetBytesPerRow");
    NSParameterAssert(IOSurfaceGetBytesPerRow);
    OSType (*IOSurfaceGetPixelFormat)(IOSurfaceRef buffer) = dlsym(_IOSurface, "IOSurfaceGetPixelFormat");
    NSParameterAssert(IOSurfaceGetPixelFormat);
    
    _bytesPerRow = IOSurfaceGetBytesPerRow(_screenSurface);
    _pixelFormat = IOSurfaceGetPixelFormat(_screenSurface);
}

#pragma mark - Create Surface

- (IOSurfaceRef)createScreenSurface {
    size_t (*IOSurfaceGetBytesPerElement)(IOSurfaceRef buffer) = dlsym(_IOSurface, "IOSurfaceGetBytesPerElement");
    NSParameterAssert(IOSurfaceGetBytesPerElement);
    size_t bytesPerElement = IOSurfaceGetBytesPerElement(_screenSurface);
    
    size_t (*IOSurfaceGetAllocSize)(IOSurfaceRef buffer) = dlsym(_IOSurface, "IOSurfaceGetAllocSize");
    NSParameterAssert(IOSurfaceGetAllocSize);
    size_t allocSize = IOSurfaceGetAllocSize(_screenSurface);
    
    const CFStringRef *kIOSurfaceIsGlobal = dlsym(_IOSurface, "kIOSurfaceIsGlobal");
    NSParameterAssert(*kIOSurfaceIsGlobal);
    const CFStringRef *kIOSurfaceBytesPerElement = dlsym(_IOSurface, "kIOSurfaceBytesPerElement");
    NSParameterAssert(*kIOSurfaceBytesPerElement);
    const CFStringRef *kIOSurfaceAllocSize = dlsym(_IOSurface, "kIOSurfaceAllocSize");
    NSParameterAssert(*kIOSurfaceAllocSize);
    const CFStringRef *kIOSurfaceBytesPerRow = dlsym(_IOSurface, "kIOSurfaceBytesPerRow");
    NSParameterAssert(*kIOSurfaceBytesPerRow);
    const CFStringRef *kIOSurfaceWidth = dlsym(_IOSurface, "kIOSurfaceWidth");
    NSParameterAssert(*kIOSurfaceWidth);
    const CFStringRef *kIOSurfaceHeight = dlsym(_IOSurface, "kIOSurfaceHeight");
    NSParameterAssert(*kIOSurfaceHeight);
    const CFStringRef *kIOSurfacePixelFormat = dlsym(_IOSurface, "kIOSurfacePixelFormat");
    NSParameterAssert(*kIOSurfacePixelFormat);
    const CFStringRef *kIOSurfaceCacheMode = dlsym(_IOSurface, "kIOSurfaceCacheMode");
    NSParameterAssert(*kIOSurfaceCacheMode);
    
    _properties = CFBridgingRetain(@{(__bridge NSString *)*kIOSurfaceIsGlobal:         @YES,
                                     (__bridge NSString *)*kIOSurfaceBytesPerElement:  @(bytesPerElement),
                                     (__bridge NSString *)*kIOSurfaceAllocSize:        @(allocSize),
                                     (__bridge NSString *)*kIOSurfaceBytesPerRow:      @(_bytesPerRow),
                                     (__bridge NSString *)*kIOSurfaceWidth:            @(self.screenWidth),
                                     (__bridge NSString *)*kIOSurfaceHeight:           @(self.screenHeight),
                                     (__bridge NSString *)*kIOSurfacePixelFormat:      @(_pixelFormat),
                                     (__bridge NSString *)*kIOSurfaceCacheMode:        @(kIOMapInhibitCache)
                                     });
    
    IOSurfaceRef (*IOSurfaceCreate)(CFDictionaryRef properties) = dlsym(_IOSurface, "IOSurfaceCreate");
    NSParameterAssert(IOSurfaceCreate);
    return IOSurfaceCreate(_properties);
}

#pragma mark - Initialize Recorder

- (void)setupVideoRecordingObjects {
    NSAssert(_videoWriter, @"There is no video writer...WHAT?!");
    
    //CGAffineTransform playbackTransform;
    //NSAssert(error==nil, @"AVAssetWriter failed to initialize: %@", error);

    [_videoWriter setMovieTimeScale:_framerate];
    
    NSMutableDictionary * compressionProperties = [NSMutableDictionary dictionary];
    [compressionProperties setObject: [NSNumber numberWithInt:_bitrate * 1000] forKey: AVVideoAverageBitRateKey];
    [compressionProperties setObject: [NSNumber numberWithInt:_framerate] forKey: AVVideoMaxKeyFrameIntervalKey];
    [compressionProperties setObject: AVVideoProfileLevelH264HighAutoLevel forKey: AVVideoProfileLevelKey];
    
    NSMutableDictionary *outputSettings = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                                           AVVideoCodecH264, AVVideoCodecKey,
                                           [NSNumber numberWithUnsignedLong:self.screenWidth], AVVideoWidthKey,
                                           [NSNumber numberWithUnsignedLong:self.screenHeight], AVVideoHeightKey,
                                           compressionProperties, AVVideoCompressionPropertiesKey,
                                           nil];
    
    NSAssert([_videoWriter canApplyOutputSettings:outputSettings forMediaType:AVMediaTypeVideo], @"Strange error: AVVideoWriter isn't accepting our output settings.");
    
    _videoWriterInput = [AVAssetWriterInput assetWriterInputWithMediaType:AVMediaTypeVideo outputSettings:outputSettings];
    [_videoWriterInput setMediaTimeScale:_framerate];
    NSAssert([_videoWriter canAddInput:_videoWriterInput], @"Strange error: AVVideoWriter doesn't want our input.");
    [_videoWriter addInput:_videoWriterInput];
    
    NSDictionary *bufferAttributes = [NSDictionary dictionaryWithObjectsAndKeys:
                                      [NSNumber numberWithInt:_pixelFormat], kCVPixelBufferPixelFormatTypeKey,
                                      [NSNumber numberWithUnsignedLong:self.screenWidth], kCVPixelBufferWidthKey,
                                      [NSNumber numberWithUnsignedLong:self.screenHeight], kCVPixelBufferHeightKey,
                                      [NSNumber numberWithUnsignedLong:_bytesPerRow], kCVPixelBufferBytesPerRowAlignmentKey,
                                      kCFAllocatorDefault, kCVPixelBufferMemoryAllocatorKey,
                                      nil];
    
    _pixelBufferAdaptor = [[AVAssetWriterInputPixelBufferAdaptor alloc]initWithAssetWriterInput:_videoWriterInput sourcePixelBufferAttributes:bufferAttributes];
    [_videoWriterInput setExpectsMediaDataInRealTime:YES];
    
    /*
     playbackTransform = CGAffineTransformMakeRotation(DEGREES_TO_RADIANS(90));
     _videoWriterInput.transform = playbackTransform;
     
     AudioChannelLayout acl;
     bzero(&acl, sizeof(acl));
     acl.mChannelLayoutTag = kAudioChannelLayoutTag_Stereo;
     
     NSDictionary*  audioOutputSettings;
     
     audioOutputSettings = [ NSDictionary dictionaryWithObjectsAndKeys: [NSNumber numberWithInt:kAudioFormatMPEG4AAC], AVFormatIDKey,
     [ NSNumber numberWithInt: 2 ], AVNumberOfChannelsKey,
     [ NSNumber numberWithFloat: 44100.0 ], AVSampleRateKey,
     [ NSData dataWithBytes: &acl length: sizeof( acl ) ], AVChannelLayoutKey,
     [ NSNumber numberWithInt: 64000 ], AVEncoderBitRateKey,
     nil];
     
     
     _audioWriterInput = [AVAssetWriterInput assetWriterInputWithMediaType:AVMediaTypeAudio outputSettings:audioOutputSettings];
     
     _audioWriterInput.expectsMediaDataInRealTime = YES;
     
     //\Add inputs to Write
     NSAssert([_videoWriter canAddInput:_audioWriterInput], @"Cannot write to this type of audio input" );
     NSAssert([_videoWriter canAddInput:_audioWriterInput], @"Cannot write to this type of video input" );
     
     [_videoWriter addInput:_audioWriterInput];
     */
    
    [_videoWriter addInput:_videoWriterInput];
    [_videoWriter startWriting];
    [_videoWriter startSessionAtSourceTime:kCMTimeZero];
    
    //NSAssert(_pixelBufferAdaptor.pixelBufferPool, @"There's no pixel buffer pool? Something has gone horribly wrong...");
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
    if (!_screenSurface) {
        _screenSurface = [self createScreenSurface];
        NSAssert(_screenSurface, @"Error creating the IOSurface.");
    }
    
    void *CoreVideo = dlopen("/System/Library/Frameworks/CoreVideo.framework/CoreVideo", RTLD_LAZY);
    NSParameterAssert(CoreVideo);
    kern_return_t (*CVPixelBufferCreateWithIOSurface)(CFAllocatorRef allocator, IOSurfaceRef surface, CFDictionaryRef pixelBufferAttributes, CVPixelBufferRef *pixelBufferOut) = dlsym(CoreVideo, "CVPixelBufferCreateWithIOSurface");
    NSParameterAssert(CVPixelBufferCreateWithIOSurface);

    static CVPixelBufferRef pixelBuffer = NULL;
    CVPixelBufferCreateWithIOSurface(kCFAllocatorDefault, _screenSurface, NULL, &pixelBuffer);
    NSAssert(pixelBuffer, @"Why isn't the pixel buffer created?!");
    dlclose(CoreVideo);
    
    dispatch_async(_videoQueue, ^{
        while(!_videoWriterInput.readyForMoreMediaData)
            usleep(1000);
            [_pixelBufferLock lock];
            [_pixelBufferAdaptor appendPixelBuffer:pixelBuffer withPresentationTime:frame];
            [_pixelBufferLock unlock];
    });
}

#pragma mark - Stop, Finalize Recorder, and Release Objects

- (void)stopRecording {
    NSLog(@"Recorder stopped.");
    [self setRecording:NO];
}

- (void)recordingDone {
    [_videoWriterInput markAsFinished];
    [_videoWriter finishWritingWithCompletionHandler:^{
        dlclose(_IOSurface);
        NSLog(@"Recording saved at path: %@",_videoPath);
    }];
}

#pragma mark - Screen Width & Height

- (NSInteger)screenHeight {
    CGRect screenBounds = [[UIScreen mainScreen] bounds];
    CGFloat screenScale = [[UIScreen mainScreen] scale];
    CGSize screenSize = CGSizeMake((screenBounds.size.width * screenScale), (screenBounds.size.height * screenScale));
    NSInteger screenHeight = screenSize.height;
    return screenHeight;
}

- (NSInteger)screenWidth {
    CGRect screenBounds = [[UIScreen mainScreen] bounds];
    CGFloat screenScale = [[UIScreen mainScreen] scale];
    CGSize screenSize = CGSizeMake((screenBounds.size.width * screenScale), (screenBounds.size.height * screenScale));
    NSInteger screenWidth = screenSize.width;
    return screenWidth;
}

/*

#pragma mark - Cleanup

- (void)dealloc {
    CFRelease(_accelerator);
    CFRelease(_mySurface);
    CFRelease(_mySurfaceAttributes);
    CFRelease((void *)_framebufferConnection);
}
 
*/

@end
