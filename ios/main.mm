#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>
#include <SDL3/SDL.h>
#include <SDL3/SDL_main.h>
#include <SDL3/SDL_system.h>
#include "NativeHost.hpp"
#include "Lifecycle.hpp"
#include "Diagnostics.hpp"
#include "Preferences.hpp"
#include "Joystick.hpp"
#include "PortraitLayout.hpp"
#include "ControlLayout.hpp"
#include <cstdio>
#include <ctime>
#include <cstring>
#include <algorithm>

static uint32_t bombSerial=0, pauseSerial=0;
static bool shooting=false, focusing=false;
static touhou::ios::ToggleButton fireButton,slowButton;
static float stickX=0,stickY=0;
static bool stickMode=false;
static touhou::ios::Lifecycle lifecycle;
static uint64_t frames=0;
static bool smoke=false;
#if TH15_DIAGNOSTICS
static int diagnosticStage=0,diagnosticCharacter=0,regressionIndex=0;
static bool regression=false,settingsSmoke=false,touchSmoke=false;
static bool bombChecks=false;
static bool uiTest=false;
static UIAccessibilityElement* testState;
#endif
static void showSettings(UIButton* button);
static void showDeveloper();
static void beginLayoutEditing();
static void finishLayoutEditing();
static void controls(){
    const bool gameplay=sdl_controls_gameplay();
    const bool autoFire=gameplay&&touhou::ios::preference(@"autoFire"),autoSlow=gameplay&&touhou::ios::preference(@"autoSlow");
    sdl_touch_options(1,!touhou::ios::preference(@"dragLimited"),float(touhou::ios::preference(@"sensitivity")));
    sdl_developer_enabled(touhou::ios::preference(@"developer"));
    sdl_auto_bomb(touhou::ios::preference(@"autoBomb"));
    sdl_touch_gestures(touhou::ios::preference(@"twoFingerSlow"),touhou::ios::preference(@"doubleTapBomb"));
    sdl_display_options(touhou::ios::preference(@"smooth"),touhou::ios::preference(@"portraitZoom"));
    if(!stickMode)sdl_touch_mode((uint32_t)touhou::ios::preference(@"movement"));
    sdl_touch_controls(shooting||(gameplay&&fireButton.latched)||autoFire,focusing||(gameplay&&slowButton.latched)||autoSlow,bombSerial,pauseSerial,stickX*32767,stickY*32767);
}
static void audioSession(){
    NSError* error=nil;
    AVAudioSession* session=AVAudioSession.sharedInstance;
    BOOL category=[session setCategory:AVAudioSessionCategoryPlayback error:&error];
    if(!category)touhou::ios::diagnostic(@"Audio category error: %@",error);
    error=nil;BOOL enabled=[session setActive:YES error:&error];
    touhou::ios::diagnostic(@"Audio session: active=%d sampleRate=%.0f buffer=%.4f error=%@",enabled,session.sampleRate,session.IOBufferDuration,error);
}
static void buttonAppearance(UIButton* button,bool held){
    const bool action=button.tag<7,rose=button.tag==4||button.tag==6;
    button.backgroundColor=rose?[UIColor colorWithRed:.20 green:.07 blue:.13 alpha:held?.88:.58]:
                                 [UIColor colorWithRed:.09 green:.13 blue:.21 alpha:held?.88:.58];
    button.layer.borderColor=(rose?[UIColor colorWithRed:.86 green:.32 blue:.49 alpha:held?.95:.68]:
                                   [UIColor colorWithRed:.61 green:.75 blue:.88 alpha:held?.95:.62]).CGColor;
    button.transform=action&&held?CGAffineTransformMakeScale(.90,.90):CGAffineTransformIdentity;
    button.alpha=touhou::ios::preference(@"opacity");
}
@interface TH15Joystick : UIControl
@property(nonatomic,strong) UIView* thumb;
@property(nonatomic,strong) UIView* innerRing;
@property(nonatomic) BOOL engaged;
@property(nonatomic) touhou::ios::JoystickSample sample;
- (void)reset;
@end
@implementation TH15Joystick
- (instancetype)initWithFrame:(CGRect)frame {
    self=[super initWithFrame:frame];if(!self)return nil;
    self.multipleTouchEnabled=NO;self.exclusiveTouch=NO;
    self.backgroundColor=[UIColor colorWithRed:.18 green:.16 blue:.32 alpha:.29];
    self.layer.borderWidth=1.5;self.layer.borderColor=[UIColor colorWithRed:.61 green:.70 blue:.84 alpha:.48].CGColor;
    self.innerRing=[[UIView alloc] initWithFrame:CGRectZero];self.innerRing.userInteractionEnabled=NO;
    self.innerRing.backgroundColor=[UIColor colorWithRed:.28 green:.42 blue:.58 alpha:.23];
    self.innerRing.layer.borderWidth=1;self.innerRing.layer.borderColor=[UIColor colorWithRed:.60 green:.73 blue:.88 alpha:.25].CGColor;
    [self addSubview:self.innerRing];
    self.thumb=[[UIView alloc] initWithFrame:CGRectZero];self.thumb.userInteractionEnabled=NO;
    self.thumb.backgroundColor=[UIColor colorWithRed:.68 green:.78 blue:.96 alpha:.58];
    self.thumb.layer.borderWidth=1;self.thumb.layer.borderColor=[UIColor colorWithRed:.86 green:.91 blue:1 alpha:.70].CGColor;
    [self addSubview:self.thumb];
    self.isAccessibilityElement=YES;self.accessibilityLabel=@"移动摇杆";
    self.accessibilityHint=@"按住并拖动以移动角色或选择菜单";
    self.accessibilityIdentifier=@"th15.joystick";
    self.accessibilityTraits=UIAccessibilityTraitAllowsDirectInteraction;
    return self;
}
- (void)layoutSubviews {
    [super layoutSubviews];CGFloat size=std::min(self.bounds.size.width,self.bounds.size.height);
    self.layer.cornerRadius=size/2;self.thumb.bounds=CGRectMake(0,0,56,56);self.thumb.layer.cornerRadius=28;
    self.innerRing.bounds=CGRectMake(0,0,size*.78,size*.78);self.innerRing.layer.cornerRadius=size*.39;
    self.innerRing.center=CGPointMake(CGRectGetMidX(self.bounds),CGRectGetMidY(self.bounds));
    self.thumb.backgroundColor=self.engaged?[UIColor colorWithRed:.82 green:.90 blue:.96 alpha:.83]:
                                          [UIColor colorWithRed:.68 green:.78 blue:.96 alpha:.58];
    self.thumb.transform=self.engaged?CGAffineTransformMakeScale(1.10,1.10):CGAffineTransformIdentity;
    const CGFloat radius=std::max(CGFloat(1),(size-56)/2);
    self.thumb.center=CGPointMake(CGRectGetMidX(self.bounds)+self.sample.knobX*radius,CGRectGetMidY(self.bounds)+self.sample.knobY*radius);
}
- (void)updateTouch:(UITouch*)touch {
    const CGPoint point=[touch locationInView:self];
    const CGFloat radius=std::max(CGFloat(1),(std::min(self.bounds.size.width,self.bounds.size.height)-56)/2);
    self.sample=touhou::ios::joystickSample(float(point.x-CGRectGetMidX(self.bounds)),float(point.y-CGRectGetMidY(self.bounds)),float(radius),float(touhou::ios::preference(@"deadZone")));
#if TH15_DIAGNOSTICS
    if(uiTest&&!CGRectContainsPoint(self.bounds,point)){touhou::ios::diagnostic(@"Joystick captured outside: engaged=%d x=%.2f y=%.2f",self.engaged,self.sample.x,self.sample.y);touhou::ios::diagnosticsFlush();}
#endif
    [self setNeedsLayout];[self sendActionsForControlEvents:UIControlEventValueChanged];
}
- (BOOL)beginTrackingWithTouch:(UITouch*)touch withEvent:(UIEvent*)event {
    if(!lifecycle.running())return NO;
    self.engaged=YES;[self updateTouch:touch];return YES;
}
- (BOOL)continueTrackingWithTouch:(UITouch*)touch withEvent:(UIEvent*)event {
    // UIKit continues delivering the captured finger outside this view.
    // Clamp the vector in joystickSample; release only on up/cancel/pause.
    if(!lifecycle.running()){[self reset];return NO;}
    [self updateTouch:touch];return YES;
}
- (void)endTrackingWithTouch:(UITouch*)touch withEvent:(UIEvent*)event {[super endTrackingWithTouch:touch withEvent:event];[self reset];}
- (void)cancelTrackingWithEvent:(UIEvent*)event {[super cancelTrackingWithEvent:event];[self reset];}
- (void)reset {
    self.engaged=NO;self.sample=touhou::ios::JoystickSample{};[self setNeedsLayout];[self sendActionsForControlEvents:UIControlEventValueChanged];
}
@end
@interface TH15Controls : UIView
@property(nonatomic,strong) NSArray<UIButton*>* buttons;
@property(nonatomic,strong) TH15Joystick* joystick;
@property(nonatomic) CGRect layoutBounds;
@property(nonatomic) UIEdgeInsets layoutInsets;
@property(nonatomic) uint32_t pressedButtons;
@property(nonatomic) BOOL editingLayout;
@property(nonatomic,strong) NSMutableDictionary* layoutDraft;
@property(nonatomic,strong) UIView* layoutToolbar;
@property(nonatomic,strong) UILabel* layoutHint;
@property(nonatomic) CGPoint dragOrigin;
- (void)startLayoutEditing;
- (void)applyControlLayout;
- (void)releaseInputs;
@end
@implementation TH15Controls
- (instancetype)initWithFrame:(CGRect)frame {
    self=[super initWithFrame:frame]; if(!self)return nil;
    self.multipleTouchEnabled=YES; self.backgroundColor=UIColor.clearColor;
    self.joystick=[[TH15Joystick alloc] initWithFrame:CGRectZero];
    [self.joystick addTarget:self action:@selector(joystickChanged:) forControlEvents:UIControlEventValueChanged];
    [self addSubview:self.joystick];
    NSArray* titles=@[@"Z",@"S",@"X",@"",@"",@"DEV"];
    NSArray* labels=@[@"射击／确认",@"低速",@"灵击",@"暂停／返回",@"设置",@"开发者功能"];
    NSArray* identifiers=@[@"th15.fire",@"th15.slow",@"th15.bomb",@"th15.pause",@"th15.settings",@"th15.developer"];
    NSMutableArray* all=[NSMutableArray array];
    for(NSInteger i=0;i<titles.count;i++){
        UIButton* button=[UIButton buttonWithType:UIButtonTypeSystem];button.tag=i+4;
        [button setTitle:titles[i] forState:UIControlStateNormal];
        [button setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
        button.titleLabel.font=[UIFont systemFontOfSize:24 weight:UIFontWeightSemibold];
        button.accessibilityLabel=labels[i];button.accessibilityIdentifier=identifiers[i];
        if(i==3||i==4){
            UIImageSymbolConfiguration* config=[UIImageSymbolConfiguration configurationWithPointSize:19 weight:UIImageSymbolWeightSemibold];
            [button setImage:[UIImage systemImageNamed:i==3?@"pause.fill":@"gearshape" withConfiguration:config] forState:UIControlStateNormal];
            button.tintColor=UIColor.whiteColor;
        }
        if(i==5){button.titleLabel.font=[UIFont systemFontOfSize:13 weight:UIFontWeightBold];button.hidden=YES;}
        button.layer.borderWidth=i<3?1.5:1;buttonAppearance(button,false);
        button.multipleTouchEnabled=NO;button.exclusiveTouch=NO;
        [button addTarget:self action:@selector(down:) forControlEvents:UIControlEventTouchDown];
        [button addTarget:self action:@selector(reenter:) forControlEvents:UIControlEventTouchDragEnter];
        [button addTarget:self action:@selector(up:) forControlEvents:UIControlEventTouchUpInside|UIControlEventTouchUpOutside|UIControlEventTouchCancel|UIControlEventTouchDragExit];
        [self addSubview:button];[all addObject:button];
    }self.buttons=all;
    for(UIView* control in [@[self.joystick] arrayByAddingObjectsFromArray:self.buttons]){UIPanGestureRecognizer* pan=[[UIPanGestureRecognizer alloc]initWithTarget:self action:@selector(moveControl:)];pan.enabled=NO;pan.maximumNumberOfTouches=1;[control addGestureRecognizer:pan];}
    return self;
}
- (UIView*)hitTest:(CGPoint)point withEvent:(UIEvent*)event {UIView* hit=[super hitTest:point withEvent:event];return hit==self&&!self.editingLayout?nil:hit;}
- (void)layoutSubviews {
    [super layoutSubviews];UIEdgeInsets insets=self.safeAreaInsets;
    if(!CGRectEqualToRect(self.layoutBounds,self.bounds)||!UIEdgeInsetsEqualToEdgeInsets(self.layoutInsets,insets)){
        // Rotation invalidates both UIKit button tracking and SDL drag origins.
        [self releaseInputs];self.layoutBounds=self.bounds;self.layoutInsets=insets;
        touhou::ios::diagnostic(@"Layout width=%.0f height=%.0f portrait=%d",self.bounds.size.width,self.bounds.size.height,self.bounds.size.height>=self.bounds.size.width);
    }
    CGFloat left=insets.left+16,right=self.bounds.size.width-insets.right-16,bottom=self.bounds.size.height-insets.bottom-16;
    // Follow the earlier TH07 port: large Z at the right thumb, smaller X to
    // its left and S above, with a concentric joystick for the left thumb.
    const CGFloat scale=touhou::ios::preference(@"size");
    const CGFloat radius=std::clamp(std::min(self.bounds.size.width,self.bounds.size.height)*.064*scale,CGFloat(30),CGFloat(70));
    const CGFloat joystickRadius=std::max(CGFloat(60),radius*1.48);
    self.joystick.frame=CGRectMake(left,bottom-joystickRadius*2,joystickRadius*2,joystickRadius*2);
    const CGFloat actionX=right-radius*1.06,actionY=bottom-radius*1.06;
    const CGPoint centers[]={CGPointMake(actionX,actionY),CGPointMake(actionX-radius*.80,actionY-radius*1.95),
                             CGPointMake(actionX-radius*2.0,actionY),CGPointMake(right-22,insets.top+32),CGPointMake(left+22,insets.top+32),CGPointMake(left+78,insets.top+32)};
    const CGFloat diameters[]={radius*2.12,radius*1.68,radius*1.72,44,44,48};
    for(NSUInteger i=0;i<self.buttons.count;i++){
        UIButton* button=self.buttons[i];button.bounds=CGRectMake(0,0,diameters[i],diameters[i]);button.center=centers[i];
        button.layer.cornerRadius=diameters[i]/2;
        if(i<3)button.titleLabel.font=[UIFont systemFontOfSize:std::clamp(diameters[i]*.36,CGFloat(22),CGFloat(32)) weight:UIFontWeightSemibold];
    }
    const CGFloat width=self.bounds.size.width,height=self.bounds.size.height;
    const bool portrait=height>=width;
    if(!portrait){
        // Landscape is full-screen; safe areas constrain controls only.
        sdl_set_viewport(0,0,1,1);
        [self applyControlLayout];return;
    }
    if(sdl_zoom_active()){
        const auto layout=touhou::ios::portraitLayout(float(width),float(height),float(insets.top),float(self.window.screen.nativeScale));
        const auto& r=layout.playfield;
        sdl_set_viewport(r[0],r[1],r[2],r[3]);
        sdl_set_portrait_header(layout.header[1],layout.header[3]);
        // Utility controls float over the playfield; the original HUD is
        // left readable across the complete header width.
        self.buttons[3].center=CGPointMake(right-22,r[1]*height+30);
        self.buttons[4].center=CGPointMake(left+22,r[1]*height+30);
        self.buttons[5].center=CGPointMake(left+78,r[1]*height+30);
        [self applyControlLayout];return;
    }
    CGFloat ax=insets.left;
    CGFloat ay=insets.top+56;
    CGFloat aw=width-ax-insets.right;
    CGFloat ah=height-ay-insets.bottom-200;
    if(aw>0&&ah>0){
        const CGFloat ratio=4./3.;
        CGFloat gw=std::min(aw,ah*ratio),gh=gw/ratio;
        sdl_set_viewport(float((ax+(aw-gw)/2)/width),float((ay+(ah-gh)/2)/height),float(gw/width),float(gh/height));
    }
    [self applyControlLayout];
}
- (NSString*)orientationKey{return self.bounds.size.height>=self.bounds.size.width?@"layoutPortrait":@"layoutLandscape";}
- (NSArray<UIView*>*)layoutControls{return [@[self.joystick] arrayByAddingObjectsFromArray:self.buttons];}
- (CGPoint)clampCenter:(CGPoint)center control:(UIView*)control{
    const auto insets=self.safeAreaInsets;const CGFloat top=insets.top+(self.editingLayout?94:0);
    return CGPointMake(touhou::ios::controlCoordinate(center.x,self.bounds.size.width,insets.left,insets.right,control.bounds.size.width),touhou::ios::controlCoordinate(center.y,self.bounds.size.height,top,insets.bottom,control.bounds.size.height));
}
- (void)applyControlLayout{
    NSString* key=[self orientationKey];NSDictionary* saved=self.editingLayout?self.layoutDraft[key]:[NSUserDefaults.standardUserDefaults dictionaryForKey:touhou::ios::key(key)];
    NSArray* controls=[self layoutControls];for(NSUInteger i=0;i<controls.count;i++){
        UIView* control=controls[i];NSArray* position=saved[[NSString stringWithFormat:@"%lu",(unsigned long)i]];
        if([position isKindOfClass:NSArray.class]&&position.count==2&&[position[0] respondsToSelector:@selector(doubleValue)]&&[position[1] respondsToSelector:@selector(doubleValue)])control.center=CGPointMake([position[0] doubleValue]*self.bounds.size.width,[position[1] doubleValue]*self.bounds.size.height);
        control.center=[self clampCenter:control.center control:control];
    }
    const BOOL hidden=touhou::ios::preference(@"hidden")&&sdl_controls_gameplay()&&!self.editingLayout;self.joystick.hidden=hidden;self.joystick.alpha=self.editingLayout?1:touhou::ios::preference(@"opacity");
    for(NSUInteger i=0;i<self.buttons.count;i++){UIButton* button=self.buttons[i];if(i<3)button.hidden=hidden;if(i==5)button.hidden=!self.editingLayout&&(!touhou::ios::preference(@"developer")||!sdl_developer_available());button.alpha=self.editingLayout?1:touhou::ios::preference(@"opacity");}
    if(self.editingLayout){self.layoutToolbar.frame=CGRectMake(self.safeAreaInsets.left,self.safeAreaInsets.top,self.bounds.size.width-self.safeAreaInsets.left-self.safeAreaInsets.right,88);self.layoutHint.frame=CGRectMake(4,3,self.layoutToolbar.bounds.size.width-8,28);CGFloat w=self.layoutToolbar.bounds.size.width/3;for(UIButton* tool in self.layoutToolbar.subviews)if([tool isKindOfClass:UIButton.class])tool.frame=CGRectMake(w*tool.tag,34,w,48);[self bringSubviewToFront:self.layoutToolbar];}
#if TH15_DIAGNOSTICS
    if(uiTest&&testState){
        // Explicit diagnostic accessibility lists must omit hidden controls;
        // otherwise XCTest reports the hidden joystick as still hittable.
        NSMutableArray* accessible=[NSMutableArray array];
        if(!self.editingLayout)[accessible addObject:testState];
        for(UIView* control in controls)if(!control.hidden)[accessible addObject:control];
        if(self.editingLayout)[accessible addObject:self.layoutToolbar];
        self.accessibilityElements=accessible;
    }
#endif
}
- (void)startLayoutEditing{
    [self releaseInputs];self.editingLayout=YES;self.layoutDraft=[NSMutableDictionary dictionary];for(NSString* key in @[@"layoutPortrait",@"layoutLandscape"]){NSDictionary* value=[NSUserDefaults.standardUserDefaults dictionaryForKey:touhou::ios::key(key)];if(value)self.layoutDraft[key]=[value mutableCopy];}
    self.layoutToolbar=[UIView new];self.layoutToolbar.backgroundColor=[UIColor colorWithWhite:.08 alpha:.94];self.layoutToolbar.layer.cornerRadius=12;
    self.layoutHint=[UILabel new];self.layoutHint.text=@"拖动摇杆和按钮 · 横竖屏分别保存";self.layoutHint.textAlignment=NSTextAlignmentCenter;self.layoutHint.textColor=UIColor.whiteColor;self.layoutHint.font=[UIFont systemFontOfSize:14];[self.layoutToolbar addSubview:self.layoutHint];
    NSArray* titles=@[@"保存",@"重置当前方向",@"取消"];NSArray* ids=@[@"th15.layout.save",@"th15.layout.reset",@"th15.layout.cancel"];
    for(NSInteger i=0;i<3;i++){UIButton* tool=[UIButton buttonWithType:UIButtonTypeSystem];tool.tag=i;[tool setTitle:titles[i] forState:UIControlStateNormal];tool.accessibilityIdentifier=ids[i];[tool addTarget:self action:@selector(layoutTool:) forControlEvents:UIControlEventTouchUpInside];[self.layoutToolbar addSubview:tool];}
    [self addSubview:self.layoutToolbar];
#if TH15_DIAGNOSTICS
    if(uiTest)self.accessibilityElements=[[self layoutControls] arrayByAddingObject:self.layoutToolbar];
#endif
    for(UIView* control in [self layoutControls])for(UIGestureRecognizer* gesture in control.gestureRecognizers)gesture.enabled=YES;
    [self setNeedsLayout];
}
- (void)moveControl:(UIPanGestureRecognizer*)gesture{
    if(!self.editingLayout)return;UIView* control=gesture.view;if(gesture.state==UIGestureRecognizerStateBegan)self.dragOrigin=control.center;
    CGPoint delta=[gesture translationInView:self];control.center=[self clampCenter:CGPointMake(self.dragOrigin.x+delta.x,self.dragOrigin.y+delta.y) control:control];
    NSString* key=[self orientationKey];NSMutableDictionary* saved=self.layoutDraft[key];if(!saved){saved=[NSMutableDictionary dictionary];self.layoutDraft[key]=saved;}
    NSUInteger index=[[self layoutControls] indexOfObject:control];saved[[NSString stringWithFormat:@"%lu",(unsigned long)index]]=@[@(control.center.x/self.bounds.size.width),@(control.center.y/self.bounds.size.height)];
}
- (void)layoutTool:(UIButton*)tool{
    if(tool.tag==1){[self.layoutDraft removeObjectForKey:[self orientationKey]];[self setNeedsLayout];return;}
    if(tool.tag==0)for(NSString* key in @[@"layoutPortrait",@"layoutLandscape"]){if(self.layoutDraft[key])touhou::ios::setPreference(key,self.layoutDraft[key]);else [NSUserDefaults.standardUserDefaults removeObjectForKey:touhou::ios::key(key)];}
    self.editingLayout=NO;self.layoutDraft=nil;[self.layoutToolbar removeFromSuperview];self.layoutToolbar=nil;
#if TH15_DIAGNOSTICS
    if(uiTest)self.accessibilityElements=[@[testState] arrayByAddingObjectsFromArray:[self layoutControls]];
#endif
    for(UIView* control in [self layoutControls])for(UIGestureRecognizer* gesture in control.gestureRecognizers)gesture.enabled=NO;
    [self releaseInputs];[self setNeedsLayout];touhou::ios::diagnostic(@"Control layout %@",tool.tag==0?@"saved":@"cancelled");finishLayoutEditing();
}
- (void)joystickChanged:(TH15Joystick*)joystick {
    // Shared mode 3 suppresses viewport dragging. Use it while the joystick
    // owns movement, then restore mode 0 so normal area dragging still works.
    const bool engaged=joystick.engaged&&lifecycle.running();
    if(engaged!=stickMode){stickMode=engaged;sdl_touch_mode(engaged?3:(uint32_t)touhou::ios::preference(@"movement"));}
    stickX=engaged?joystick.sample.x:0;stickY=engaged?joystick.sample.y:0;
    controls();
}
- (void)down:(UIButton*)button {
    if(self.editingLayout)return;
    // Diagnostics remain available after a terminal frame result.
    if(button.tag==8){showSettings(button);return;}
    if(button.tag==9){showDeveloper();return;}
    if(!lifecycle.running()||(self.pressedButtons&(1u<<button.tag)))return;
    self.pressedButtons|=1u<<button.tag;
    if(button.tag==4){fireButton.down(sdl_controls_gameplay()&&touhou::ios::preference(@"toggleFire"));shooting=fireButton.held;sdl_key("KeyZ",fireButton.active());}
    else if(button.tag==5){slowButton.down(sdl_controls_gameplay()&&touhou::ios::preference(@"toggleSlow"));focusing=slowButton.held;sdl_key("ShiftLeft",slowButton.active());}
    else if(button.tag==6){++bombSerial;sdl_key("KeyX",1);}
    else {++pauseSerial;sdl_key("Escape",1);}
    controls();buttonAppearance(button,button.tag==4?fireButton.active():button.tag==5?slowButton.active():true);
}
- (void)reenter:(UIButton*)button {
    // Continuous controls may be re-entered; a Bomb/pause touch fires once.
    if(button.tag==4&&!touhou::ios::preference(@"toggleFire"))[self down:button];
    if(button.tag==5&&!touhou::ios::preference(@"toggleSlow"))[self down:button];
}
- (void)up:(UIButton*)button {
    self.pressedButtons&=~(1u<<button.tag);
    if(button.tag==4){fireButton.up();shooting=false;sdl_key("KeyZ",fireButton.latched&&sdl_controls_gameplay());}
    else if(button.tag==5){slowButton.up();focusing=false;sdl_key("ShiftLeft",slowButton.latched&&sdl_controls_gameplay());}
    else if(button.tag==6)sdl_key("KeyX",0);
    else if(button.tag==7)sdl_key("Escape",0);
    controls();buttonAppearance(button,button.tag==4?fireButton.active():button.tag==5?slowButton.active():false);
}
- (void)releaseInputs {
    self.pressedButtons=0;shooting=focusing=false;fireButton.clear();slowButton.clear();
    [self.joystick cancelTrackingWithEvent:nil];
    stickX=stickY=0;
    sdl_keys_clear();controls();
    SDL_FlushEvents(SDL_EVENT_FINGER_DOWN,SDL_EVENT_FINGER_CANCELED);
    for(UIButton* button in self.buttons){
        [button cancelTrackingWithEvent:nil];button.highlighted=NO;buttonAppearance(button,false);
    }
}
@end
static TH15Controls* overlay;
static bool settingsShowing=false;
static bool developerShowing=false;
static void pauseFor(touhou::ios::Lifecycle::Reason reason,bool paused){
    const bool changed=lifecycle.set(reason,paused);
    touhou::ios::diagnostic(@"Lifecycle reason=%u paused=%d running=%d changed=%d",unsigned(reason),paused,lifecycle.running(),changed);
    // Clear every pause source, including a second source while already paused.
    if(paused||changed)[overlay releaseInputs];
    if(!changed)return;
    if(lifecycle.running())audioSession();
    sdl_loop_pause(lifecycle.running()?0:1);
    touhou::ios::diagnosticsState(@"lifecycle transition / save");
    touhou::ios::diagnosticsFlush();
}
static void showSettings(UIButton* button){
    if(settingsShowing||developerShowing)return;settingsShowing=true;
    pauseFor(touhou::ios::Lifecycle::settings,true);
    touhou::ios::presentSettings(overlay.window.rootViewController,button,^{
        settingsShowing=false;controls();[overlay setNeedsLayout];pauseFor(touhou::ios::Lifecycle::settings,false);
    },^{beginLayoutEditing();});
}
static void beginLayoutEditing(){settingsShowing=false;pauseFor(touhou::ios::Lifecycle::layout,true);pauseFor(touhou::ios::Lifecycle::settings,false);[overlay startLayoutEditing];}
static void finishLayoutEditing(){controls();pauseFor(touhou::ios::Lifecycle::layout,false);}
static void showDeveloper(){
    if(settingsShowing||developerShowing||!lifecycle.running()||!touhou::ios::preference(@"developer")||!sdl_developer_available())return;
    developerShowing=true;pauseFor(touhou::ios::Lifecycle::developer,true);
    touhou::ios::presentDeveloper(overlay.window.rootViewController,^{
        developerShowing=false;controls();[overlay setNeedsLayout];pauseFor(touhou::ios::Lifecycle::developer,false);
    });
}
static void installControls(SDL_Window* window){
    UIWindow* native=(__bridge UIWindow*)SDL_GetPointerProperty(SDL_GetWindowProperties(window),SDL_PROP_WINDOW_UIKIT_WINDOW_POINTER,nullptr);
    UIView* parent=native.rootViewController.view;
    overlay=[[TH15Controls alloc] initWithFrame:parent.bounds];
    overlay.autoresizingMask=UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;
    [parent addSubview:overlay];
#if TH15_DIAGNOSTICS
    if(uiTest){
        testState=[[UIAccessibilityElement alloc] initWithAccessibilityContainer:overlay];
        testState.accessibilityIdentifier=@"th15.state";testState.accessibilityTraits=UIAccessibilityTraitStaticText;
        testState.accessibilityFrameInContainerSpace=CGRectMake(0,0,1,1);
        overlay.accessibilityElements=@[testState,overlay.joystick,overlay.buttons[0],overlay.buttons[1],overlay.buttons[2],overlay.buttons[3],overlay.buttons[4],overlay.buttons[5]];
    }
    if([NSProcessInfo.processInfo.arguments containsObject:@"--landscape-smoke"]){
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW,2*NSEC_PER_SEC),dispatch_get_main_queue(),^{
            if(@available(iOS 16.0,*)){
                UIWindowSceneGeometryPreferencesIOS* geometry=[[UIWindowSceneGeometryPreferencesIOS alloc] initWithInterfaceOrientations:UIInterfaceOrientationMaskLandscapeLeft];
                [native.windowScene requestGeometryUpdateWithPreferences:geometry errorHandler:^(NSError* error){
                    touhou::ios::diagnostic(@"Landscape smoke rotation failed: %@",error);
                }];
            }
        });
    }
