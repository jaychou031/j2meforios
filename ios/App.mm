#import <UIKit/UIKit.h>
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>
#import <AVFoundation/AVFoundation.h>
#import <CommonCrypto/CommonDigest.h>
#import "NJSession.h"
#include "Controls.hpp"

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
@end
struct KeyCap { int code; __unsafe_unretained NSString *label; controls::Rect rect; };
@implementation GameSurface {
    std::vector<KeyCap> _keys;
    controls::HeldKeys _held;
    __weak UITouch *_pointer;
    CGPoint _lastPointer;
    controls::Rect _screen;
}
- (instancetype)init { if((self=[super init])) { self.multipleTouchEnabled=YES; self.backgroundColor=UIColor.blackColor; } return self; }
- (void)key:(int)key down:(BOOL)down {
    nj_event e={}; e.type=down?NJ_EV_KEY_DOWN:NJ_EV_KEY_UP; e.key=key; [_session sendEvent:e];
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
    _pointer=nil; [self setNeedsDisplay];
}
- (void)layoutSubviews {
    [super layoutSubviews]; [self releaseTouches]; _keys.clear();
    auto layout=controls::layout(self.bounds.size.width,self.bounds.size.height);
    _screen=controls::fit(layout.viewport,_session.width?:240,_session.height?:320,_pixel,self.window.screen.scale?:3);
    const int left[15]={0,NJ_KEY_UP,0,NJ_KEY_LEFT,NJ_KEY_FIRE,NJ_KEY_RIGHT,0,NJ_KEY_DOWN,0,NJ_KEY_GAME_A,NJ_KEY_GAME_B,NJ_KEY_GAME_C,NJ_KEY_GAME_D,NJ_KEY_SOFT_LEFT,NJ_KEY_CLEAR};
    NSArray *labels=@[@"",@"▲",@"",@"◀",@"FIRE",@"▶",@"",@"▼",@"",@"A",@"B",@"C",@"D",@"左软键",@"CLEAR"];
    for(int i=0;i<15;i++) if(left[i]) _keys.push_back({left[i],labels[i],controls::cell(layout.left,i%3,i/3)});
    const int right[15]={NJ_KEY_1,NJ_KEY_2,NJ_KEY_3,NJ_KEY_4,NJ_KEY_5,NJ_KEY_6,NJ_KEY_7,NJ_KEY_8,NJ_KEY_9,NJ_KEY_STAR,NJ_KEY_0,NJ_KEY_POUND,0,NJ_KEY_SOFT_RIGHT,0};
    NSArray *digits=@[@"1",@"2",@"3",@"4",@"5",@"6",@"7",@"8",@"9",@"*",@"0",@"#",@"",@"右软键",@""];
    for(int i=0;i<15;i++) if(right[i]) _keys.push_back({right[i],digits[i],controls::cell(layout.right,i%3,i/3)});
    [self setNeedsDisplay];
}
- (void)setPixel:(BOOL)pixel { _pixel=pixel; [self setNeedsLayout]; }
- (void)drawRect:(CGRect)rect {
    (void)rect;
    CGContextRef context=UIGraphicsGetCurrentContext();
    CGContextSetInterpolationQuality(context,_pixel?kCGInterpolationNone:kCGInterpolationLow);
    [_gameImage drawInRect:cg(_screen)];
    for(auto key:_keys) {
        UIColor *fill=_held.down(key.code)?accent():[UIColor colorWithWhite:0.13 alpha:1];
        [fill setFill]; [[UIBezierPath bezierPathWithRoundedRect:cg(key.rect) cornerRadius:9] fill];
        NSDictionary *attributes=@{NSFontAttributeName:[UIFont systemFontOfSize:14 weight:UIFontWeightSemibold],NSForegroundColorAttributeName:_held.down(key.code)?UIColor.blackColor:UIColor.whiteColor};
        CGSize size=[key.label sizeWithAttributes:attributes];
        [key.label drawAtPoint:CGPointMake(key.rect.x+(key.rect.w-size.width)/2,key.rect.y+(key.rect.h-size.height)/2) withAttributes:attributes];
    }
}
- (void)updateTouches:(NSSet<UITouch *> *)touches ending:(BOOL)ending {
    for(UITouch *touch in touches) {
        CGPoint p=[touch locationInView:self]; int code=0;
        if(!ending) for(auto cap:_keys) if(cap.rect.contains(p.x,p.y)) { code=cap.code; break; }
        uintptr_t token=(uintptr_t)(__bridge void *)touch;
        _held.move(token,code,[&](int k,bool d){[self key:k down:d];});
        if(_pointer==touch) {
            if(ending || code || !_screen.contains(p.x,p.y)) { [self pointer:NJ_EV_POINTER_UP point:p]; _pointer=nil; }
            else [self pointer:NJ_EV_POINTER_MOVE point:p];
        } else if(!ending && !code && !_pointer && _screen.contains(p.x,p.y)) {
            _pointer=touch; [self pointer:NJ_EV_POINTER_DOWN point:p];
        }
    }
    [self setNeedsDisplay];
}
- (void)touchesBegan:(NSSet<UITouch *> *)t withEvent:(UIEvent *)e { (void)e; [self updateTouches:t ending:NO]; }
- (void)touchesMoved:(NSSet<UITouch *> *)t withEvent:(UIEvent *)e { (void)e; [self updateTouches:t ending:NO]; }
- (void)touchesEnded:(NSSet<UITouch *> *)t withEvent:(UIEvent *)e { (void)e; [self updateTouches:t ending:YES]; }
- (void)touchesCancelled:(NSSet<UITouch *> *)t withEvent:(UIEvent *)e { (void)e; [self updateTouches:t ending:YES]; }
@end

