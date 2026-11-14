#import "NJSession.h"
#import <AVFoundation/AVFoundation.h>
#include "AudioOutput.hpp"
#include "nj_posix_dir.h"
#include <condition_variable>
#include <deque>
#include <mutex>
#include <vector>
#include <ctime>
#include <cmath>
#include <thread>
#include <chrono>

struct State {
    std::mutex lock;
    std::condition_variable condition;
    std::deque<nj_event> events;
    bool stop=false, paused=false, dirty=false;
    int width,height;
    float volume=0.7f;
    float appliedVolume=-1;
    NSUInteger frames=0;
    std::vector<uint32_t> pixels, snapshot;
    AudioOutput audio;
    __strong AVAudioPlayer *tone=nil;
    __strong NSMutableString *logs=[NSMutableString string];
    __strong NSString *rms=nil, *files=nil;
    explicit State(int w,int h):width(w),height(h),pixels(w*h),snapshot(w*h) {}
};
static nj_u4 millis(void *) {
    return (nj_u4)std::chrono::duration_cast<std::chrono::milliseconds>(std::chrono::steady_clock::now().time_since_epoch()).count();
}
static void yieldVM(void *ud) {
    auto *s=(State *)ud;
    std::unique_lock<std::mutex> guard(s->lock);
    float volume=s->volume;
    bool park=s->paused && !s->stop;
    guard.unlock();
    if(volume!=s->appliedVolume) {
        s->audio.volume(volume); s->tone.volume=volume; s->appliedVolume=volume;
    }
    if(park) {
        s->audio.pause(true); [s->tone pause];
        guard.lock(); s->condition.wait(guard,[s]{return !s->paused || s->stop;}); guard.unlock();
        s->audio.pause(false); [s->tone play];
    }
}
static void sleepVM(void *ud,nj_u4 ms) {
    yieldVM(ud);
    auto *s=(State *)ud;
    std::unique_lock<std::mutex> guard(s->lock);
    s->condition.wait_for(guard,std::chrono::milliseconds(std::min(ms,50u)),[s]{return s->stop || s->paused;});
}
static int poll(void *ud,nj_event *event) {
    yieldVM(ud);
    auto *s=(State *)ud;
    std::lock_guard<std::mutex> guard(s->lock);
    if(s->stop) { s->stop=false; *event={}; event->type=NJ_EV_QUIT; return 1; }
    if(s->events.empty()) return 0;
    *event=s->events.front(); s->events.pop_front(); return 1;
}
static int initDisplay(void *ud,int *w,int *h,int *stride,void **pixels) {
    auto *s=(State *)ud; *w=s->width; *h=s->height; *stride=*w*4; *pixels=s->pixels.data();
    return NJ_PIXFMT_ARGB8888;
}
static void present(void *ud,int,int,int,int) {
    auto *s=(State *)ud; std::lock_guard<std::mutex> guard(s->lock);
    if(s->pixels!=s->snapshot) { s->snapshot=s->pixels; s->dirty=true; s->frames++; }
}
static void logVM(void *ud,int level,const char *msg) {
    @autoreleasepool {
        auto *s=(State *)ud;
        NSString *text=msg?[NSString stringWithUTF8String:msg]:@"";
        std::lock_guard<std::mutex> guard(s->lock);
        [s->logs appendFormat:@"[%d] %@\n",level,text?:@"(invalid UTF-8)"];
        if(s->logs.length>65536) [s->logs deleteCharactersInRange:NSMakeRange(0,s->logs.length-49152)];
    }
}
static int now(void *,nj_datetime *out) {
    time_t t=time(nullptr); struct tm local={}; localtime_r(&t,&local);
    *out={}; out->year=local.tm_year+1900; out->month=local.tm_mon; out->day=local.tm_mday;
    out->hour=local.tm_hour; out->minute=local.tm_min; out->second=local.tm_sec;
    out->weekday=local.tm_wday; out->tz_offset=(int)(local.tm_gmtoff/60); return 1;
}
static int pcmOpen(void *ud,int rate,int channels) {
    auto *s=(State *)ud; s->appliedVolume=-1; return s->audio.open(rate,channels);
}
static int pcmWrite(void *ud,const nj_s2 *p,int n) { return ((State *)ud)->audio.write(p,n); }
static int pcmFree(void *ud) { return ((State *)ud)->audio.freeFrames(); }
static int pcmQueued(void *ud) { return ((State *)ud)->audio.queuedFrames(); }
static void pcmClose(void *ud) { ((State *)ud)->audio.close(); }
static void toneStop(void *ud) { auto *s=(State *)ud; [s->tone stop]; s->tone=nil; }
static int tonePlay(void *ud,const nj_audio_tone *tones,int count) {
    auto *s=(State *)ud; toneStop(ud);
    if(!tones || count<1 || count>4096) return -1;
    uint64_t n=0; for(int i=0;i<count;i++) n+=(uint64_t)tones[i].duration_ms*22050/1000;
    if(n>22050*120 || !n) return -1;
    NSMutableData *wav=[NSMutableData dataWithLength:44+n*2];
    auto *b=(uint8_t *)wav.mutableBytes;
    auto u16=[&](int o,uint16_t v){b[o]=v&255;b[o+1]=v>>8;};
    auto u32=[&](int o,uint32_t v){for(int i=0;i<4;i++) b[o+i]=(v>>(8*i))&255;};
    memcpy(b,"RIFF",4); u32(4,(uint32_t)n*2+36); memcpy(b+8,"WAVEfmt ",8);
    u32(16,16); u16(20,1); u16(22,1); u32(24,22050); u32(28,44100); u16(32,2); u16(34,16);
    memcpy(b+36,"data",4); u32(40,(uint32_t)n*2);
    int16_t *samples=(int16_t *)(b+44); size_t pos=0;
    for(int i=0;i<count;i++) for(uint32_t j=0;j<(uint32_t)tones[i].duration_ms*22050/1000;j++)
        samples[pos++]=(int16_t)(sin(6.283185307179586*tones[i].freq_hz*j/22050)*6000);
    NSError *error=nil; s->tone=[[AVAudioPlayer alloc] initWithData:wav error:&error];
    { std::lock_guard<std::mutex> guard(s->lock); s->tone.volume=s->volume; }
    return s->tone && [s->tone play]?0:-1;
}