#endif
    NSNotificationCenter* center=NSNotificationCenter.defaultCenter;
    [center addObserverForName:UIApplicationWillResignActiveNotification object:nil queue:NSOperationQueue.mainQueue usingBlock:^(NSNotification*){
        pauseFor(touhou::ios::Lifecycle::inactive,true);
    }];
    [center addObserverForName:UIApplicationDidEnterBackgroundNotification object:nil queue:NSOperationQueue.mainQueue usingBlock:^(NSNotification*){
        pauseFor(touhou::ios::Lifecycle::inactive,true);
    }];
    [center addObserverForName:UIApplicationDidBecomeActiveNotification object:nil queue:NSOperationQueue.mainQueue usingBlock:^(NSNotification*){
        pauseFor(touhou::ios::Lifecycle::inactive,false);
    }];
    [center addObserverForName:AVAudioSessionInterruptionNotification object:nil queue:NSOperationQueue.mainQueue usingBlock:^(NSNotification* note){
        NSNumber* type=note.userInfo[AVAudioSessionInterruptionTypeKey];
        if(!type)return;
        touhou::ios::diagnostic(@"Audio interruption: type=%@ options=%@",type,note.userInfo[AVAudioSessionInterruptionOptionKey]);
        if(type.unsignedIntegerValue==AVAudioSessionInterruptionTypeBegan)
            pauseFor(touhou::ios::Lifecycle::audioInterruption,true);
        else if(type.unsignedIntegerValue==AVAudioSessionInterruptionTypeEnded)
            pauseFor(touhou::ios::Lifecycle::audioInterruption,false);
    }];
    [center addObserverForName:AVAudioSessionRouteChangeNotification object:nil queue:NSOperationQueue.mainQueue usingBlock:^(NSNotification* note){
        touhou::ios::diagnostic(@"Audio route changed: reason=%@",note.userInfo[AVAudioSessionRouteChangeReasonKey]);
        if(lifecycle.running())audioSession();
    }];
    [center addObserverForName:UIApplicationDidReceiveMemoryWarningNotification object:nil queue:NSOperationQueue.mainQueue usingBlock:^(NSNotification*){
        touhou::ios::diagnosticsState(@"memory warning");touhou::ios::diagnosticsFlush();
    }];
    [center addObserverForName:UIApplicationWillTerminateNotification object:nil queue:NSOperationQueue.mainQueue usingBlock:^(NSNotification*){
        touhou::ios::diagnostic(@"Application will terminate");touhou::ios::diagnosticsFlush();
    }];
    pauseFor(touhou::ios::Lifecycle::inactive,UIApplication.sharedApplication.applicationState!=UIApplicationStateActive);
}
static void frame(void*){
    @autoreleasepool {
        if(!lifecycle.running())return;
        static bool previousGameplay=false;const bool gameplay=sdl_controls_gameplay();if(previousGameplay!=gameplay){[overlay releaseInputs];[overlay setNeedsLayout];previousGameplay=gameplay;}controls();
#if TH15_DIAGNOSTICS
        if(regression&&sdl_game_status()[5]>=300){
            const int next=++regressionIndex;
            if(next>=10){touhou::ios::diagnostic(@"REGRESSION PASS: seven stages and four characters each reached 300 frames");pauseFor(touhou::ios::Lifecycle::stopped,true);return;}
            const int stage=next<7?next+1:1,character=next<7?0:next-6;
            touhou::ios::diagnostic(@"REGRESSION start stage=%d character=%d",stage,character);touhou::ios::diagnosticsFlush();
            if(!sdl_test_stage(stage,character)){touhou::ios::diagnostic(@"REGRESSION FAIL %s",sdl_file_error());pauseFor(touhou::ios::Lifecycle::stopped,true);return;}
        }
        if(bombChecks&&sdl_game_status()[5]>=180){
            if(!sdl_test_auto_bomb()){touhou::ios::diagnostic(@"AUTO BOMB FAIL: character=%d %s",diagnosticCharacter,sdl_file_error());pauseFor(touhou::ios::Lifecycle::stopped,true);return;}
            touhou::ios::diagnostic(@"AUTO BOMB collision PASS: character=%d, stock=3->2, protection, disabled and empty-stock ordinary hit",diagnosticCharacter);
            if(++diagnosticCharacter>=4){touhou::ios::diagnostic(@"AUTO BOMB PASS: four original character Bomb services via actual circle collision");pauseFor(touhou::ios::Lifecycle::stopped,true);return;}
            if(!sdl_test_stage(1,diagnosticCharacter)){touhou::ios::diagnostic(@"AUTO BOMB FAIL: %s",sdl_file_error());pauseFor(touhou::ios::Lifecycle::stopped,true);return;}
        }
        if(regression||diagnosticStage)sdl_test_protect();
        if(settingsSmoke&&frames==120)[overlay down:overlay.buttons[4]];
        if(settingsSmoke&&frames==120){dispatch_after(dispatch_time(DISPATCH_TIME_NOW,2*NSEC_PER_SEC),dispatch_get_main_queue(),^{UIViewController* nav=overlay.window.rootViewController.presentedViewController;[[(UINavigationController*)nav topViewController] performSelector:@selector(done)];});}
        if(smoke){
            const bool battle=sdl_game_status()[0]==1;
            const bool confirm=frames>=20&&((frames-20)%45)<3;
            sdl_key("KeyZ",battle||confirm);
        }
#endif
        const double started=double(SDL_GetTicksNS())/1000000000.;
        int result=sdl_loop_frame(started);
#if TH15_DIAGNOSTICS
        if(uiTest)testState.accessibilityLabel=[NSString stringWithFormat:@"%s width=%.0f height=%.0f deadZone=%.2f dragLimited=%d fireLatch=%d slowLatch=%d hidden=%d",sdl_test_state(),overlay.bounds.size.width,overlay.bounds.size.height,touhou::ios::preference(@"deadZone"),int(touhou::ios::preference(@"dragLimited")),fireButton.latched,slowButton.latched,int(touhou::ios::preference(@"hidden"))];
#endif
        const BOOL hideDeveloper=!touhou::ios::preference(@"developer")||!sdl_developer_available();
        if(overlay.buttons[5].hidden!=hideDeveloper){overlay.buttons[5].hidden=hideDeveloper;[overlay setNeedsLayout];}
        static bool previousZoom=false;
        if(previousZoom!=sdl_zoom_active()){previousZoom=sdl_zoom_active();[overlay setNeedsLayout];}
        if(frames%300==0){const auto* status=sdl_game_status();touhou::ios::diagnostic(@"scene=%d stage=%d stageFrame=%d screen=%d pause=%d",status[0],status[2],status[5],status[8],status[14]);}
        if(result){touhou::ios::diagnostic(@"TH15 frame result %d error=%s",result,sdl_file_error());pauseFor(touhou::ios::Lifecycle::stopped,true);}
        touhou::ios::diagnosticsFrame(started,double(SDL_GetTicksNS())/1000000000.-started,++frames);
    }
}
int main(int argc,char** argv){
    @autoreleasepool {
        touhou::ios::diagnosticsStart();
#if TH15_DIAGNOSTICS
        for(int i=1;i<argc;i++){
            if(!strcmp(argv[i],"--smoke"))smoke=true;
            if(!strcmp(argv[i],"--regression")){regression=smoke=true;diagnosticStage=1;}
            if(!strcmp(argv[i],"--autobomb-checks")){bombChecks=true;diagnosticStage=1;}
            if(!strcmp(argv[i],"--stage")&&i+1<argc)diagnosticStage=atoi(argv[++i]);
            if(!strcmp(argv[i],"--character")&&i+1<argc)diagnosticCharacter=atoi(argv[++i]);
            if(!strcmp(argv[i],"--settings-smoke"))settingsSmoke=true;
            if(!strcmp(argv[i],"--ui-test"))uiTest=true;
            if(!strcmp(argv[i],"--reset-native-settings"))touhou::ios::resetPreferences();
            if(!strcmp(argv[i],"--portrait-zoom"))touhou::ios::setPreference(@"portraitZoom",@YES);
        }
#endif
        SDL_SetHint(SDL_HINT_ORIENTATIONS,"LandscapeLeft LandscapeRight Portrait");
        SDL_SetHint(SDL_HINT_TOUCH_MOUSE_EVENTS,"0");
        SDL_SetHint(SDL_HINT_MOUSE_TOUCH_EVENTS,"0");
        touhou::ios::diagnostic(@"SDL initialization begins; smoke=%d",smoke);
        if(!SDL_Init(SDL_INIT_VIDEO|SDL_INIT_AUDIO|SDL_INIT_EVENTS|SDL_INIT_GAMEPAD)){touhou::ios::diagnostic(@"SDL initialization failed: %s",SDL_GetError());touhou::ios::diagnosticsFlush();return 1;}
        touhou::ios::diagnostic(@"SDL initialized; opening TH15 original game");
        audioSession();UIApplication.sharedApplication.idleTimerDisabled=YES;
        auto* game=sdl_game_open(smoke);
        if(!game){touhou::ios::diagnostic(@"TH15 initialization failed: %s file=%s",SDL_GetError(),sdl_file_error());touhou::ios::diagnosticsFlush();return 2;}
        auto* window=static_cast<SDL_Window*>(sdl_window());
        if(!window){touhou::ios::diagnostic(@"TH15 window missing");touhou::ios::diagnosticsFlush();return 3;}
#if TH15_DIAGNOSTICS
        if(diagnosticStage&&!sdl_test_stage(diagnosticStage,diagnosticCharacter)){touhou::ios::diagnostic(@"Diagnostic stage failed: %s",sdl_file_error());touhou::ios::diagnosticsFlush();return 5;}
#endif
        sdl_touch_options(1,0,1);sdl_touch_gestures(0,0);controls();
        sdl_loop_start(game);installControls(window);
        if(!SDL_SetiOSAnimationCallback(window,1,frame,nullptr)){touhou::ios::diagnostic(@"TH15 display callback failed: %s",SDL_GetError());touhou::ios::diagnosticsFlush();return 4;}
        touhou::ios::diagnostic(@"TH15 native started, JP assets, logic=60Hz, ARM64 device / simulator diagnostic separated");
        touhou::ios::diagnosticsState(@"startup complete");touhou::ios::diagnosticsFlush();
        return 0;
    }
}
