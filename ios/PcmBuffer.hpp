#pragma once
#include <algorithm>
#include <cstdint>
#include <cstring>
#include <vector>

namespace audio {
// Caller serializes access. Counts are frames, not interleaved samples.
class PcmBuffer {
    std::vector<int16_t> data;
    int channels=0, capacity=0, head=0, tail=0, buffered=0, inFlight=0;
public:
    uint64_t written=0, played=0, underrunFrames=0, clippedSamples=0;
    int peak=0;
    void reset(int rate,int count) {
        channels=count; capacity=std::max(1,rate*120/1000);
        data.assign(capacity*channels,0);
        head=tail=buffered=inFlight=peak=0;
        written=played=underrunFrames=clippedSamples=0;
    }
    int queued() const { return buffered+inFlight; }
    int free() const { return capacity-queued(); }
    int write(const int16_t *src,int frames) {
        int n=std::min(std::max(0,frames),free());
        for(int i=0;i<n;++i) {
            for(int c=0;c<channels;++c) {
                int16_t sample=src[i*channels+c];
                data[head*channels+c]=sample;
                if(sample==INT16_MAX || sample==INT16_MIN) ++clippedSamples;
            }
            head=(head+1)%capacity;
        }
        buffered+=n; written+=n; peak=std::max(peak,queued()); return n;
    }
    int read(int16_t *dst,int frames,bool countUnderrun=true) {
        int n=std::min(std::max(0,frames),buffered);
        for(int i=0;i<n;++i) {
            std::memcpy(dst+i*channels,data.data()+tail*channels,channels*sizeof(int16_t));
            tail=(tail+1)%capacity;
        }
        std::fill(dst+n*channels,dst+frames*channels,int16_t{0});
        buffered-=n; inFlight+=n;
        if(countUnderrun && n==0) underrunFrames+=frames;
        return n;
    }
    void complete(int frames) {
        int n=std::min(std::max(0,frames),inFlight);
        inFlight-=n; played+=n;
    }
};
}