@interface GameController : UIViewController
@property(nonatomic,copy) NSString *jarPath;
@property(nonatomic,copy) NSString *saveID;
@end
@implementation GameController {
    NJSession *_session;
    GameSurface *_surface;
    UIStackView *_toolbar;
    UIButton *_fps;
    CADisplayLink *_timer;
    NSTimeInterval _lastTime;
    NSUInteger _lastFrames;
    BOOL _showFPS, _locked, _stopping, _audioInterrupted;
    UIInterfaceOrientationMask _lockMask;
    float _volume;
}
- (BOOL)prefersStatusBarHidden { return YES; }
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
    [AVAudioSession.sharedInstance setActive:YES error:&error];
    _timer=[CADisplayLink displayLinkWithTarget:self selector:@selector(tick:)];
    [_timer addToRunLoop:NSRunLoop.mainRunLoop forMode:NSRunLoopCommonModes];
    UIApplication.sharedApplication.idleTimerDisabled=YES;
    __weak GameController *weakSelf=self;
    [_session startJar:_jarPath saveID:_saveID completion:^(int status){ [weakSelf finished:status]; }];
}
- (void)viewWillAppear:(BOOL)animated { [super viewWillAppear:animated]; [self.navigationController setNavigationBarHidden:YES animated:animated]; }
- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews]; CGRect safe=UIEdgeInsetsInsetRect(self.view.bounds,self.view.safeAreaInsets);
    _toolbar.frame=CGRectMake(safe.origin.x,safe.origin.y,safe.size.width,44);
    _surface.frame=CGRectMake(safe.origin.x,safe.origin.y+44,safe.size.width,MAX(1,safe.size.height-44));
}
- (void)tick:(CADisplayLink *)timer {
    UIImage *frame=[_session takeFrame]; if(frame) { _surface.gameImage=frame; [_surface setNeedsDisplay]; }
    if(timer.timestamp-_lastTime>=0.5) {
        NSUInteger count=_session.frameCount;
        double fps=_lastTime?(count-_lastFrames)/(timer.timestamp-_lastTime):0;
        [_fps setTitle:_showFPS?[NSString stringWithFormat:@"%.0f FPS",fps]:@"FPS 关" forState:UIControlStateNormal];
        _lastFrames=count; _lastTime=timer.timestamp;
    }
}
- (void)scale { _surface.pixel=!_surface.pixel; [NSUserDefaults.standardUserDefaults setBool:_surface.pixel forKey:@"pixel"]; }
- (void)toggleFPS { _showFPS=!_showFPS; [NSUserDefaults.standardUserDefaults setBool:_showFPS forKey:@"fps"]; }
- (void)volumeBy:(float)delta { _volume=std::clamp(_volume+delta,0.0f,1.0f); [_session setVolume:_volume]; [NSUserDefaults.standardUserDefaults setFloat:_volume forKey:@"volume"]; }
- (void)quieter { [self volumeBy:-0.1f]; }
- (void)louder { [self volumeBy:0.1f]; }
- (void)inactive { [_surface releaseTouches]; [_session setPaused:YES]; }
- (void)notificationInactive:(NSNotification *)notification { (void)notification; [self inactive]; }
- (void)notificationActive:(NSNotification *)notification { (void)notification; [self active]; }
- (void)active {
    if(!_audioInterrupted && !self.presentedViewController && !_stopping) {
        [AVAudioSession.sharedInstance setActive:YES error:nil]; [_session setPaused:NO];
    }
}
- (void)audioInterrupted:(NSNotification *)notification {
    _audioInterrupted=[notification.userInfo[AVAudioSessionInterruptionTypeKey] unsignedIntegerValue]==AVAudioSessionInterruptionTypeBegan;
    if(_audioInterrupted) [self inactive]; else [self active];
}
- (void)resume { if(UIApplication.sharedApplication.applicationState==UIApplicationStateActive && !_audioInterrupted) [_session setPaused:NO]; }
- (void)menu {
    if(_stopping) return;
    [self inactive];
    UIAlertController *a=[UIAlertController alertControllerWithTitle:self.title message:[NSString stringWithFormat:@"音量 %.0f%% · %@ · %d×%d",_volume*100,_surface.pixel?@"整数倍":@"最大尺寸",_session.width,_session.height] preferredStyle:UIAlertControllerStyleAlert];
    [a addAction:[UIAlertAction actionWithTitle:@"继续游戏" style:UIAlertActionStyleCancel handler:^(UIAlertAction *){[self resume];}]];
    [a addAction:[UIAlertAction actionWithTitle:_locked?@"解除方向锁定":@"锁定当前方向" style:UIAlertActionStyleDefault handler:^(UIAlertAction *){
        UIInterfaceOrientation o=self.view.window.windowScene?self.view.window.windowScene.interfaceOrientation:UIApplication.sharedApplication.statusBarOrientation;
        self->_lockMask=(UIInterfaceOrientationMask)(1<<o); self->_locked=!self->_locked;
        [UIViewController attemptRotationToDeviceOrientation]; [self resume];
    }]];
    [a addAction:[UIAlertAction actionWithTitle:@"结束并返回游戏列表" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *){
        self->_stopping=YES; self->_toolbar.userInteractionEnabled=NO; [self->_session stop];
    }]];
    [self presentViewController:a animated:YES completion:nil];
}
- (void)finished:(int)status {
    [_timer invalidate]; _timer=nil; [_surface releaseTouches];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    UIApplication.sharedApplication.idleTimerDisabled=NO;
    [AVAudioSession.sharedInstance setActive:NO withOptions:AVAudioSessionSetActiveOptionNotifyOthersOnDeactivation error:nil];
    NSString *path=[documents() stringByAppendingPathComponent:@"latest-session.log"];
    [_session.logText writeToFile:path atomically:YES encoding:NSUTF8StringEncoding error:nil];
    if(self.presentedViewController) [self dismissViewControllerAnimated:NO completion:nil];
    UIViewController *library=self.navigationController.viewControllers.firstObject;
    [self.navigationController popViewControllerAnimated:NO];
    if(status<0) message(library,@"游戏运行失败",[NSString stringWithFormat:@"错误码 %d。请从游戏列表导出运行日志。",status]);
}
@end

