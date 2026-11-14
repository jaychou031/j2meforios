#import <UIKit/UIKit.h>
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>
#import <AVFoundation/AVFoundation.h>
#import <QuartzCore/QuartzCore.h>
#import <CommonCrypto/CommonDigest.h>
#import "NJSession.h"
#import "GameStorage.h"
#include "Controls.hpp"
#include "SessionLifecycle.hpp"

static NSString *documents() { return NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,NSUserDomainMask,YES).firstObject; }
static CGRect cg(controls::Rect r) { return CGRectMake(r.x,r.y,r.w,r.h); }
static UIColor *accent() { return [UIColor colorWithRed:0.15 green:0.85 blue:0.7 alpha:1]; }
static void message(UIViewController *owner,NSString *title,NSString *text) {
    UIAlertController *alert=[UIAlertController alertControllerWithTitle:title message:text preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"好" style:UIAlertActionStyleDefault handler:nil]];
    [owner presentViewController:alert animated:YES completion:nil];
}

@interface GameSurface : UIView
@property(nonatomic,strong) NJSession *session;
@property(nonatomic,strong) UIImage *gameImage;
@property(nonatomic) BOOL pixel;
- (void)releaseTouches;
- (NSString *)inputDiagnostics;
@end
struct KeyCap { int code; __unsafe_unretained NSString *label; controls::Rect rect; };
@implementation GameSurface {
    UIImageView *_display;
    std::vector<KeyCap> _keys;
    std::vector<controls::HitKey> _hitKeys;
    controls::HeldKeys _held;
    __weak UITouch *_pointer;
    CGPoint _lastPointer;
    controls::Rect _screen;
    CGRect _layoutBounds;
    BOOL _hasLayout, _layoutPixel;
    int _layoutWidth, _layoutHeight;
    CGFloat _layoutScale;
    NSUInteger _touchSamples;
    double _touchDelayTotal, _touchDelayMax;
    NSUInteger _edgeSamples;
    double _edgeDelayTotal, _edgeDelayMax;
}
@synthesize gameImage=_gameImage;
- (instancetype)init {
    if((self=[super init])) {
        self.multipleTouchEnabled=YES; self.backgroundColor=UIColor.blackColor;
        _display=[UIImageView new]; _display.userInteractionEnabled=NO;
        _display.contentMode=UIViewContentModeScaleToFill;
        [self addSubview:_display];
    }
    return self;
}
- (void)key:(int)key down:(BOOL)down {
    nj_event e={}; e.type=down?NJ_EV_KEY_DOWN:NJ_EV_KEY_UP; e.key=key; [_session sendEvent:e];
    for(const auto& cap:_keys) if(cap.code==key) [self setNeedsDisplayInRect:cg(cap.rect)];
}
- (void)setGameImage:(UIImage *)image {
    _gameImage=image;
    // UIKit composites the game image independently from the keypad backing
    // store, so a new game frame never schedules a keypad drawRect pass.
    _display.image=image;
}
- (void)pointer:(int)type point:(CGPoint)p {
    if(_screen.w<=0 || _screen.h<=0) return;
    nj_event e={}; e.type=type;
    e.x=std::clamp((int)((p.x-_screen.x)*_session.width/_screen.w),0,_session.width-1);
    e.y=std::clamp((int)((p.y-_screen.y)*_session.height/_screen.h),0,_session.height-1);
    [_session sendEvent:e]; _lastPointer=p;
}
- (void)releaseTouches {
    _held.clear([&](int k,bool d){[self key:k down:d];});
    if(_pointer) [self pointer:NJ_EV_POINTER_UP point:_lastPointer];
    _pointer=nil;
}
- (void)layoutSubviews {
    [super layoutSubviews];
    int width=_session.width?:240, height=_session.height?:320;
    CGFloat scale=self.window.screen.scale?:3;
    // Toolbar/FPS updates can trigger layout without changing the controls.
    // Only an actual geometry change should cancel held fingers.
    if(_hasLayout && CGRectEqualToRect(_layoutBounds,self.bounds) &&
       _layoutWidth==width && _layoutHeight==height &&
       _layoutPixel==_pixel && _layoutScale==scale) return;
    [self releaseTouches]; _keys.clear(); _hitKeys.clear();
    _hasLayout=YES; _layoutBounds=self.bounds; _layoutWidth=width; _layoutHeight=height;
    _layoutPixel=_pixel; _layoutScale=scale;
    auto layout=controls::layout(self.bounds.size.width,self.bounds.size.height);
    _screen=controls::fit(layout.viewport,width,height,_pixel,scale);
    _display.frame=cg(_screen);
    _display.layer.magnificationFilter=_pixel?kCAFilterNearest:kCAFilterLinear;
    _display.layer.minificationFilter=_pixel?kCAFilterNearest:kCAFilterLinear;
    const int left[15]={0,NJ_KEY_UP,0,NJ_KEY_LEFT,NJ_KEY_FIRE,NJ_KEY_RIGHT,0,NJ_KEY_DOWN,0,NJ_KEY_GAME_A,NJ_KEY_GAME_B,NJ_KEY_GAME_C,NJ_KEY_GAME_D,NJ_KEY_SOFT_LEFT,NJ_KEY_CLEAR};
    NSArray *labels=@[@"",@"▲",@"",@"◀",@"FIRE",@"▶",@"",@"▼",@"",@"A",@"B",@"C",@"D",@"左软键",@"CLEAR"];
    for(int i=0;i<15;i++) if(left[i]) {
        _keys.push_back({left[i],labels[i],controls::cell(layout.left,i%3,i/3)});
        _hitKeys.push_back({left[i],controls::hitCell(layout.left,i%3,i/3)});
    }
    const int right[15]={NJ_KEY_1,NJ_KEY_2,NJ_KEY_3,NJ_KEY_4,NJ_KEY_5,NJ_KEY_6,NJ_KEY_7,NJ_KEY_8,NJ_KEY_9,NJ_KEY_STAR,NJ_KEY_0,NJ_KEY_POUND,0,NJ_KEY_SOFT_RIGHT,0};
    NSArray *digits=@[@"1",@"2",@"3",@"4",@"5",@"6",@"7",@"8",@"9",@"*",@"0",@"#",@"",@"右软键",@""];
    for(int i=0;i<15;i++) if(right[i]) {
        _keys.push_back({right[i],digits[i],controls::cell(layout.right,i%3,i/3)});
        _hitKeys.push_back({right[i],controls::hitCell(layout.right,i%3,i/3)});
    }
    [self setNeedsDisplay];
}
- (void)setPixel:(BOOL)pixel { _pixel=pixel; [self setNeedsLayout]; }
- (void)drawRect:(CGRect)rect {
    for(auto key:_keys) {
        if(!CGRectIntersectsRect(rect,cg(key.rect))) continue;
        UIColor *fill=_held.down(key.code)?accent():[UIColor colorWithWhite:0.13 alpha:1];
        [fill setFill]; [[UIBezierPath bezierPathWithRoundedRect:cg(key.rect) cornerRadius:9] fill];
        NSDictionary *attributes=@{NSFontAttributeName:[UIFont systemFontOfSize:14 weight:UIFontWeightSemibold],NSForegroundColorAttributeName:_held.down(key.code)?UIColor.blackColor:UIColor.whiteColor};
        CGSize size=[key.label sizeWithAttributes:attributes];
        [key.label drawAtPoint:CGPointMake(key.rect.x+(key.rect.w-size.width)/2,key.rect.y+(key.rect.h-size.height)/2) withAttributes:attributes];
    }
}
- (void)updateTouches:(NSSet<UITouch *> *)touches ending:(BOOL)ending {
    for(UITouch *touch in touches) {
        CGPoint p=[touch locationInView:self];
        uintptr_t token=(uintptr_t)(__bridge void *)touch;
        int code=ending?0:controls::hitTest(_hitKeys,p.x,p.y,_held.keyForFinger(token));
        _held.move(token,code,[&](int k,bool d){[self key:k down:d];});
        if(_pointer==touch) {
            if(ending || code || !_screen.contains(p.x,p.y)) { [self pointer:NJ_EV_POINTER_UP point:p]; _pointer=nil; }
            else [self pointer:NJ_EV_POINTER_MOVE point:p];
        } else if(!ending && !code && !_pointer && _screen.contains(p.x,p.y)) {
            _pointer=touch; [self pointer:NJ_EV_POINTER_DOWN point:p];
        }
    }
}
- (void)touchesBegan:(NSSet<UITouch *> *)t withEvent:(UIEvent *)e {
    (void)e;
    NSTimeInterval now=NSProcessInfo.processInfo.systemUptime;
    for(UITouch *touch in t) {
        double delay=MAX(0.0,(now-touch.timestamp)*1000.0);
        ++_touchSamples; _touchDelayTotal+=delay; _touchDelayMax=MAX(_touchDelayMax,delay);
        CGPoint p=[touch locationInView:self.window];
        CGSize size=self.window.bounds.size;
        if(p.x<24 || p.x>size.width-24 || p.y>size.height-24) {
            ++_edgeSamples; _edgeDelayTotal+=delay; _edgeDelayMax=MAX(_edgeDelayMax,delay);
        }
    }
    [self updateTouches:t ending:NO];
}
- (NSString *)inputDiagnostics {
    return [NSString stringWithFormat:@"UI_TOUCH samples=%lu average_delivery_ms=%.2f max_delivery_ms=%.2f edge_samples=%lu edge_average_ms=%.2f edge_max_ms=%.2f\n",
        (unsigned long)_touchSamples,_touchSamples?_touchDelayTotal/_touchSamples:0.0,_touchDelayMax,
        (unsigned long)_edgeSamples,_edgeSamples?_edgeDelayTotal/_edgeSamples:0.0,_edgeDelayMax];
}
- (void)touchesMoved:(NSSet<UITouch *> *)t withEvent:(UIEvent *)e { (void)e; [self updateTouches:t ending:NO]; }
- (void)touchesEnded:(NSSet<UITouch *> *)t withEvent:(UIEvent *)e { (void)e; [self updateTouches:t ending:YES]; }
- (void)touchesCancelled:(NSSet<UITouch *> *)t withEvent:(UIEvent *)e { (void)e; [self updateTouches:t ending:YES]; }
@end

