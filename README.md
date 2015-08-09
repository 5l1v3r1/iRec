### iRec - iOS 7-8 Screen Recorder  

![ScreenShot](https://pbs.twimg.com/media/CATNEPXWQAAJWSt.jpg)

####Setup

Run the following commands in terminal:  
* Only run if Cocoapods is not already installed:  
<code>sudo gem install cocoapods</code>   
* Change the directory to where the project is located by dragging the folder onto the terminal window:  
<code>cd path-to-project</code>  
* Install the Pods:  
<code>pod install</code>  

Now just launch the iRec.xcworkspace file, and compile as normal!

####NOTE: As of commit 8d256dd, the (old) setup and the steps below are no longer needed! Please follow the instructions above instead.

To install and deploy iRec to your device through Xcode, you must find and setup the PrivateFramework headers for IOKit, IOSurface, CoreSurface, and IOMobileFramebuffer (64-bit-safe version), and place them in the framework. I cannot provide these files in the project, due to legal reasons. However, you may grab the first two here:  
https://github.com/rpetrich/iphoneheaders (download the entire repository).

The third one here (you may right click the link as select "Download Linked File", and it will save to your downloads folder):  
http://denemo.org/~jjbenham/iphone-dev-read-only/include/include/CoreSurface/CoreSurface.h

And the last one from here:  
https://gist.github.com/nevyn/9486278

Once you have the correct files, you may watch this video for instructions on how to import these frameworks into the project:  
https://www.youtube.com/watch?v=OLX7b_KZIvg

Once that is complete, you must do a couple extra steps.

1.) Navigate to the theos headers folder that you downloaded (first link).  
2.) Copy the "Availability2.h" file and place it in this directory (copy the following directory, without quotes, then open a Finder window, select "Go" from the menu bar, and then "Go to Folder..."): <code>/Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS.sdk/usr/include</code>  
3.) Open a Finder window, select "Go" from the menu bar, and then "Go to Folder..." again. Now, enter this directory:
<code>/usr/include</code>. This is the system include folder. Copy the "launch.h" file and the "xpc" folder. Place it in the directory that was used in step 2, the SDK include folder.  
4.) "Go to Folder..." one last time, and enter this directory:  
<code>/System/Library/Frameworks/IOSurface.framework/Versions/A/Headers</code>, and copy the IOSurfaceAPI.h file. Now, place it in the IOSurface framework located in the SDK.  
5.) Open the Xcode Project, and go to the dropdown for IOSurface.framework --> Headers --> IOSurfaceAPI.h. After this line (without quotes):  
<code>#include IOKit/IOKitLib.h</code>    
Add this line (without quotes):  
<code>#include xpc/xpc.h</code>  

####Note: You must place brackets "<>" between IOKit/IOKitLib.h and xpc/xpc.h

After you have done this, iRec should successfully compile! Thank you for your interest in iRec.  

####Apple Watch Support  

![ScreenShot](https://pbs.twimg.com/media/CGVpWsNUAAAczLT.jpg)  
![ScreenShot](https://pbs.twimg.com/media/CGXCF2WUcAA_bGO.jpg)  

iRec v1.2 and above now has support for the Apple Watch! You can remotely start recording from your watch, see how long you've been recording for, and customize more settings, directly from the Apple Watch app on your iPhone (see photo below).  

![ScreenShot](https://pbs.twimg.com/media/CGVpWrbUYAABI8f.jpg:large)  

####Known Issues  

* If you are running iOS 8.3 or above, the resulting recording may freeze on a random frame at times, and then start recording again.  
* Apple Watch remote does not work yet, it is only a GUI.
* On iOS 9 devices, the app crashes when you start recording.

Copyright © 2015 Anthony Agatiello