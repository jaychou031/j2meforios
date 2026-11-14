#include "../ios/PcmBuffer.hpp"
#include "../ios/ToneSample.hpp"
#include <cassert>
#include <vector>

int main() {
    // Preserve mono and stereo samples exactly, across wrap and short writes.
    for(int rate:{8000,22050,44100,48000,192000}) for(int channels:{1,2}) {
        audio::PcmBuffer q; q.reset(rate,channels);
        int capacity=q.free(), block=rate/100;
        assert(capacity==rate*120/1000 && q.queued()==0);
        std::vector<int16_t> src((capacity+31)*channels),out(block*channels);
        uint64_t sent=0,received=0;
        for(int cycle=0;cycle<50;++cycle) {
            for(size_t i=0;i<src.size();++i) src[i]=static_cast<int16_t>((sent*channels+i)%20000-10000);
            int n=q.write(src.data(),capacity+31); sent+=n;
            assert(n<=capacity && q.free()+q.queued()==capacity);
            int freeBefore=q.free();
            int played=q.read(out.data(),block);
            assert(q.free()==freeBefore); // handed to hardware is still queued
            for(int i=0;i<played*channels;++i)
                assert(out[i]==static_cast<int16_t>((received*channels+i)%20000-10000));
            received+=played; q.complete(played);
            assert(q.free()==freeBefore+played);
        }
        while(q.queued()) { int n=q.read(out.data(),block); received+=n; q.complete(n); }
        assert(sent==received && q.written==q.played);
        q.read(out.data(),block); assert(q.underrunFrames==static_cast<uint64_t>(block));
        for(auto sample:out) assert(sample==0);
        // Short clip: first read contains real samples, with no silent prefix.
        int16_t shortClip[]={100,200,300,400};
        q.write(shortClip,2);
        int n=q.read(out.data(),block); assert(n==2 && out[0]==100);
        q.complete(n); assert(q.queued()==0);
    }
    for(unsigned length:{1u,10u,2205u}) {
        assert(audio::toneSample(440,0,length,22050)==0);
        assert(audio::toneSample(440,length-1,length,22050)==0);
        for(unsigned i=0;i<length;++i) {
            assert(std::abs(static_cast<int>(audio::toneSample(440,i,length,22050)))<=6000);
            assert(audio::toneSample(0,i,length,22050)==0);
        }
    }
}
