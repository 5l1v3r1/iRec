//
//  NewRecordingViewController.m
//  iRec
//
//  Created by Anthony Agatiello on 2/18/15.
//
//

#import "AppDelegate.h"
#import "NewRecordingViewController.h"
#import "ScreenRecorder.h"
#import "WelcomeViewController.h"
#import "UIAlertView+RSTAdditions.h"
#import "FXBlurView.h"

@implementation NewRecordingViewController {
    BOOL isAudioRec;
    NSString* shareString1;
    NSString* copyString;
}

- (id) init
{
    self = [super init];
    
    if(self != nil)
    {
        shareString1 = @"Record your iOS devices' screen with iRec! itms-services://?action=download-manifest&url=https://emu4ios.net/ESM/iRec.plist";
        copyString = @"Download link: itms-services://?action=download-manifest&url=https://emu4ios.net/ESM/iRec.plist";
    }
    return self;
}

- (id)activityViewControllerPlaceholderItem:(UIActivityViewController *)activityViewController
{
    return shareString1;
    return copyString;
}

- (id)activityViewController:(UIActivityViewController *)activityViewController itemForActivityType:(NSString *)activityType
{
    if([activityType isEqualToString:UIActivityTypeAirDrop])
    {
        return [NSURL URLWithString:@"itms-services://?action=download-manifest&url=https://emu4ios.net/ESM/iRec.plist"];
    }
    if([activityType isEqualToString:UIActivityTypeCopyToPasteboard])
    {
        return copyString;
    }
    else
    {
        return shareString1;
    }
}

- (id)initWithStyle:(UITableViewStyle)style
{
    self = [super initWithStyle:style];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (BOOL)otherMediaIsPlaying {
    FXBlurView *blurView = [[FXBlurView alloc] initWithFrame:CGRectMake(0, 0, [[UIScreen mainScreen] bounds].size.width, [[UIScreen mainScreen] bounds].size.height * 4)];
    [blurView setDynamic:YES];
    blurView.tintColor = [UIColor clearColor];
    blurView.blurRadius = 8;
    
    if ([[AVAudioSession sharedInstance] isOtherAudioPlaying] == YES) {
        goto fail;
    }
    return NO;
    
fail:
    [self.view addSubview:blurView];
    
    UIAlertView *musicAlert = nil;
    NSString *musicAlertText = nil;
    
    if (_recorder != nil) {
        if (_recorder) {
            musicAlertText = @"Other media is currently playing. To save the recording, you must stop the existing audio.";
            musicAlert = [[UIAlertView alloc] initWithTitle:@"3rd Party Audio" message:musicAlertText delegate:self cancelButtonTitle:nil otherButtonTitles:@"Stop Audio", nil];
            [musicAlert showWithSelectionHandler:^(UIAlertView *alertView, NSInteger buttonIndex) {
                if (buttonIndex == 0) {
                    NSError *error = nil;
                    AVAudioSession *audioSession = [AVAudioSession sharedInstance];
                    [audioSession setCategory:AVAudioSessionCategorySoloAmbient error:&error];
                    [audioSession setActive:YES error:&error];
                    [audioSession setActive:NO error:&error];
                    [blurView removeFromSuperview];
                    [self startStopRecording];
                    [[UIApplication sharedApplication] setApplicationIconBadgeNumber:0];
                    [self setButtonTextToNormal];
                }
            }];
        }
    }
    
    if (_recorder == nil) {
        if (!_recorder) {
            musicAlertText = @"Other audio from another source is currently playing from the device. In order for iRec to properly record, the audio must be stopped. Would you like to exit the app, or stop the audio?";
            musicAlert = [[UIAlertView alloc] initWithTitle:@"3rd Party Audio" message:musicAlertText delegate:self cancelButtonTitle:@"Exit" otherButtonTitles:@"Stop Audio", nil];
            [musicAlert showWithSelectionHandler:^(UIAlertView *alertView, NSInteger buttonIndex) {
                if (buttonIndex == 0) {
                    exit(0);
                }
                if (buttonIndex == 1) {
                    NSError *error = nil;
                    AVAudioSession *audioSession = [AVAudioSession sharedInstance];
                    [audioSession setCategory:AVAudioSessionCategorySoloAmbient error:&error];
                    [audioSession setActive:YES error:&error];
                    [audioSession setActive:NO error:&error];
                    [blurView removeFromSuperview];
                    [self startStopRecording];
                    [[UIApplication sharedApplication] setApplicationIconBadgeNumber:1];
                }
            }];
        }
    }
    return YES;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    if ([[userDefaults objectForKey:@"theme_value"] isEqualToString:@"darkTheme"]) {
        _shareButtonOutlet.tintColor = [UIColor whiteColor];
    }
    
    self.isRecording = NO;
    _nameField.userInteractionEnabled = YES;
    [_startStopButton setTitle:@"Start Recording" forState:UIControlStateNormal];
    [_startStopButton setTitleColor:[UIColor colorWithRed:0/255.f green:200/255.f blue:0/255.f alpha:1.0] forState:UIControlStateNormal];
    [_startStopButton setTitleShadowColor:[UIColor colorWithRed:0/255.f green:200/255.f blue:0/255.f alpha:1.0] forState:UIControlStateNormal];
    isAudioRec = NO;
    
    
    if ([[userDefaults objectForKey:@"theme_value"] isEqualToString:@"darkTheme"]) {
        _nameField.keyboardAppearance = UIKeyboardAppearanceDark;
    }
    else {
        _nameField.keyboardAppearance = UIKeyboardAppearanceLight;
    }
}

#pragma mark - UITableViewDelegate Methods

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    
    if (indexPath.section == 1) {
        if (!self.otherMediaIsPlaying) {
            if (_recorder == nil) {
                if (!self.hasValidName)
                    goto deselect;
                    _nameField.userInteractionEnabled = NO;
                    [UIApplication sharedApplication].applicationIconBadgeNumber = 1;
                    [self startStopRecording];
            }
            
            else {
                if (_recorder) {
                    [UIApplication sharedApplication].applicationIconBadgeNumber = 0;
                    [self startStopRecording];
                    [self showMergingAlert];
                    [self mergeAudio];
                    [self performSelector:@selector(setButtonTextToNormal) withObject:nil afterDelay:3.0];
                    [self removeOldVideoFallback];
                }
            }
        }
    }
    
deselect:
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
}

