#import "NJSession.h"
#import <AVFoundation/AVFoundation.h>
#include "AudioOutput.hpp"
#include "InputQueue.hpp"
#include "ToneSample.hpp"
#include "SoundFontSynth.h"
#include "SessionLifecycle.hpp"
#import "GameStorage.h"
#include "nj_posix_dir.h"
#include <condition_variable>
#include <deque>
#include <mutex>
#include <vector>
#include <ctime>
#include <cmath>
#include <thread>
#include <chrono>
#include <atomic>

struct State {
    std::mutex lock;
    std::mutex frameLock;
    std::mutex inputLock;
    std::mutex logLock;
    std::condition_variable condition;
    controls::InputQueue input;
    bool stop=false, paused=false, dirty=false, inputWake=false;
    bool audioAvailable=true, audioPaused=false, toneWasPlaying=false;
    session::Clock clock;
    int width,height, frameRate=60;
    float volume=0.7f;
    float appliedVolume=-1;
    std::atomic<NSUInteger> frames{0};
    std::vector<uint32_t> pixels, snapshot;
    AudioOutput audio;
    __strong AVAudioPlayer *tone=nil;
    __strong NSMutableString *logs=[NSMutableString string];
    __strong NSString *rms=nil, *files=nil;
    nj_sf_stats soundfontStart{};
    explicit State(int w,int h):width(w),height(h),pixels(w*h),snapshot(w*h) {}
};
static uint64_t hostMillis() {
    return (uint64_t)std::chrono::duration_cast<std::chrono::milliseconds>(std::chrono::steady_clock::now().time_since_epoch()).count();
}
static nj_u4 millis(void *ud) {
    if(!ud) return (nj_u4)hostMillis(); // Input diagnostics use real elapsed time.
    auto *s=(State *)ud;
    std::lock_guard<std::mutex> guard(s->lock);
    return (nj_u4)s->clock.now(hostMillis());
}
static void yieldVM(void *ud) {
    auto *s=(State *)ud;
    for(;;) {
        std::unique_lock<std::mutex> guard(s->lock);
        float volume=s->volume;
        bool park=s->paused && !s->stop;
        bool audioPause=park || !s->audioAvailable || s->stop;
        guard.unlock();
        if(volume!=s->appliedVolume) {
            s->audio.volume(volume); s->tone.volume=volume; s->appliedVolume=volume;
        }
        if(audioPause!=s->audioPaused) {
            s->audioPaused=audioPause;
            s->audio.pause(audioPause);
            if(audioPause) { s->toneWasPlaying=s->tone.playing; [s->tone pause]; }
            else if(s->toneWasPlaying) { [s->tone play]; s->toneWasPlaying=false; }
        }
        if(!park) return;
        guard.lock(); s->condition.wait(guard,[s]{return !s->paused || s->stop;});
        // Loop re-reads both gates after the wait, including forced quit.
    }
}
static void sleepVM(void *ud,nj_u4 ms) {
    yieldVM(ud);
    auto *s=(State *)ud;
    std::unique_lock<std::mutex> guard(s->lock);
    s->condition.wait_for(guard,std::chrono::milliseconds(std::min(ms,50u)),[s]{return s->stop || s->paused || s->inputWake;});
    // The core may sleep again before the next input poll to pace a frame.
    // Consume each wake once; a nonempty queue must not cause a busy loop.
    s->inputWake=false;
}
static int poll(void *ud,nj_event *event) {
    yieldVM(ud);
    auto *s=(State *)ud;
    {
        std::lock_guard<std::mutex> guard(s->lock);
        if(s->stop) { s->stop=false; *event={}; event->type=NJ_EV_QUIT; return 1; }
    }
    std::lock_guard<std::mutex> guard(s->inputLock);
    return s->input.pop(*event,millis(nullptr))?1:0;
}
static int initDisplay(void *ud,int *w,int *h,int *stride,void **pixels) {
    auto *s=(State *)ud; *w=s->width; *h=s->height; *stride=*w*4; *pixels=s->pixels.data();
    return NJ_PIXFMT_ARGB8888;
}
static void present(void *ud,int,int,int,int) {
    auto *s=(State *)ud; std::lock_guard<std::mutex> guard(s->frameLock);
    if(s->pixels!=s->snapshot) { s->snapshot=s->pixels; s->dirty=true; s->frames++; }
}
static void logVM(void *ud,int level,const char *msg) {
    @autoreleasepool {
        auto *s=(State *)ud;
        NSString *text=msg?[NSString stringWithUTF8String:msg]:@"";
        std::lock_guard<std::mutex> guard(s->logLock);
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
    auto *s=(State *)ud; s->appliedVolume=-1;
    float volume;
    { std::lock_guard<std::mutex> guard(s->lock); volume=s->volume; }
    int result=s->audio.open(rate,channels);
    if(result==0) { s->audio.volume(volume); s->audio.pause(s->audioPaused); }
    return result;
}
static int pcmWrite(void *ud,const nj_s2 *p,int n) { return ((State *)ud)->audio.write(p,n); }
static int pcmFree(void *ud) { return ((State *)ud)->audio.freeFrames(); }
static int pcmQueued(void *ud) { return ((State *)ud)->audio.queuedFrames(); }
static void pcmClose(void *ud) {
    auto *s=(State *)ud; s->audio.close(); auto a=s->audio.stats();
    char line[256];
    snprintf(line,sizeof(line),"PCM_CLOSE rate=%d written=%llu played=%llu gaps=%llu gap_silence_frames=%llu last_error=%d",
        a.rate,(unsigned long long)a.written,(unsigned long long)a.played,
        (unsigned long long)a.starvationGaps,(unsigned long long)a.gapSilenceFrames,a.lastError);
    logVM(s,2,line);
}
static void toneStop(void *ud) { auto *s=(State *)ud; [s->tone stop]; s->tone=nil; s->toneWasPlaying=false; }
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
        samples[pos++]=audio::toneSample(tones[i].freq_hz,j,(uint32_t)tones[i].duration_ms*22050/1000,22050);
    NSError *error=nil; s->tone=[[AVAudioPlayer alloc] initWithData:wav error:&error];
    float volume;
    { std::lock_guard<std::mutex> guard(s->lock); volume=s->volume; }
    s->tone.volume=volume;
    if(s->audioPaused && s->tone) { s->toneWasPlaying=true; [s->tone prepareToPlay]; return 0; }
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
    _state->rms=NJGameRMSPath(docs,saveID);
    _state->files=[docs stringByAppendingPathComponent:@"Files"];
    if(!_state->rms) {
        logVM(_state,0,"Invalid game storage ID");
        dispatch_async(dispatch_get_main_queue(),^{ completion(-1); }); return;
    }
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
            { std::lock_guard<std::mutex> guard(s->logLock); s->soundfontStart=nj_sf_get_stats(); }
            NSString *fontPath=[[NSBundle mainBundle] pathForResource:@"GeneralUser-GS-SoftSynth-1.44" ofType:@"sf2"];
            int loaded=fontPath ? nj_sf_load_bank(fontPath.fileSystemRepresentation) : 0;
            logVM(s,loaded?2:0,loaded ? "SOUNDFONT loaded: GeneralUser GS SoftSynth 1.44 / TinySoundFont" :
                  "SOUNDFONT load failed: using core waveform fallback");
            nj_port port={}; port.name="ios"; port.ud=s; port.user=s;
            port.millis=millis; port.now=now; port.idle=yieldVM; port.sleep_ms=sleepVM;
            port.log=logVM; port.display_init=initDisplay; port.display_present=present;
            port.input_poll=poll; port.rms_dir=s->rms.UTF8String; port.fs_dir=s->files.UTF8String;
            port.dir_open=nj_posix_dir_open; port.dir_next=nj_posix_dir_next; port.dir_close=nj_posix_dir_close;
            port.pcm_open=pcmOpen; port.pcm_write=pcmWrite; port.pcm_close=pcmClose;
            port.pcm_free=pcmFree; port.pcm_queued=pcmQueued;
            port.tone_play=tonePlay; port.tone_stop=toneStop; port.fps_cap=s->frameRate;
            logVM(s,2,s->frameRate==30?"POWER frame_cap=30":"POWER frame_cap=60");
            nj_run_opts options={}; options.jar_path=path.UTF8String;
            options.heap_bytes=32u*1024u*1024u; options.device=nj_device_find("nokia6230");
            options.stats=1;
            int result=nj_run(&port,&options);
            unsigned released=nj_sf_release_thread_streams();
            if(released) { char text[96]; snprintf(text,sizeof(text),"SOUNDFONT teardown released %u unclosed streams",released); logVM(s,2,text); }
            s->audio.close(); toneStop(s);
            dispatch_async(dispatch_get_main_queue(),^{ completion(result); });
        }
    });
}
- (void)sendEvent:(nj_event)event {
    {
        std::lock_guard<std::mutex> guard(_state->inputLock);
        _state->input.push(event,millis(nullptr));
    }
    {
        std::lock_guard<std::mutex> guard(_state->lock);
        _state->inputWake=true;
    }
    _state->condition.notify_one();
}
- (void)stop { std::lock_guard<std::mutex> guard(_state->lock); _state->stop=true; _state->paused=false; _state->clock.setPaused(false,hostMillis()); _state->condition.notify_all(); }
- (void)setPaused:(BOOL)paused {
    { std::lock_guard<std::mutex> guard(_state->lock); _state->paused=paused; _state->clock.setPaused(paused,hostMillis()); _state->condition.notify_all(); }
    logVM(_state,2,paused?"LIFECYCLE vm_paused":"LIFECYCLE vm_resumed");
}
- (void)setAudioAvailable:(BOOL)available {
    { std::lock_guard<std::mutex> guard(_state->lock); _state->audioAvailable=available; _state->condition.notify_all(); }
    logVM(_state,2,available?"LIFECYCLE audio_available":"LIFECYCLE audio_interrupted");
}
- (void)setVolume:(float)volume { std::lock_guard<std::mutex> guard(_state->lock); _state->volume=volume; }
- (void)setFrameRate:(NSInteger)frameRate { NSAssert(!_started,@"Set frame rate before starting the VM"); _state->frameRate=frameRate==30?30:60; }
- (NSUInteger)frameCount { return _state->frames.load(std::memory_order_relaxed); }
- (NSString *)logText {
    NSString *text;
    nj_sf_stats baseline;
    { std::lock_guard<std::mutex> guard(_state->logLock); text=[_state->logs copy]; baseline=_state->soundfontStart; }
    auto sound=_state->audio.stats();
    text=[text stringByAppendingFormat:@"\nAUDIO rate=%d written=%llu played=%llu empty_frames=%llu saturated_samples=%llu peak_frames=%d last_error=%d gaps=%llu gap_silence_frames=%llu\n",
        sound.rate,(unsigned long long)sound.written,(unsigned long long)sound.played,
        (unsigned long long)sound.underrunFrames,(unsigned long long)sound.clippedSamples,sound.peak,sound.lastError,
        (unsigned long long)sound.starvationGaps,(unsigned long long)sound.gapSilenceFrames];
    auto sf=nj_sf_get_stats();
    text=[text stringByAppendingFormat:@"AUDIO_MIDI soundfont_streams=%llu waveform_fallbacks=%llu limited_samples=%llu errors=%llu active_streams=%llu\n",
        (unsigned long long)(sf.opened-baseline.opened),(unsigned long long)(sf.fallback-baseline.fallback),
        (unsigned long long)(sf.limited_samples-baseline.limited_samples),
        (unsigned long long)(sf.errors-baseline.errors),(unsigned long long)sf.active];
    std::lock_guard<std::mutex> guard(_state->inputLock);
    const auto& input=_state->input;
    return [text stringByAppendingFormat:@"\nINPUT delivered=%llu peak=%zu average_ms=%.2f max_ms=%llu\n",
            (unsigned long long)input.delivered,input.peak,
            input.delivered?(double)input.latencyTotal/input.delivered:0.0,
            (unsigned long long)input.latencyMax];
}
- (UIImage *)takeFrame {
    NSData *data;
    { std::unique_lock<std::mutex> guard(_state->frameLock,std::try_to_lock);
      // Do not hold up UIKit touch delivery while the VM publishes a frame.
      if(!guard.owns_lock()) return nil;
      if(!_state->dirty) return nil; _state->dirty=false;
      data=[NSData dataWithBytes:_state->snapshot.data() length:_state->snapshot.size()*4]; }
    CGDataProviderRef provider=CGDataProviderCreateWithCFData((__bridge CFDataRef)data);
    CGColorSpaceRef space=CGColorSpaceCreateDeviceRGB();
    CGImageRef image=CGImageCreate(_width,_height,8,32,_width*4,space,kCGBitmapByteOrder32Little|kCGImageAlphaNoneSkipFirst,provider,nullptr,false,kCGRenderingIntentDefault);
    UIImage *result=[UIImage imageWithCGImage:image];
    CGImageRelease(image); CGColorSpaceRelease(space); CGDataProviderRelease(provider); return result;
}
@end