@interface GameController : UIViewController
@property(nonatomic,copy) NSString *jarPath;
@property(nonatomic,copy) NSString *saveID;
@property(nonatomic,copy) void (^onFinish)(int status);
@end
@implementation GameController {
    NJSession *_session;
    GameSurface *_surface;
    UIStackView *_toolbar;
    UIButton *_fps;
    CADisplayLink *_timer;
    NSTimeInterval _lastTime;
    NSTimeInterval _lastTickHost, _maxMainGap;
    NSUInteger _lastFrames;
    BOOL _showFPS, _locked, _stopping, _finished, _unexpectedDetach;
    session::Lifecycle _lifecycle;
    UIInterfaceOrientationMask _lockMask;
    float _volume;
}
- (BOOL)prefersStatusBarHidden { return YES; }
- (UIRectEdge)preferredScreenEdgesDeferringSystemGestures { return UIRectEdgeAll; }
- (UIInterfaceOrientationMask)supportedInterfaceOrientations { return _locked?_lockMask:UIInterfaceOrientationMaskAllButUpsideDown; }
- (UIButton *)button:(NSString *)title action:(SEL)selector {
    UIButton *b=[UIButton buttonWithType:UIButtonTypeSystem]; [b setTitle:title forState:UIControlStateNormal];
    b.tintColor=accent(); b.titleLabel.font=[UIFont systemFontOfSize:13 weight:UIFontWeightSemibold];
    [b addTarget:self action:selector forControlEvents:UIControlEventTouchUpInside]; return b;
}
- (void)viewDidLoad {
    [super viewDidLoad]; self.view.backgroundColor=UIColor.blackColor;
    NSUserDefaults *defaults=NSUserDefaults.standardUserDefaults;
    int resolution=(int)[defaults integerForKey:@"resolution"];
    const int widths[]={240,176,128,320}, heights[]={320,208,160,240};
    resolution=std::clamp(resolution,0,3);
    _session=[[NJSession alloc] initWithWidth:widths[resolution] height:heights[resolution]];
    BOOL captureAudio=[defaults boolForKey:@"capturePCM"];
    [_session setAudioCapture:captureAudio];
    if(captureAudio) [defaults setBool:NO forKey:@"capturePCM"]; // one session
    // Efficiency fixes apply at full speed. A legacy optional frame cap stays
    // user-controlled; entering iOS Low Power Mode does not silently cap games.
    BOOL limitFPS=[defaults boolForKey:@"powerSave"];
    [_session setFrameRate:limitFPS?30:60];
    _volume=[defaults floatForKey:@"volume"]; [_session setVolume:_volume];
    _surface=[GameSurface new]; _surface.session=_session; _surface.pixel=[defaults boolForKey:@"pixel"];
    [self.view addSubview:_surface];
    _fps=[self button:@"FPS" action:@selector(toggleFPS)]; _showFPS=[defaults boolForKey:@"fps"];
    _toolbar=[[UIStackView alloc] initWithArrangedSubviews:@[[self button:@"菜单" action:@selector(menu)],[self button:@"缩放" action:@selector(scale)],_fps,[self button:@"音量−" action:@selector(quieter)],[self button:@"音量+" action:@selector(louder)]]];
    _toolbar.distribution=UIStackViewDistributionFillEqually; [self.view addSubview:_toolbar];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(notificationInactive:) name:UIApplicationWillResignActiveNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(notificationActive:) name:UIApplicationDidBecomeActiveNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(audioInterrupted:) name:AVAudioSessionInterruptionNotification object:nil];
    NSError *error=nil;
    [AVAudioSession.sharedInstance setCategory:AVAudioSessionCategoryPlayback error:&error];
    _lifecycle.active=UIApplication.sharedApplication.applicationState==UIApplicationStateActive;
    _lifecycle.audioAvailable=[AVAudioSession.sharedInstance setActive:YES error:&error];
    [_session setAudioAvailable:_lifecycle.audioAvailable];
    [_session setPaused:_lifecycle.pauseVM()];
    _timer=[CADisplayLink displayLinkWithTarget:self selector:@selector(tick:)];
    _timer.preferredFramesPerSecond=limitFPS?30:60;
    [_timer addToRunLoop:NSRunLoop.mainRunLoop forMode:NSRunLoopCommonModes];
    _timer.paused=YES; // first changed frame wakes the display link
    UIApplication.sharedApplication.idleTimerDisabled=YES;
    __weak GameController *weakSelf=self;
    [_session setFrameReadyHandler:^{
        GameController *owner=weakSelf;
        if(owner && !owner->_lifecycle.pauseVM() && !owner->_stopping) {
            owner->_lastTickHost=0; owner->_timer.paused=NO;
        }
    }];
    [_session startJar:_jarPath saveID:_saveID completion:^(int status){ [weakSelf finished:status]; }];
}
- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    [self setNeedsUpdateOfScreenEdgesDeferringSystemGestures];
}
- (void)dismissViewControllerAnimated:(BOOL)animated completion:(void (^)(void))completion {
    // A back-gesture tweak may ask this controller to dismiss directly. Allow
    // dismissal of our menu alert, but keep the game until its worker exits.
    if(!_finished && !self.presentedViewController) return;
    [super dismissViewControllerAnimated:animated completion:completion];
}
- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
    // An ancestor or injected code can bypass our dismissal guard. Only an
    // actual removal stops the VM; an alert, backgrounding or cancelled swipe
    // must not end the game. Keep ownership until the worker's completion.
    BOOL detached=!self.presentingViewController && !self.parentViewController && !self.view.window;
    if(!_finished && (self.isBeingDismissed || self.isMovingFromParentViewController || detached)) {
        _unexpectedDetach=YES;
        [self stopGame];
    }
}
- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews]; CGRect safe=UIEdgeInsetsInsetRect(self.view.bounds,self.view.safeAreaInsets);
    _toolbar.frame=CGRectMake(safe.origin.x,safe.origin.y,safe.size.width,44);
    _surface.frame=CGRectMake(safe.origin.x,safe.origin.y+44,safe.size.width,MAX(1,safe.size.height-44));
}
- (void)tick:(CADisplayLink *)timer {
    NSTimeInterval host=NSProcessInfo.processInfo.systemUptime;
    if(_lastTickHost>0) _maxMainGap=MAX(_maxMainGap,host-_lastTickHost);
    _lastTickHost=host;
    BOOL idle=NO;
    UIImage *frame=[_session takeFrameWithIdle:&idle]; if(frame) _surface.gameImage=frame;
    if(idle && !_showFPS) { _timer.paused=YES; _lastTickHost=0; }
    if(timer.timestamp-_lastTime>=0.5) {
        NSUInteger count=_session.frameCount;
        double fps=_lastTime?(count-_lastFrames)/(timer.timestamp-_lastTime):0;
        if(_showFPS) [_fps setTitle:[NSString stringWithFormat:@"%.0f FPS",fps] forState:UIControlStateNormal];
        _lastFrames=count; _lastTime=timer.timestamp;
    }
}
- (void)scale { _surface.pixel=!_surface.pixel; [NSUserDefaults.standardUserDefaults setBool:_surface.pixel forKey:@"pixel"]; }
- (void)toggleFPS { _showFPS=!_showFPS; if(!_showFPS) [_fps setTitle:@"FPS 关" forState:UIControlStateNormal]; else if(!_lifecycle.pauseVM()) _timer.paused=NO; [NSUserDefaults.standardUserDefaults setBool:_showFPS forKey:@"fps"]; }
- (void)volumeBy:(float)delta { _volume=std::clamp(_volume+delta,0.0f,1.0f); [_session setVolume:_volume]; [NSUserDefaults.standardUserDefaults setFloat:_volume forKey:@"volume"]; }
- (void)quieter { [self volumeBy:-0.1f]; }
- (void)louder { [self volumeBy:0.1f]; }
- (void)applyLifecycle {
    _lastTickHost=0;
    _timer.paused=_lifecycle.pauseVM();
    if(_stopping) return; // never re-park the worker after stop woke it for teardown
    [_session setAudioAvailable:_lifecycle.audioAvailable];
    [_session setPaused:_lifecycle.pauseVM()];
}
- (void)inactive { _lastTickHost=0; [_surface releaseTouches]; _lifecycle.active=false; [self applyLifecycle]; }
- (void)notificationInactive:(NSNotification *)notification { (void)notification; [self inactive]; }
- (void)notificationActive:(NSNotification *)notification { (void)notification; [self active]; }
- (void)active {
    _lastTickHost=0;
    _lifecycle.active=UIApplication.sharedApplication.applicationState==UIApplicationStateActive;
    // A suspended app may never receive interruption-ended. Foreground entry
    // always retries activation; failure gates audio, never strands the VM.
    if(_lifecycle.active && !_stopping) _lifecycle.audioAvailable=[AVAudioSession.sharedInstance setActive:YES error:nil];
    [self applyLifecycle];
}
- (void)audioInterrupted:(NSNotification *)notification {
    BOOL began=[notification.userInfo[AVAudioSessionInterruptionTypeKey] unsignedIntegerValue]==AVAudioSessionInterruptionTypeBegan;
    if(began) { _lifecycle.audioAvailable=false; [_surface releaseTouches]; [self applyLifecycle]; }
    else [self active];
}
- (void)resume { _lifecycle.menu=false; [self active]; }
- (void)stopGame {
    if(_stopping || _finished) return;
    _stopping=YES; _lifecycle.stopping=true;
    _timer.paused=YES; [_surface releaseTouches]; _toolbar.userInteractionEnabled=NO;
    // stop wakes a paused worker so destroyApp and audio teardown can finish.
    [_session stop];
}
- (void)menu {
    if(_stopping) return;
    [_surface releaseTouches]; _lifecycle.menu=true; [self applyLifecycle];
    UIAlertController *a=[UIAlertController alertControllerWithTitle:self.title message:[NSString stringWithFormat:@"音量 %.0f%% · %@ · %d×%d",_volume*100,_surface.pixel?@"整数倍":@"最大尺寸",_session.width,_session.height] preferredStyle:UIAlertControllerStyleAlert];
    [a addAction:[UIAlertAction actionWithTitle:@"继续游戏" style:UIAlertActionStyleCancel handler:^(UIAlertAction *){[self resume];}]];
    [a addAction:[UIAlertAction actionWithTitle:_locked?@"解除方向锁定":@"锁定当前方向" style:UIAlertActionStyleDefault handler:^(UIAlertAction *){
        UIInterfaceOrientation o=self.view.window.windowScene?self.view.window.windowScene.interfaceOrientation:UIApplication.sharedApplication.statusBarOrientation;
        self->_lockMask=(UIInterfaceOrientationMask)(1<<o); self->_locked=!self->_locked;
        [UIViewController attemptRotationToDeviceOrientation]; [self resume];
    }]];
    [a addAction:[UIAlertAction actionWithTitle:@"结束并返回游戏列表" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *){
        [self stopGame];
    }]];
    [self presentViewController:a animated:YES completion:nil];
}
- (void)finished:(int)status {
    if(_finished) return;
    _finished=YES; _stopping=YES; _lifecycle.stopping=true;
    [_timer invalidate]; _timer=nil; [_surface releaseTouches];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    UIApplication.sharedApplication.idleTimerDisabled=NO;
    [AVAudioSession.sharedInstance setActive:NO withOptions:AVAudioSessionSetActiveOptionNotifyOthersOnDeactivation error:nil];
    NSString *path=[documents() stringByAppendingPathComponent:@"latest-session.log"];
    NSString *log=[_session.logText stringByAppendingFormat:@"%@UI_MAIN max_tick_gap_ms=%.2f\nUI_EXIT unexpected_detach=%d\nAPP_VERSION=%@ BUILD=%@\n",
        [_surface inputDiagnostics],_maxMainGap*1000.0,(int)_unexpectedDetach,
        [NSBundle.mainBundle objectForInfoDictionaryKey:@"CFBundleShortVersionString"],
        [NSBundle.mainBundle objectForInfoDictionaryKey:@"CFBundleVersion"]];
    [log writeToFile:path atomically:YES encoding:NSUTF8StringEncoding error:nil];
    [self returnToLibrary:status];
}
- (void)returnToLibrary:(int)status {
    // The menu may still be animating away when a fast worker finishes. Wait
    // for that transition (or an external dismissal), then close the full
    // presentation chain in one operation instead of racing two dismissals.
    id<UIViewControllerTransitionCoordinator> transition=self.presentedViewController.transitionCoordinator ?: self.transitionCoordinator;
    if(transition && [transition animateAlongsideTransition:nil completion:^(id<UIViewControllerTransitionCoordinatorContext> context) {
        (void)context;
        dispatch_async(dispatch_get_main_queue(),^{ [self returnToLibrary:status]; });
    }]) return;
    void (^done)(void)=^{
        void (^callback)(int)=self.onFinish;
        self.onFinish=nil;
        if(callback) callback(status);
    };
    UIViewController *presenter=self.presentingViewController;
    if(presenter && presenter.presentedViewController==self) [presenter dismissViewControllerAnimated:NO completion:done];
    else done(); // already removed externally; never dismiss another screen
}
@end