@interface LibraryController : UITableViewController <UIDocumentPickerDelegate>
@end
@implementation LibraryController { NSArray<NSDictionary *> *_games; }
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
    cell.detailTextLabel.text=path.row==0?@"验证画面、按键、音调和 RMS":@"点击启动 · 从菜单正常退出以保存";
    cell.accessoryType=UITableViewCellAccessoryDisclosureIndicator; return cell;
}
- (void)tableView:(UITableView *)table didSelectRowAtIndexPath:(NSIndexPath *)path {
    [table deselectRowAtIndexPath:path animated:YES];
    NSDictionary *game=_games[path.row]; GameController *vc=[GameController new];
    vc.jarPath=game[@"path"]; vc.saveID=game[@"id"]; vc.title=game[@"title"];
    [self.navigationController pushViewController:vc animated:YES];
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
    UIAlertController *a=[UIAlertController alertControllerWithTitle:@"设置" message:@"游戏逻辑分辨率在下次启动时生效。横竖屏只改变界面布局。" preferredStyle:UIAlertControllerStyleAlert];
    NSArray *resolutions=@[@"240 × 320",@"176 × 208",@"128 × 160",@"320 × 240"];
    NSInteger current=[NSUserDefaults.standardUserDefaults integerForKey:@"resolution"];
    for(NSInteger i=0;i<4;i++) [a addAction:[UIAlertAction actionWithTitle:[NSString stringWithFormat:@"%@%@",current==i?@"✓ ":@"",resolutions[i]] style:UIAlertActionStyleDefault handler:^(UIAlertAction *){[NSUserDefaults.standardUserDefaults setInteger:i forKey:@"resolution"];}]];
    [a addAction:[UIAlertAction actionWithTitle:@"导出上次运行日志" style:UIAlertActionStyleDefault handler:^(UIAlertAction *){
        NSURL *url=[NSURL fileURLWithPath:[documents() stringByAppendingPathComponent:@"latest-session.log"]];
        if(![[NSFileManager defaultManager] fileExistsAtPath:url.path]) { message(self,@"暂无日志",@"请运行一次游戏并正常退出。"); return; }
        UIActivityViewController *share=[[UIActivityViewController alloc] initWithActivityItems:@[url] applicationActivities:nil];
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
