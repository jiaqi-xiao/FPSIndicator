#import <notify.h>
#import <substrate.h>
#import <libcolorpicker.h>
#import <objc/runtime.h>
#include <dlfcn.h>



enum FPSMode{
	kModeAverage=1,
	kModePerSecond,
	kModeRenderFrame,
};

static BOOL enabled;
static enum FPSMode fpsMode;

static dispatch_source_t _timer;
static UILabel *fpsLabel;

static void loadPref(){
	NSLog(@"loadPref..........");
	NSMutableDictionary *prefs = [[NSMutableDictionary alloc] initWithContentsOfFile:kPrefPath];

	enabled=prefs[@"enabled"]?[prefs[@"enabled"] boolValue]:YES;
	fpsMode=prefs[@"fpsMode"]?[prefs[@"fpsMode"] intValue]:0;
	if(fpsMode==0) fpsMode++; //0.0.2 compatibility 

	NSString *colorString = prefs[@"color"]?:@"#ffff00"; 
    UIColor *color = LCPParseColorString(colorString, nil);

	[fpsLabel setHidden:!enabled];
	[fpsLabel setTextColor:color];

}
static BOOL isEnabledApp(){
	NSString* bundleIdentifier=[[NSBundle mainBundle] bundleIdentifier];
	NSMutableDictionary *prefs = [[NSMutableDictionary alloc] initWithContentsOfFile:kPrefPath];
	return [prefs[@"apps"] containsObject:bundleIdentifier];
}


double FPSavg = 0;
double FPSPerSecond = 0;
double RenderFPS = 0;

static void startRefreshTimer(){
	_timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, dispatch_get_main_queue());
    dispatch_source_set_timer(_timer, dispatch_walltime(NULL, 0), (1.0/5.0) * NSEC_PER_SEC, 0);

    dispatch_source_set_event_handler(_timer, ^{
    	switch(fpsMode){
		    case kModeAverage:
		    	[fpsLabel setText:[NSString stringWithFormat:@"%.1lf",FPSavg]];
		    	break;
		    case kModePerSecond:
		    	[fpsLabel setText:[NSString stringWithFormat:@"%.1lf",FPSPerSecond]];
		    	break;
			case kModeRenderFrame:
				[fpsLabel setText:[NSString stringWithFormat:@"%.1lf",RenderFPS]];
				break;
		    default:
		    	break;
    	}

    	NSLog(@"%.1lf %.1lf %.1lf",FPSavg,FPSPerSecond,RenderFPS);

    });
    dispatch_resume(_timer); 
}

static void startUpdateRenderFPS(){
	//CARenderServer渲染帧率
	NSInteger (*origin_CARenderServerGetFrameCounter)(int) = NULL;


	void *handle = dlopen("/System/Library/Frameworks/QuartzCore.framework/QuartzCore", RTLD_NOW);
	origin_CARenderServerGetFrameCounter = dlsym(handle, "CARenderServerGetFrameCounter");
	if (origin_CARenderServerGetFrameCounter == NULL) {
		return;
	}
	static NSInteger AppFrameCounter = 0;
	static NSTimeInterval AppRenderTime = 0;
	static NSTimer *renderTimer = nil;
	if (renderTimer) {
		return;
	}
	renderTimer = [NSTimer timerWithTimeInterval:0.2 repeats:YES block:^(NSTimer * _Nonnull timer) {
		NSInteger frameCounter = origin_CARenderServerGetFrameCounter(0);
		if (AppFrameCounter == 0) {
			AppFrameCounter = frameCounter;
		} else {
			NSInteger renderFrameCount = frameCounter - AppFrameCounter;
			AppFrameCounter = frameCounter;
			NSTimeInterval currentTime = CACurrentMediaTime();
			if (AppRenderTime > 0) {
				NSInteger fps = floor(renderFrameCount / (currentTime - AppRenderTime));
				// renderFPSLabel.text = [NSString stringWithFormat:@"渲染FPS:%ld", (long)fps];
				RenderFPS = fps;
			}
			AppRenderTime = CACurrentMediaTime();
		}
	}];
	[[NSRunLoop mainRunLoop] addTimer:renderTimer forMode:NSRunLoopCommonModes];
	return;
}

#pragma mark ui
#define kFPSLabelWidth 50
#define kFPSLabelHeight 20
%group ui
%hook UIWindow
- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
	static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        CGRect bounds=[self bounds];
        CGFloat safeOffsetY=0;
        CGFloat safeOffsetX=0;
        if(@available(iOS 11.0,*)) {
            if(self.frame.size.width<self.frame.size.height){
                safeOffsetY=self.safeAreaInsets.top;    
            }
            else{
                safeOffsetX=self.safeAreaInsets.right;
            }
            
        }
        fpsLabel= [[UILabel alloc] initWithFrame:CGRectMake(bounds.size.width-kFPSLabelWidth-5.-safeOffsetX, safeOffsetY, kFPSLabelWidth, kFPSLabelHeight)];
        fpsLabel.font=[UIFont fontWithName:@"Helvetica-Bold" size:16];
        fpsLabel.textAlignment=NSTextAlignmentRight;
        fpsLabel.userInteractionEnabled=NO;
        
        [self addSubview:fpsLabel];
        loadPref();
		startUpdateRenderFPS();
        startRefreshTimer();
		
    });
	return %orig;
}
%end
%end//ui

// credits to https://github.com/masagrator/NX-FPS/blob/master/source/main.cpp#L64
void frameTick(){
	static double FPS_temp = 0;
	static double starttick = 0;
	static double endtick = 0;
	static double deltatick = 0;
	static double frameend = 0;
	static double framedelta = 0;
	static double frameavg = 0;
	
	if (starttick == 0) starttick = CACurrentMediaTime()*1000.0;
	endtick = CACurrentMediaTime()*1000.0;
	framedelta = endtick - frameend;
	frameavg = ((9*frameavg) + framedelta) / 10;
	FPSavg = 1000.0f / (double)frameavg;
	frameend = endtick;
	
	FPS_temp++;
	deltatick = endtick - starttick;
	if (deltatick >= 1000.0f) {
		starttick = CACurrentMediaTime()*1000.0;
		FPSPerSecond = FPS_temp - 1;
		FPS_temp = 0;
	}
	
	return;
}

#pragma mark gl
%group gl
%hook EAGLContext 
- (BOOL)presentRenderbuffer:(NSUInteger)target{
	BOOL ret=%orig;
	frameTick();
	return ret;
}
%end
%end//gl

#pragma mark metal
%group metal
%hook CAMetalDrawable
- (void)present{
	%orig;
	frameTick();
}
- (void)presentAfterMinimumDuration:(CFTimeInterval)duration{
	%orig;
	frameTick();
}
- (void)presentAtTime:(CFTimeInterval)presentationTime{
	%orig;
	frameTick();
}
%end //CAMetalDrawable
%end//metal


%ctor{
	if(!isEnabledApp()) return;
	NSLog(@"ctor: FPSIndicator");

	%init(ui);
	%init(gl);
	%init(metal);

	int token = 0;
	notify_register_dispatch("com.brend0n.fpsindicator/loadPref", &token, dispatch_get_main_queue(), ^(int token) {
		loadPref();
	});
}
