#include "AudioOutput.hpp"
#include <algorithm>
#include <cstring>
void AudioOutput::callback(void *context,AudioQueueRef q,AudioQueueBufferRef b) {
    auto *s=static_cast<AudioOutput *>(context);
    {
        std::lock_guard<std::mutex> guard(s->lock);
        s->pending-=static_cast<int>(reinterpret_cast<uintptr_t>(b->mUserData));
        int n=std::min(1024,s->buffered);
        auto *out=static_cast<int16_t *>(b->mAudioData);
        for(int i=0;i<n;i++) {
            for(int c=0;c<s->channels;c++) out[i*s->channels+c]=s->ring[s->tail*s->channels+c];
            s->tail=(s->tail+1)%capacity;
        }
        s->buffered-=n;
        memset(out+n*s->channels,0,(1024-n)*s->channels*sizeof(int16_t));
        b->mAudioDataByteSize=1024*s->channels*sizeof(int16_t);
        b->mUserData=reinterpret_cast<void *>(static_cast<uintptr_t>(n));
    }
    AudioQueueEnqueueBuffer(q,b,0,nullptr);
}
int AudioOutput::open(int rate,int count) {
    close();
    if(rate<4000 || rate>192000 || count<1 || count>2) return -1;
    channels=count; ring.resize(capacity*channels);
    AudioStreamBasicDescription format={};
    format.mSampleRate=rate; format.mFormatID=kAudioFormatLinearPCM;
    format.mFormatFlags=kLinearPCMFormatFlagIsSignedInteger|kAudioFormatFlagIsPacked;
    format.mBytesPerPacket=format.mBytesPerFrame=count*2;
    format.mFramesPerPacket=1; format.mChannelsPerFrame=count; format.mBitsPerChannel=16;
    if(AudioQueueNewOutput(&format,callback,this,nullptr,nullptr,0,&queue)!=noErr) { queue=nullptr; return -1; }
    for(int i=0;i<3;i++) {
        AudioQueueBufferRef buffer=nullptr;
        if(AudioQueueAllocateBuffer(queue,1024*count*2,&buffer)!=noErr) { close(); return -1; }
        buffer->mUserData=nullptr; callback(this,queue,buffer);
    }
    if(AudioQueueStart(queue,nullptr)!=noErr) { close(); return -1; }
    return 0;
}
int AudioOutput::write(const int16_t *samples,int frames) {
    if(!queue || !samples || frames<=0) return 0;
    std::lock_guard<std::mutex> guard(lock);
    int n=std::min(frames,capacity-buffered);
    for(int i=0;i<n;i++) {
        for(int c=0;c<channels;c++) ring[head*channels+c]=samples[i*channels+c];
        head=(head+1)%capacity;
    }
    buffered+=n; pending+=n; return n;
}
int AudioOutput::freeFrames() { std::lock_guard<std::mutex> guard(lock); return capacity-buffered; }
int AudioOutput::queuedFrames() { std::lock_guard<std::mutex> guard(lock); return pending; }
void AudioOutput::close() {
    if(queue) { AudioQueueDispose(queue,true); queue=nullptr; }
    std::lock_guard<std::mutex> guard(lock);
    head=tail=buffered=pending=0;
}
void AudioOutput::pause(bool paused) { if(queue) { if(paused) AudioQueuePause(queue); else AudioQueueStart(queue,nullptr); } }
void AudioOutput::volume(float value) { if(queue) AudioQueueSetParameter(queue,kAudioQueueParam_Volume,value); }
