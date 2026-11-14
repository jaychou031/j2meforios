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
    bool running=false, paused=false, enqueued[3]={};
    int lastError=0;
    uint64_t starvationGaps=0, gapSilenceFrames=0, emptySince=0;
    int fill(AudioQueueBufferRef buffer,bool countUnderrun);
    void updateRunning();
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
    struct Stats { uint64_t written,played,underrunFrames,clippedSamples; int rate,peak,lastError; uint64_t starvationGaps,gapSilenceFrames; };
    Stats stats();
};
