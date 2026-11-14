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
        // At most two contiguous copies, including ring wrap. In-flight frames
        // still count against capacity; no per-frame modulo or tiny memcpy.
        int first=std::min(n,capacity-head);
        if(first) std::memcpy(data.data()+head*channels,src,first*channels*sizeof(int16_t));
        if(n>first) std::memcpy(data.data(),src+first*channels,(n-first)*channels*sizeof(int16_t));
        for(int i=0;i<n*channels;++i)
            clippedSamples+=(src[i]==INT16_MAX || src[i]==INT16_MIN);
        head+=n; if(head>=capacity) head-=capacity;
        buffered+=n; written+=n; peak=std::max(peak,queued()); return n;
    }
    int read(int16_t *dst,int frames,bool countUnderrun=true) {
        int n=std::min(std::max(0,frames),buffered);
        int first=std::min(n,capacity-tail);
        if(first) std::memcpy(dst,data.data()+tail*channels,first*channels*sizeof(int16_t));
        if(n>first) std::memcpy(dst+first*channels,data.data(),(n-first)*channels*sizeof(int16_t));
        tail+=n; if(tail>=capacity) tail-=capacity;
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
