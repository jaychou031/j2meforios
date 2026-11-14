#pragma once
#include <AudioToolbox/AudioToolbox.h>
#include <mutex>
#include <vector>
#include "PcmBuffer.hpp"
class AudioOutput {
    std::mutex lock;
    AudioQueueRef queue=nullptr;
    audio::PcmBuffer pcm;
    AudioQueueBufferRef buffers[3]={};
    int channels=0, blockFrames=0, sampleRate=0;
    bool started=false, paused=false;
    int lastError=0;
    void fill(AudioQueueBufferRef buffer,bool countUnderrun);
    static void callback(void *context,AudioQueueRef queue,AudioQueueBufferRef buffer);
public:
    ~AudioOutput() { close(); }
    int open(int rate,int count);
    int write(const int16_t *samples,int frames);
    int freeFrames();
    int queuedFrames();
    void close();
    void pause(bool paused);
    void volume(float value);
    struct Stats { uint64_t written,played,underrunFrames,clippedSamples; int rate,peak,lastError; };
    Stats stats();
};
