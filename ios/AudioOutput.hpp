#pragma once
#include <AudioToolbox/AudioToolbox.h>
#include <mutex>
#include <vector>
class AudioOutput {
    std::mutex lock;
    AudioQueueRef queue=nullptr;
    std::vector<int16_t> ring;
    int channels=0, head=0, tail=0, buffered=0, pending=0;
    static constexpr int capacity=32768;
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
};