- (void)setTitleAndColorForButton {
    [_startStopButton setTitle:@"Stop Recording" forState:UIControlStateNormal];
    [_startStopButton setTitleColor:[UIColor redColor] forState:UIControlStateNormal];
    [_startStopButton setTitleShadowColor:[UIColor redColor] forState:UIControlStateNormal];
}

- (void)showMergingAlert {
    FXBlurView *blurView = [[FXBlurView alloc] initWithFrame:CGRectMake(0, 0, [[UIScreen mainScreen] bounds].size.width, [[UIScreen mainScreen] bounds].size.height * 4)];
    [blurView setDynamic:YES];
    blurView.tintColor = [UIColor clearColor];
    blurView.blurRadius = 8;
    
    [self.view addSubview:blurView];
    
    UIAlertView *mergingAlert = [[UIAlertView alloc] initWithTitle:@"Saving – Please wait..." message:nil delegate:self cancelButtonTitle:nil otherButtonTitles:nil];
    [mergingAlert show];
    [mergingAlert performSelector:@selector(dismissWithClickedButtonIndex:animated:) withObject:nil afterDelay:3.0];
    if (![userDefaults boolForKey:@"discard_switch"]) {
        [blurView performSelector:@selector(removeFromSuperview) withObject:nil afterDelay:3.0];
    }
}

- (void)setButtonTextToNormal {
    [_startStopButton setTitle:@"Start Recording" forState:UIControlStateNormal];
    [_startStopButton setTitleColor:[UIColor colorWithRed:0/255.f green:200/255.f blue:0/255.f alpha:1.0] forState:UIControlStateNormal];
    [_startStopButton setTitleShadowColor:[UIColor colorWithRed:0/255.f green:200/255.f blue:0/255.f alpha:1.0] forState:UIControlStateNormal];
    _startStopButton.userInteractionEnabled = NO;
    _nameField.userInteractionEnabled = YES;
    self.tabBarController.tabBar.userInteractionEnabled = YES;
    self.tableView.userInteractionEnabled = YES;
    if ([userDefaults boolForKey:@"discard_switch"]) {
        [self showDiscardOrSaveAlert];
    }
    else {
        [_nameField setText:nil];
    }
}