@interface LibraryController : UITableViewController <UIDocumentPickerDelegate>
@end
@implementation LibraryController {
    NSArray<NSDictionary *> *_games;
    GameController *_activeGame; // retains the session even after a forced dismissal
}
- (void)viewDidLoad {
    [super viewDidLoad]; self.title=@"掌上 J2ME";
    self.navigationItem.rightBarButtonItem=[[UIBarButtonItem alloc] initWithTitle:@"导入 JAR" style:UIBarButtonItemStylePlain target:self action:@selector(importJar)];
    self.navigationItem.leftBarButtonItem=[[UIBarButtonItem alloc] initWithTitle:@"设置" style:UIBarButtonItemStylePlain target:self action:@selector(settings)];
    self.tableView.backgroundColor=[UIColor colorWithWhite:0.06 alpha:1];
    self.tableView.rowHeight=UITableViewAutomaticDimension; self.tableView.estimatedRowHeight=64;
    self.refreshControl=[UIRefreshControl new]; [self.refreshControl addTarget:self action:@selector(reload) forControlEvents:UIControlEventValueChanged];
}
- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated]; [self.navigationController setNavigationBarHidden:NO animated:animated];
    self.navigationController.interactivePopGestureRecognizer.enabled=NO; [self reload];
}
- (void)reload {
    NSMutableArray *list=[NSMutableArray array];
    NSString *demo=[NSBundle.mainBundle pathForResource:@"korvo_demo" ofType:@"jar"];
    if(demo) [list addObject:@{@"title":@"内置演示 · Korvo Demo",@"path":demo,@"id":@"builtin-demo"}];
    NSString *folder=[documents() stringByAppendingPathComponent:@"Games"];
    [[NSFileManager defaultManager] createDirectoryAtPath:folder withIntermediateDirectories:YES attributes:nil error:nil];
    NSArray *files=[[[NSFileManager defaultManager] contentsOfDirectoryAtPath:folder error:nil] sortedArrayUsingSelector:@selector(localizedStandardCompare:)];
    for(NSString *file in files) if([file.pathExtension.lowercaseString isEqualToString:@"jar"]) {
        NSString *path=[folder stringByAppendingPathComponent:file];
        NSString *title=[NSString stringWithContentsOfFile:[path stringByAppendingString:@".title"] encoding:NSUTF8StringEncoding error:nil];
        [list addObject:@{@"title":title?:file,@"path":path,@"id":file.stringByDeletingPathExtension}];
    }
    _games=list; [self.tableView reloadData]; [self.refreshControl endRefreshing];
}
- (NSInteger)tableView:(UITableView *)table numberOfRowsInSection:(NSInteger)section { (void)table;(void)section;return _games.count; }
- (UITableViewCell *)tableView:(UITableView *)table cellForRowAtIndexPath:(NSIndexPath *)path {
    UITableViewCell *cell=[table dequeueReusableCellWithIdentifier:@"game"];
    if(!cell) cell=[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"game"];
    cell.textLabel.text=_games[path.row][@"title"]; cell.textLabel.numberOfLines=2;
    BOOL builtin=[_games[path.row][@"id"] isEqualToString:@"builtin-demo"];
    cell.detailTextLabel.text=builtin?@"验证画面、按键、音调和 RMS · ⓘ 管理数据":@"点击启动 · 左滑或点 ⓘ 管理";
    cell.accessoryType=UITableViewCellAccessoryDetailButton; return cell;
}
- (void)confirmManageGame:(NSDictionary *)game deleting:(BOOL)deleting {
    BOOL builtin=[game[@"id"] isEqualToString:@"builtin-demo"];
    if(deleting && builtin) return;
    NSString *title=deleting?@"删除游戏":@"清空游戏数据";
    NSString *detail=deleting?@"删除该游戏的 JAR 和独立存档（RMS）。此操作不可撤销。":@"清空该游戏的独立存档（RMS），包括通常保存在其中的进度和设置；游戏文件会保留。此操作不可撤销。";
    detail=[detail stringByAppendingString:@"\n共用 Files 目录中的导出文件会保留，不会删除其他游戏的数据。"];
    UIAlertController *alert=[UIAlertController alertControllerWithTitle:title message:[NSString stringWithFormat:@"%@\n\n%@",game[@"title"],detail] preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:title style:UIAlertActionStyleDestructive handler:^(UIAlertAction *){
        NSError *error=nil;
        BOOL ok=deleting?NJDeleteImportedGame(documents(),[game[@"path"] lastPathComponent],&error):NJClearGameData(documents(),game[@"id"],&error);
        [self reload];
        if(!ok) [self dismissViewControllerAnimated:YES completion:^{
            message(self,@"未能完成",[NSString stringWithFormat:@"%@\n部分文件可能已经移除。",error.localizedDescription?:@"文件操作失败"]);
        }];
    }]];
    [self presentViewController:alert animated:YES completion:nil];
}
- (void)tableView:(UITableView *)table accessoryButtonTappedForRowWithIndexPath:(NSIndexPath *)path {
    (void)table;
    NSDictionary *game=_games[path.row];
    UIAlertController *a=[UIAlertController alertControllerWithTitle:game[@"title"] message:@"管理此游戏" preferredStyle:UIAlertControllerStyleAlert];
    [a addAction:[UIAlertAction actionWithTitle:@"清空游戏数据" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *){
        [self dismissViewControllerAnimated:YES completion:^{[self confirmManageGame:game deleting:NO];}];
    }]];
    if(![game[@"id"] isEqualToString:@"builtin-demo"])
        [a addAction:[UIAlertAction actionWithTitle:@"删除游戏" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *){
            [self dismissViewControllerAnimated:YES completion:^{[self confirmManageGame:game deleting:YES];}];
        }]];
    [a addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:a animated:YES completion:nil];
}
- (UISwipeActionsConfiguration *)tableView:(UITableView *)table trailingSwipeActionsConfigurationForRowAtIndexPath:(NSIndexPath *)path {
    (void)table; NSDictionary *game=_games[path.row];
    NSMutableArray<UIContextualAction *> *actions=[NSMutableArray array];
    if(![game[@"id"] isEqualToString:@"builtin-demo"]) {
        [actions addObject:[UIContextualAction contextualActionWithStyle:UIContextualActionStyleDestructive title:@"删除游戏" handler:^(UIContextualAction *,UIView *,void (^done)(BOOL)){
            done(YES); [self confirmManageGame:game deleting:YES];
        }]];
    }
    UIContextualAction *clear=[UIContextualAction contextualActionWithStyle:UIContextualActionStyleNormal title:@"清空数据" handler:^(UIContextualAction *,UIView *,void (^done)(BOOL)){
        done(YES); [self confirmManageGame:game deleting:NO];
    }];
    clear.backgroundColor=UIColor.systemOrangeColor; [actions addObject:clear];
    UISwipeActionsConfiguration *configuration=[UISwipeActionsConfiguration configurationWithActions:actions];
    configuration.performsFirstActionWithFullSwipe=NO; return configuration;
}
- (void)tableView:(UITableView *)table didSelectRowAtIndexPath:(NSIndexPath *)path {
    [table deselectRowAtIndexPath:path animated:YES];
    if(_activeGame || self.presentedViewController || self.navigationController.presentedViewController) return;
    NSDictionary *game=_games[path.row]; GameController *vc=[GameController new];
    vc.jarPath=game[@"path"]; vc.saveID=game[@"id"]; vc.title=game[@"title"];
    // Keep the game OUT of the library's navigation stack. Full-screen return
    // tweaks can add their own pop recognizer, ignoring interactivePop.enabled.
    vc.modalPresentationStyle=UIModalPresentationFullScreen;
    vc.modalInPresentation=YES;
    vc.modalPresentationCapturesStatusBarAppearance=YES;
    __weak LibraryController *weakSelf=self;
    vc.onFinish=^(int status) {
        LibraryController *owner=weakSelf;
        if(!owner) return;
        owner->_activeGame=nil;
        [owner updateGameAvailability];
        if(status<0) message(owner,@"游戏运行失败",[NSString stringWithFormat:@"错误码 %d。请从游戏列表导出运行日志。",status]);
    };
    _activeGame=vc; [self updateGameAvailability];
    [self presentViewController:vc animated:NO completion:nil];
}
- (void)updateGameAvailability {
    // A forced return must not launch a second VM or modify its storage while
    // the first worker is still destroying the game and closing audio.
    BOOL available=_activeGame==nil;
    self.view.userInteractionEnabled=available;
    self.navigationItem.leftBarButtonItem.enabled=available;
    self.navigationItem.rightBarButtonItem.enabled=available;
}
- (void)importJar {
    UIDocumentPickerViewController *picker=[[UIDocumentPickerViewController alloc] initForOpeningContentTypes:@[UTTypeData] asCopy:YES];
    picker.delegate=self; picker.allowsMultipleSelection=YES; [self presentViewController:picker animated:YES completion:nil];
}
- (void)documentPicker:(UIDocumentPickerViewController *)picker didPickDocumentsAtURLs:(NSArray<NSURL *> *)urls {
    (void)picker;
    NSMutableArray *errors=[NSMutableArray array];
    for(NSURL *url in urls) {
        BOOL scoped=[url startAccessingSecurityScopedResource];
        NSError *error=nil; NSNumber *size=nil; [url getResourceValue:&size forKey:NSURLFileSizeKey error:&error];
        if(![url.pathExtension.lowercaseString isEqualToString:@"jar"] || !size || size.unsignedLongLongValue>64*1024*1024) {
            [errors addObject:[NSString stringWithFormat:@"%@：请选择不超过 64 MiB 的 JAR",url.lastPathComponent]];
        } else {
            NSData *data=[NSData dataWithContentsOfURL:url options:0 error:&error];
            const uint8_t *bytes=(const uint8_t *)data.bytes;
            if(!data || data.length<4 || bytes[0]!='P' || bytes[1]!='K') {
                [errors addObject:[NSString stringWithFormat:@"%@：无法读取 JAR 压缩包",url.lastPathComponent]];
            } else {
                unsigned char digest[CC_SHA256_DIGEST_LENGTH]; CC_SHA256(data.bytes,(CC_LONG)data.length,digest);
                NSMutableString *hash=[NSMutableString string]; for(unsigned char byte:digest) [hash appendFormat:@"%02x",byte];
                NSString *path=[[documents() stringByAppendingPathComponent:@"Games"] stringByAppendingPathComponent:[hash stringByAppendingString:@".jar"]];
                if(![[NSFileManager defaultManager] fileExistsAtPath:path] && ![data writeToFile:path options:NSDataWritingAtomic error:&error]) [errors addObject:error.localizedDescription];
                else [url.lastPathComponent writeToFile:[path stringByAppendingString:@".title"] atomically:YES encoding:NSUTF8StringEncoding error:nil];
            }
        }
        if(scoped) [url stopAccessingSecurityScopedResource];
    }
    [self reload]; if(errors.count) message(self,@"部分文件未导入",[errors componentsJoinedByString:@"\n"]);
}
- (void)settings {
    UIAlertController *a=[UIAlertController alertControllerWithTitle:@"设置" message:@"分辨率和帧率上限在下次启动游戏时生效。默认 60 FPS，代码效率优化始终启用。横竖屏只改变界面布局。" preferredStyle:UIAlertControllerStyleAlert];
    NSArray *resolutions=@[@"240 × 320",@"176 × 208",@"128 × 160",@"320 × 240"];
    NSInteger current=[NSUserDefaults.standardUserDefaults integerForKey:@"resolution"];
    for(NSInteger i=0;i<4;i++) [a addAction:[UIAlertAction actionWithTitle:[NSString stringWithFormat:@"%@%@",current==i?@"✓ ":@"",resolutions[i]] style:UIAlertActionStyleDefault handler:^(UIAlertAction *){[NSUserDefaults.standardUserDefaults setInteger:i forKey:@"resolution"];}]];
    BOOL powerSave=[NSUserDefaults.standardUserDefaults boolForKey:@"powerSave"];
    [a addAction:[UIAlertAction actionWithTitle:powerSave?@"帧率上限：30 → 60 FPS":@"帧率上限：60 → 30 FPS" style:UIAlertActionStyleDefault handler:^(UIAlertAction *){[NSUserDefaults.standardUserDefaults setBool:!powerSave forKey:@"powerSave"];}]];
    BOOL capture=[NSUserDefaults.standardUserDefaults boolForKey:@"capturePCM"];
    [a addAction:[UIAlertAction actionWithTitle:capture?@"取消下次音频诊断录制":@"下次游戏录制音频诊断（最多 30 秒）" style:UIAlertActionStyleDefault handler:^(UIAlertAction *){
        [NSUserDefaults.standardUserDefaults setBool:!capture forKey:@"capturePCM"];
    }]];
    [a addAction:[UIAlertAction actionWithTitle:@"导出上次运行日志" style:UIAlertActionStyleDefault handler:^(UIAlertAction *){
        NSURL *url=[NSURL fileURLWithPath:[documents() stringByAppendingPathComponent:@"latest-session.log"]];
        if(![[NSFileManager defaultManager] fileExistsAtPath:url.path]) { message(self,@"暂无日志",@"请运行一次游戏并正常退出。"); return; }
        NSMutableArray *items=[NSMutableArray arrayWithObject:url];
        NSURL *pcm=[NSURL fileURLWithPath:[documents() stringByAppendingPathComponent:@"latest-session-pcm.wav"]];
        if([[NSFileManager defaultManager] fileExistsAtPath:pcm.path]) [items addObject:pcm];
        UIActivityViewController *share=[[UIActivityViewController alloc] initWithActivityItems:items applicationActivities:nil];
        [self presentViewController:share animated:YES completion:nil];
    }]];
    [a addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:a animated:YES completion:nil];
}
@end

