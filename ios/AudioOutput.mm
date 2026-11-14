#include "AudioOutput.hpp"
#include <algorithm>
#include <cstring>

void AudioOutput::fill(AudioQueueBufferRef b,bool countUnderrun) {
    pcm.complete(static_cast<int>(reinterpret_cast<uintptr_t>(b->mUserData)));
    int n=pcm.read(static_cast<int16_t *>(b->mAudioData),blockFrames,countUnderrun);
    // A short tail has its real duration. Empty callbacks keep the device alive.
    b->mAudioDataByteSize=static_cast<UInt32>((n?n:blockFrames)*channels*sizeof(int16_t));
    b->mUserData=reinterpret_cast<void *>(static_cast<uintptr_t>(n));
}
void AudioOutput::callback(void *context,AudioQueueRef q,AudioQueueBufferRef b) {
    auto *s=static_cast<AudioOutput *>(context);
    { std::lock_guard<std::mutex> guard(s->lock); s->fill(b,true); }
    OSStatus status=AudioQueueEnqueueBuffer(q,b,0,nullptr);
    if(status!=noErr) { std::lock_guard<std::mutex> guard(s->lock); s->lastError=status; }
}
int AudioOutput::open(int rate,int count) {
    close();
    if(rate<4000 || rate>192000 || count<1 || count>2) return -1;
    {
        std::lock_guard<std::mutex> guard(lock);
        channels=count; sampleRate=rate; blockFrames=std::max(1,rate/100);
        pcm.reset(rate,count); lastError=0;
    }
    AudioStreamBasicDescription format={};
    format.mSampleRate=rate; format.mFormatID=kAudioFormatLinearPCM;
    format.mFormatFlags=kLinearPCMFormatFlagIsSignedInteger|kAudioFormatFlagIsPacked;
    format.mBytesPerPacket=format.mBytesPerFrame=count*2;
    format.mFramesPerPacket=1; format.mChannelsPerFrame=count; format.mBitsPerChannel=16;
    OSStatus status=AudioQueueNewOutput(&format,callback,this,nullptr,nullptr,0,&queue);
    if(status!=noErr) { queue=nullptr; std::lock_guard<std::mutex> guard(lock); lastError=status; return -1; }
    for(auto& buffer:buffers) {
        status=AudioQueueAllocateBuffer(queue,blockFrames*count*2,&buffer);
        if(status!=noErr) { close(); std::lock_guard<std::mutex> guard(lock); lastError=status; return -1; }
        buffer->mUserData=nullptr;
    }
    // Prime from actual PCM on first write. Three silent 1024-frame buffers
    // previously added 139 ms before a 22.05 kHz sound even started.
    return 0;
}
int AudioOutput::write(const int16_t *samples,int frames) {
    if(!queue || !samples || frames<=0) return 0;
    int n;
    {
        std::lock_guard<std::mutex> guard(lock);
        n=pcm.write(samples,frames);
        if(started || !n) return n;
        for(auto buffer:buffers) fill(buffer,false);
    }
    for(auto buffer:buffers) {
        OSStatus status=AudioQueueEnqueueBuffer(queue,buffer,0,nullptr);
        if(status!=noErr) { close(); std::lock_guard<std::mutex> guard(lock); lastError=status; return -1; }
    }
    started=true;
    if(!paused) {
        OSStatus status=AudioQueueStart(queue,nullptr);
        if(status!=noErr) { close(); std::lock_guard<std::mutex> guard(lock); lastError=status; return -1; }
    }
    return n;
}
int AudioOutput::freeFrames() { std::lock_guard<std::mutex> guard(lock); return queue?pcm.free():0; }
int AudioOutput::queuedFrames() { std::lock_guard<std::mutex> guard(lock); return queue?pcm.queued():0; }
void AudioOutput::close() {
    // Dispose waits for callbacks; never hold their mutex while disposing.
    if(queue) { AudioQueueDispose(queue,true); queue=nullptr; }
    for(auto& buffer:buffers) buffer=nullptr;
    started=false; paused=false;
    // Retain counters for the exported session log after teardown.
}
void AudioOutput::pause(bool value) {
    paused=value;
    if(queue && started) {
        if(value) AudioQueuePause(queue); else AudioQueueStart(queue,nullptr);
    }
}
void AudioOutput::volume(float value) { if(queue) AudioQueueSetParameter(queue,kAudioQueueParam_Volume,std::clamp(value,0.0f,1.0f)); }
AudioOutput::Stats AudioOutput::stats() {
    std::lock_guard<std::mutex> guard(lock);
    return {pcm.written,pcm.played,pcm.underrunFrames,pcm.clippedSamples,sampleRate,pcm.peak,lastError};
}