- (void)showDiscardOrSaveAlert {
    UIAlertView *discardSaveAlert = [[UIAlertView alloc] initWithTitle:@"Discard or Save?" message:[NSString stringWithFormat:@"Would you like to discard or save the recording named \"%@\"?", _nameField.text] delegate:self cancelButtonTitle:@"Discard" otherButtonTitles:@"Save", nil];
    
    [discardSaveAlert showWithSelectionHandler:^(UIAlertView *alertView, NSInteger buttonIndex) {
        if (buttonIndex == 0) {
            UIAlertView *confirmationAlert = [[UIAlertView alloc] initWithTitle:@"Confirmation" message:@"Are you sure you want to discard this recording?" delegate:self cancelButtonTitle:@"No" otherButtonTitles:@"Yes", nil];
            
            [confirmationAlert showWithSelectionHandler:^(UIAlertView *alertView, NSInteger buttonIndex) {
                if (buttonIndex == 1) {
                    NSError *error = nil;
                    NSString *videoPath = [documentsDirectory stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.mp4", _nameField.text]];
                    [[NSFileManager defaultManager] removeItemAtPath:videoPath error:&error];
                    [_nameField setText:nil];
                    for (UIView *subView in self.view.subviews) {
                        if ([subView isKindOfClass:[FXBlurView class]]) {
                            [subView removeFromSuperview];
                        }
                    }
                }
                if (buttonIndex == 0) {
                    [self showDiscardOrSaveAlert];
                }
            }];
        }
        if (buttonIndex == 1) {
            for (UIView *subView in self.view.subviews) {
                if ([subView isKindOfClass:[FXBlurView class]]) {
                    [subView removeFromSuperview];
                }
            }
            [_nameField setText:nil];
        }
    }];
}

- (BOOL)hasValidName {
    FXBlurView *blurView = [[FXBlurView alloc] initWithFrame:CGRectMake(0, 0, [[UIScreen mainScreen] bounds].size.width, [[UIScreen mainScreen] bounds].size.height * 4)];
    [blurView setDynamic:YES];
    blurView.tintColor = [UIColor clearColor];
    blurView.blurRadius = 8;
    
    NSString *errorText = nil;
    UIAlertView *failAlert = nil;
    
    if ([[_nameField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] isEqualToString:@""]) {
        errorText = @"Please enter a name for your new recording before continuing.";
        goto fail;
    }
    
    
    else {
        NSFileManager *fileManager = [[NSFileManager alloc] init];
        if ([fileManager fileExistsAtPath:[documentsDirectory stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.mp4", _nameField.text]]]) {
            errorText = @"Please enter a different name, that one has already been taken.";
            goto fail;
        }
    }
    
    return YES;
    
fail:
    
    [self.view addSubview:blurView];
    
    failAlert = [[UIAlertView alloc] initWithTitle:@"Error" message:errorText delegate:self cancelButtonTitle:@"OK" otherButtonTitles:nil];
    [failAlert showWithSelectionHandler:^(UIAlertView *alertView, NSInteger buttonIndex) {
        if (buttonIndex == 0) {
            [blurView removeFromSuperview];
        }
    }];
    
    return NO;
}

- (int)framerate {
    int fps = 0;
    if ([userDefaults objectForKey:@"multi_fps"]) {
        fps = [[userDefaults objectForKey:@"multi_fps"] doubleValue];
    }
    return fps;
}


- (int)bitrate {
    int bitrate = 0;
    if ([userDefaults objectForKey:@"multi_bitrate"]) {
        bitrate = [[userDefaults objectForKey:@"multi_bitrate"] doubleValue];
    }
    return bitrate;
}

- (float)samplerate {
    float samplerate = 0;
    if ([userDefaults objectForKey:@"samplerate_value"]) {
        samplerate = [[userDefaults objectForKey:@"samplerate_value"] floatValue];
    }
    return samplerate;
}

- (int)channels {
    int channels = 0;
    if ([userDefaults objectForKey:@"channels_number"]) {
        channels = [[userDefaults objectForKey:@"channels_number"] doubleValue];
    }
    return channels;
}

#pragma mark - IBActions

- (IBAction)textFieldDidEndEditing:(UITextField *)sender {
    [sender resignFirstResponder];
}

- (IBAction)shareApplication:(UIBarButtonItem *)activityType {
    NewRecordingViewController* item = [[NewRecordingViewController alloc] init];
    UIActivityViewController* activityViewController = [[UIActivityViewController alloc] initWithActivityItems:@[item] applicationActivities:nil];
    
    [self presentViewController:activityViewController animated:YES completion:nil];
    
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad) {
        activityViewController.modalPresentationStyle = UIModalPresentationPopover;
        activityViewController.popoverPresentationController.barButtonItem = activityType;
        activityViewController.popoverPresentationController.permittedArrowDirections = UIPopoverArrowDirectionAny;
    }
}

- (void)startStopRecording
{
    NSString *urlString = [documentsDirectory stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.caf", _nameField.text]];
    NSURL *fileURL = [NSURL fileURLWithPath:urlString];
    
    //If the app is not recording, we want to start recording
    if(!self.isRecording)
    {
        [self setTitleAndColorForButton];
        
        [[UIApplication sharedApplication] setMinimumBackgroundFetchInterval:1];
        _recorder = [[ScreenRecorder alloc] initWithFramerate:self.framerate bitrate:self.bitrate];
        _videoPath = [documentsDirectory stringByAppendingPathComponent:[NSString stringWithFormat:@"%@-1.mp4", _nameField.text]];
        [_recorder startRecording];
        
        NSError *error = nil;
        AVAudioSession *audioSession = [AVAudioSession sharedInstance];
        [audioSession setCategory:AVAudioSessionCategoryPlayAndRecord withOptions:AVAudioSessionCategoryOptionDuckOthers error:&error];
        [audioSession overrideOutputAudioPort:AVAudioSessionPortOverrideSpeaker error:&error];
        [audioSession setActive:YES error:&error];
        
        if (![userDefaults objectForKey:@"showedBlackScreenAlert"]) {
            FXBlurView *blurView = [[FXBlurView alloc] initWithFrame:CGRectMake(0, 0, [[UIScreen mainScreen] bounds].size.width, [[UIScreen mainScreen] bounds].size.height * 4)];
            [blurView setDynamic:YES];
            blurView.tintColor = [UIColor clearColor];
            blurView.blurRadius = 8;
            
            [self.view addSubview:blurView];
            
            UIAlertView *blackScreenAlert = [[UIAlertView alloc] initWithTitle:@"Attention" message:@"In order to record OpenGL content (almost all games), you must enable AssistiveTouch in the default Settings application." delegate:self cancelButtonTitle:@"Don't Show Again" otherButtonTitles:@"OK", nil];
            [blackScreenAlert showWithSelectionHandler:^(UIAlertView *alertView, NSInteger buttonIndex) {
                if (buttonIndex == 0) {
                    [userDefaults setObject:[NSDate date] forKey:@"showedBlackScreenAlert"];
                    [userDefaults synchronize];
                    [blurView removeFromSuperview];
                }
                if (buttonIndex == 1) {
                    [blurView removeFromSuperview];
                }
                if ([userDefaults boolForKey:@"suspend_switch"]) {
                    [AppDelegate suspendApp];
                }
            }];
        }
        else {
            if ([userDefaults boolForKey:@"suspend_switch"]) {
                [AppDelegate suspendApp];
            }
        }
        
        self.isRecording = YES;
        isAudioRec = YES;
        
        NSDictionary *recordSettings = @{AVSampleRateKey:          @(self.samplerate),
                                         AVFormatIDKey:            @(kAudioFormatAppleIMA4),
                                         AVNumberOfChannelsKey:    @(self.channels),
                                         AVEncoderAudioQualityKey: @(AVAudioQualityMax)};
        
        recorder = [[AVAudioRecorder alloc] initWithURL:fileURL settings:recordSettings error:&error];
        [recorder setDelegate:self];
        [recorder prepareToRecord];
        [recorder record];
    }
    //If the app is recording, we want to stop recording
    else
    {
        [[UIApplication sharedApplication] setMinimumBackgroundFetchInterval:1 * 60 * 60 * 24];
        [_delegate newRecordingViewController:self didAddNewRecording:_nameField.text];
        _recording = NO;
        _recorder = nil;
        [recorder stop];
        recorder = nil;
        self.isRecording = NO;
        isAudioRec = NO;
        
        if (!self.otherMediaIsPlaying) {
            NSError *error = nil;
            [[AVAudioSession sharedInstance] setActive:NO error:&error];
        }
    }
}

- (void)mergeAudio {
    double degrees = 0.0;
    if ([userDefaults objectForKey:@"video_orientation"]) {
        if (_screenSize.width > _screenSize.height) {
            degrees = [[userDefaults objectForKey:@"video_orientation"] doubleValue] + 270;
        }
        else {
            degrees = [[userDefaults objectForKey:@"video_orientation"] doubleValue];
        }
        _screenSize = CGSizeMake(0, 0);
    }
    
    NSString *videoPath = [documentsDirectory stringByAppendingPathComponent:[NSString stringWithFormat:@"%@-1.mp4", _nameField.text]];
    NSString *audioPath = [documentsDirectory stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.caf", _nameField.text]];
    
    NSURL *videoURL = [NSURL fileURLWithPath:videoPath];
    NSURL *audioURL = [NSURL fileURLWithPath:audioPath];
    
    NSError *error = nil;
    NSDictionary *options = nil;
    
    AVURLAsset *videoAsset = [AVURLAsset URLAssetWithURL:videoURL options:options];
    AVURLAsset *audioAsset = [AVURLAsset URLAssetWithURL:audioURL options:options];
    
    AVAssetTrack *assetVideoTrack = nil;
    AVAssetTrack *assetAudioTrack = nil;
    
    if ([[NSFileManager defaultManager] fileExistsAtPath:videoPath]) {
        NSArray *assetArray = [videoAsset tracksWithMediaType:AVMediaTypeVideo];
        if ([assetArray count] > 0) {
            assetVideoTrack = assetArray[0];
        }
    }
    
    if ([[NSFileManager defaultManager] fileExistsAtPath:audioPath] && [userDefaults boolForKey:@"switch_audio"]) {
        NSArray *assetArray = [audioAsset tracksWithMediaType:AVMediaTypeAudio];
        if ([assetArray count] > 0) {
            assetAudioTrack = assetArray[0];
        }
    }
    
    AVMutableComposition *mixComposition = [AVMutableComposition composition];
    
    if (assetVideoTrack != nil) {
        AVMutableCompositionTrack *compositionVideoTrack = [mixComposition addMutableTrackWithMediaType:AVMediaTypeVideo preferredTrackID:kCMPersistentTrackID_Invalid];
        [compositionVideoTrack insertTimeRange:CMTimeRangeMake(kCMTimeZero, videoAsset.duration) ofTrack:assetVideoTrack atTime:kCMTimeZero error:&error];
        if (assetAudioTrack != nil) {
            [compositionVideoTrack scaleTimeRange:CMTimeRangeMake(kCMTimeZero, videoAsset.duration) toDuration:audioAsset.duration];
        }
        [compositionVideoTrack setPreferredTransform:CGAffineTransformMakeRotation(degreesToRadians(degrees))];
    }
    
    if (assetAudioTrack != nil) {
        AVMutableCompositionTrack *compositionAudioTrack = [mixComposition addMutableTrackWithMediaType:AVMediaTypeAudio preferredTrackID:kCMPersistentTrackID_Invalid];
        [compositionAudioTrack insertTimeRange:CMTimeRangeMake(kCMTimeZero, audioAsset.duration) ofTrack:assetAudioTrack atTime:kCMTimeZero error:&error];
    }
    
    NSString *exportPath = [documentsDirectory stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.mp4", _nameField.text]];
    NSURL *exportURL = [NSURL fileURLWithPath:exportPath];
    
    AVAssetExportSession *exportSession = [[AVAssetExportSession alloc] initWithAsset:mixComposition presetName:AVAssetExportPresetHighestQuality];
    [exportSession setOutputFileType:AVFileTypeMPEG4];
    [exportSession setOutputURL:exportURL];
    [exportSession setShouldOptimizeForNetworkUse:NO];
    
    [exportSession exportAsynchronouslyWithCompletionHandler:^(void){
        switch (exportSession.status) {
            case AVAssetExportSessionStatusCompleted:{
                NSError *error = nil;
                [[NSFileManager defaultManager] removeItemAtPath:videoPath error:&error];
                [[NSFileManager defaultManager] removeItemAtPath:audioPath error:&error];
                break;
            }
                
            case AVAssetExportSessionStatusFailed:
                NSLog(@"Failed: %@", exportSession.error);
                break;
                
            case AVAssetExportSessionStatusCancelled:
                NSLog(@"Canceled: %@", exportSession.error);
                break;
                
            default:
                break;
        }
    }];
}

- (void)removeOldVideoFallback {
    NSString *oldVideoPath = [documentsDirectory stringByAppendingPathComponent:[NSString stringWithFormat:@"%@-1.mp4", _nameField.text]];
    NSString *newVideoPath = [documentsDirectory stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.mp4", _nameField.text]];
    
    if ([[NSFileManager defaultManager] fileExistsAtPath:oldVideoPath]) {
        NSError *error = nil;
        [[NSFileManager defaultManager] moveItemAtPath:oldVideoPath toPath:newVideoPath error:&error];
    }
}

@end