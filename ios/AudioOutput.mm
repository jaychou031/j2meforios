#include "AudioOutput.hpp"
#include <algorithm>
#include <chrono>
#include <cstring>

static uint64_t audioMillis() {
    return (uint64_t)std::chrono::duration_cast<std::chrono::milliseconds>(
        std::chrono::steady_clock::now().time_since_epoch()).count();
}
int AudioOutput::fill(AudioQueueBufferRef b,bool countUnderrun) {
    pcm.complete(static_cast<int>(reinterpret_cast<uintptr_t>(b->mUserData)));
    int n=pcm.read(static_cast<int16_t *>(b->mAudioData),blockFrames,countUnderrun);
    b->mAudioDataByteSize=static_cast<UInt32>(n*channels*sizeof(int16_t));
    b->mUserData=reinterpret_cast<void *>(static_cast<uintptr_t>(n));
    return n;
}
void AudioOutput::callback(void *context,AudioQueueRef q,AudioQueueBufferRef b) {
    auto *s=static_cast<AudioOutput *>(context);
    std::lock_guard<std::mutex> guard(s->lock);
    if(q!=s->queue) return; // Dispose/reset returns retired buffers too.
    int index=0;
    while(index<3 && s->buffers[index]!=b) ++index;
    if(index==3) return;
    s->enqueued[index]=false;
    if(s->fill(b,true)>0) {
        OSStatus status=AudioQueueEnqueueBuffer(q,b,0,nullptr);
        if(status==noErr) s->enqueued[index]=true;
        else s->lastError=status;
    }
    // Park empty buffers: never run an endless 100 Hz silent-buffer loop.
    if(!s->pcm.queued() && !s->emptySince) s->emptySince=audioMillis();
}
void AudioOutput::updateRunning() {
    AudioQueueRef q;
    bool start=false,stop=false;
    {
        std::lock_guard<std::mutex> guard(lock);
        q=queue;
        if(!q) return;
        bool haveBuffers=enqueued[0] || enqueued[1] || enqueued[2];
        start=!running && !paused && haveBuffers;
        stop=running && (paused || !pcm.queued());
        if(stop) running=false;
    }
    // Queue control may synchronize with callbacks; do not hold their lock.
    OSStatus status=noErr;
    if(stop) status=AudioQueuePause(q);
    else if(start) status=AudioQueueStart(q,nullptr);
    if(stop || start) {
        std::lock_guard<std::mutex> guard(lock);
        if(queue==q) {
            if(status!=noErr) lastError=status;
            else if(start) running=true;
        }
    }
}
int AudioOutput::open(int rate,int count) {
    close();
    if(rate<4000 || rate>192000 || count<1 || count>2) return -1;
    {
        std::lock_guard<std::mutex> guard(lock);
        channels=count; sampleRate=rate; blockFrames=std::max(1,rate/100);
        pcm.reset(rate,count); lastError=0;
        starvationGaps=gapSilenceFrames=emptySince=0;
    }
    AudioStreamBasicDescription format={};
    format.mSampleRate=rate; format.mFormatID=kAudioFormatLinearPCM;
    format.mFormatFlags=kLinearPCMFormatFlagIsSignedInteger|kAudioFormatFlagIsPacked;
    format.mBytesPerPacket=format.mBytesPerFrame=count*2;
    format.mFramesPerPacket=1; format.mChannelsPerFrame=count; format.mBitsPerChannel=16;
    AudioQueueRef created=nullptr;
    OSStatus status=AudioQueueNewOutput(&format,callback,this,nullptr,nullptr,0,&created);
    if(status!=noErr) { std::lock_guard<std::mutex> guard(lock); lastError=status; return -1; }
    { std::lock_guard<std::mutex> guard(lock); queue=created; }
    for(auto& buffer:buffers) {
        status=AudioQueueAllocateBuffer(queue,blockFrames*count*2,&buffer);
        if(status!=noErr) { close(); std::lock_guard<std::mutex> guard(lock); lastError=status; return -1; }
        buffer->mUserData=nullptr;
    }
    return 0;
}
int AudioOutput::write(const int16_t *samples,int frames) {
    if(!samples || frames<=0) return 0;
    int n;
    OSStatus error=noErr;
    {
        std::lock_guard<std::mutex> guard(lock);
        if(!queue) return 0;
        n=pcm.write(samples,frames);
        if(n && emptySince) {
            if(!paused) { ++starvationGaps; gapSilenceFrames+=(audioMillis()-emptySince)*sampleRate/1000; }
            emptySince=0;
        }
        for(int i=0;i<3;++i) if(!enqueued[i] && fill(buffers[i],false)>0) {
            error=AudioQueueEnqueueBuffer(queue,buffers[i],0,nullptr);
            if(error!=noErr) { lastError=error; break; }
            enqueued[i]=true;
        }
    }
    if(error!=noErr) { close(); return -1; }
    updateRunning();
    return n;
}
int AudioOutput::freeFrames() {
    updateRunning();
    std::lock_guard<std::mutex> guard(lock); return queue?pcm.free():0;
}
int AudioOutput::queuedFrames() {
    updateRunning();
    std::lock_guard<std::mutex> guard(lock); return queue?pcm.queued():0;
}
void AudioOutput::close() {
    AudioQueueRef retired;
    { std::lock_guard<std::mutex> guard(lock); retired=queue; queue=nullptr; }
    if(retired) AudioQueueDispose(retired,true);
    for(auto& buffer:buffers) buffer=nullptr;
    for(auto& flag:enqueued) flag=false;
    running=false; paused=false;
    // Counters survive close for the exported diagnostics.
}
void AudioOutput::pause(bool value) {
    { std::lock_guard<std::mutex> guard(lock); paused=value; if(value) emptySince=0; }
    updateRunning();
}
void AudioOutput::volume(float value) { if(queue) AudioQueueSetParameter(queue,kAudioQueueParam_Volume,std::clamp(value,0.0f,1.0f)); }
AudioOutput::Stats AudioOutput::stats() {
    std::lock_guard<std::mutex> guard(lock);
    return {pcm.written,pcm.played,pcm.underrunFrames,pcm.clippedSamples,sampleRate,pcm.peak,lastError,starvationGaps,gapSilenceFrames};
}
