#include "../ios/AudioOutput.hpp"
#include <cassert>
#include <cstdlib>
#include <cstdio>
static Queue *device=nullptr;
static unsigned enqueueCalls=0;
OSStatus AudioQueueNewOutput(const AudioStreamBasicDescription*,Callback cb,void *ctx,void*,void*,UInt32,AudioQueueRef *q) {
    *q=device=new Queue{}; device->callback=cb; device->context=ctx; return 0;
}
OSStatus AudioQueueAllocateBuffer(AudioQueueRef q,UInt32 bytes,AudioQueueBufferRef *b) {
    *b=new Buffer{}; (*b)->mAudioData=std::malloc(bytes); q->allocated.push_back(*b); return 0;
}
OSStatus AudioQueueEnqueueBuffer(AudioQueueRef q,AudioQueueBufferRef b,UInt32,const void*) {
    ++enqueueCalls;
    if(q->disposing) return -66632;
    assert(b->mAudioDataByteSize>0);
    q->ready.push_back(b); return 0;
}
OSStatus AudioQueueStart(AudioQueueRef q,const void*) { q->started=true; return 0; }
OSStatus AudioQueuePause(AudioQueueRef q) { q->started=false; return 0; }
OSStatus AudioQueueDispose(AudioQueueRef q,bool) {
    q->disposing=true;
    auto before=enqueueCalls;
    // Simulate outstanding callback delivery inside a synchronous disposal.
    for(auto b:q->ready) q->callback(q->context,q,b);
    assert(enqueueCalls==before);
    for(auto b:q->allocated) { std::free(b->mAudioData); delete b; }
    delete q; device=nullptr; return 0;
}
OSStatus AudioQueueSetParameter(AudioQueueRef,int,float) { return 0; }
int main() {
    AudioOutput audio;
    assert(audio.open(22050,2)==0 && device && !device->started && device->ready.empty());
    std::vector<int16_t> input(6000); for(int i=0;i<6000;++i) input[i]=static_cast<int16_t>(i);
    assert(audio.write(input.data(),3000)==2646 && device->started && device->ready.size()==3);
    assert(audio.queuedFrames()==2646 && audio.freeFrames()==0);
    int heard=0;
    while(audio.queuedFrames()) {
        auto b=device->ready.front(); device->ready.erase(device->ready.begin());
        int real=static_cast<int>(reinterpret_cast<uintptr_t>(b->mUserData));
        if(real) {
            assert(b->mAudioDataByteSize==static_cast<UInt32>(real*4));
            auto p=static_cast<int16_t*>(b->mAudioData);
            for(int i=0;i<real*2;++i) assert(p[i]==input[heard*2+i]);
            heard+=real;
        }
        device->callback(device->context,device,b);
    }
    assert(heard==2646 && audio.stats().played==2646);
    assert(device->ready.empty() && !device->started);
    auto idleEnqueues=enqueueCalls;
    for(int i=0;i<1000;++i) { assert(audio.queuedFrames()==0); assert(audio.freeFrames()==2646); }
    assert(enqueueCalls==idleEnqueues); // no silent callbacks or enqueues while idle
    assert(audio.stats().starvationGaps==0); // natural tail is not a confirmed gap
    audio.pause(true); assert(!device->started);
    audio.pause(false); assert(!device->started); // no empty playback to resume
    audio.close(); assert(!device && audio.queuedFrames()==0);
    assert(audio.open(8000,1)==0);
    int16_t shortClip[]={1,2,3}; assert(audio.write(shortClip,3)==3);
    assert(device->ready.size()==1 && device->ready[0]->mAudioDataByteSize==6);
    audio.pause(true); assert(!device->started && audio.queuedFrames()==3);
    audio.pause(false); assert(device->started && audio.queuedFrames()==3);
    auto b=device->ready.front(); device->ready.erase(device->ready.begin());
    device->callback(device->context,device,b);
    assert(audio.queuedFrames()==0 && device->ready.empty() && !device->started);
    assert(audio.write(shortClip,3)==3 && device->started && device->ready.size()==1);
    assert(audio.stats().starvationGaps==1);
    audio.close(); assert(audio.stats().lastError==0);
    assert(audio.open(8000,1)==0);
    audio.pause(true); assert(audio.write(shortClip,3)==3 && !device->started);
    audio.pause(false); assert(device->started);
    audio.close(); assert(audio.open(0,1)==-1 && !device);
    std::puts("AudioQueue: no silent wake loop, restart, pause, sample order and dispose callbacks passed.");
}