@implementation NJSession { State *_state; BOOL _started; }
- (instancetype)initWithWidth:(int)width height:(int)height {
    if((self=[super init])) { _state=new State(width,height); _width=width; _height=height; }
    return self;
}
- (void)dealloc { delete _state; }
- (void)startJar:(NSString *)path saveID:(NSString *)saveID completion:(void (^)(int))completion {
    NSAssert(!_started,@"A session can only be started once"); _started=YES;
    NSString *docs=NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,NSUserDomainMask,YES).firstObject;
    _state->rms=[docs stringByAppendingPathComponent:[@"Saves" stringByAppendingPathComponent:saveID]];
    _state->files=[docs stringByAppendingPathComponent:@"Files"];
    NSError *error=nil;
    for(NSString *dir in @[_state->rms,_state->files]) {
        if(![[NSFileManager defaultManager] createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:nil error:&error]) {
            logVM(_state,0,error.localizedDescription.UTF8String);
            dispatch_async(dispatch_get_main_queue(),^{ completion(-1); }); return;
        }
    }
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED,0),^{
        @autoreleasepool {
            State *s=self->_state;
            nj_port port={}; port.name="ios"; port.ud=s; port.user=s;
            port.millis=millis; port.now=now; port.idle=yieldVM; port.sleep_ms=sleepVM;
            port.log=logVM; port.display_init=initDisplay; port.display_present=present;
            port.input_poll=poll; port.rms_dir=s->rms.UTF8String; port.fs_dir=s->files.UTF8String;
            port.dir_open=nj_posix_dir_open; port.dir_next=nj_posix_dir_next; port.dir_close=nj_posix_dir_close;
            port.pcm_open=pcmOpen; port.pcm_write=pcmWrite; port.pcm_close=pcmClose;
            port.pcm_free=pcmFree; port.pcm_queued=pcmQueued;
            port.tone_play=tonePlay; port.tone_stop=toneStop; port.fps_cap=60;
            nj_run_opts options={}; options.jar_path=path.UTF8String;
            options.heap_bytes=32u*1024u*1024u; options.device=nj_device_find("nokia6230");
            options.stats=1;
            int result=nj_run(&port,&options);
            s->audio.close(); toneStop(s);
            dispatch_async(dispatch_get_main_queue(),^{ completion(result); });
        }
    });
}
- (void)sendEvent:(nj_event)event { std::lock_guard<std::mutex> guard(_state->lock); _state->events.push_back(event); }
- (void)stop { std::lock_guard<std::mutex> guard(_state->lock); _state->stop=true; _state->paused=false; _state->condition.notify_all(); }
- (void)setPaused:(BOOL)paused { std::lock_guard<std::mutex> guard(_state->lock); _state->paused=paused; _state->condition.notify_all(); }
- (void)setVolume:(float)volume { std::lock_guard<std::mutex> guard(_state->lock); _state->volume=volume; }
- (NSUInteger)frameCount { std::lock_guard<std::mutex> guard(_state->lock); return _state->frames; }
- (NSString *)logText { std::lock_guard<std::mutex> guard(_state->lock); return [_state->logs copy]; }
- (UIImage *)takeFrame {
    NSData *data;
    { std::lock_guard<std::mutex> guard(_state->lock);
      if(!_state->dirty) return nil; _state->dirty=false;
      data=[NSData dataWithBytes:_state->snapshot.data() length:_state->snapshot.size()*4]; }
    CGDataProviderRef provider=CGDataProviderCreateWithCFData((__bridge CFDataRef)data);
    CGColorSpaceRef space=CGColorSpaceCreateDeviceRGB();
    CGImageRef image=CGImageCreate(_width,_height,8,32,_width*4,space,kCGBitmapByteOrder32Little|kCGImageAlphaNoneSkipFirst,provider,nullptr,false,kCGRenderingIntentDefault);
    UIImage *result=[UIImage imageWithCGImage:image];
    CGImageRelease(image); CGColorSpaceRelease(space); CGDataProviderRelease(provider); return result;
}
@end