@interface NavigationController : UINavigationController
@end
@implementation NavigationController
- (UIInterfaceOrientationMask)supportedInterfaceOrientations { return self.topViewController.supportedInterfaceOrientations; }
- (UIViewController *)childViewControllerForStatusBarHidden { return self.topViewController; }
- (UIViewController *)childViewControllerForScreenEdgesDeferringSystemGestures { return self.topViewController; }
@end
@interface AppDelegate : UIResponder <UIApplicationDelegate>
@property(nonatomic,strong) UIWindow *window;
@end
@implementation AppDelegate
- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)options {
    (void)application;(void)options;
    [NSUserDefaults.standardUserDefaults registerDefaults:@{@"volume":@0.7,@"resolution":@0,@"pixel":@NO,@"fps":@NO}];
    self.window=[[UIWindow alloc] initWithFrame:UIScreen.mainScreen.bounds];
    self.window.overrideUserInterfaceStyle=UIUserInterfaceStyleDark;
    self.window.tintColor=accent();
    self.window.rootViewController=[[NavigationController alloc] initWithRootViewController:[LibraryController new]];
    [self.window makeKeyAndVisible]; return YES;
}
@end
int main(int argc,char **argv) { @autoreleasepool { return UIApplicationMain(argc,argv,nil,NSStringFromClass(AppDelegate.class)); } }
