/* Local/CI diagnostic utility. User game assets are never distributed. */
extern "C" {
#include "nj_midi.h"
}
#include "SoundFontSynth.h"
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <chrono>
#include <vector>
static void *allocate(void *,nj_size n) { return std::malloc(n); }
static void release(void *,void *p) { std::free(p); }
static void word(FILE *f,unsigned value,int bytes) { while(bytes--) { std::fputc(value&255,f); value>>=8; } }
int main(int argc,char **argv) {
    if(argc<3 || argc>4) return 2;
    if(std::strcmp(argv[1],"none") && !nj_sf_load_bank(argv[1])) return 3;
    FILE *f=std::fopen(argv[2],"rb"); if(!f) return 4;
    std::fseek(f,0,SEEK_END); long size=std::ftell(f); std::rewind(f);
    if(size<0 || size>64*1024*1024) { std::fclose(f); return 5; }
    std::vector<unsigned char> bytes((size_t)size);
    auto read=std::fread(bytes.data(),1,bytes.size(),f); std::fclose(f);
    if(read!=bytes.size()) return 6;
    nj_midi_mem mem{nullptr,allocate,release};
    auto start=std::chrono::steady_clock::now();
    auto *s=nj_midi_stream_open(bytes.data(),(nj_u4)bytes.size(),&mem); if(!s) return 7;
    unsigned channels=nj_midi_stream_channels(s),frames=0,n;
    unsigned char pcm[4096];
    uint64_t saturated=0,energy=0; int peak=0;
    std::vector<unsigned char> wave;
    while(frames<60*NJ_MIDI_RATE && (n=nj_midi_stream_pull(s,pcm,1024))>0) {
        for(unsigned i=0;i<n*channels;i++) {
            int value=(short)(pcm[i*2] | (pcm[i*2+1]<<8));
            if(value==-32768 || value==32767) ++saturated;
            int magnitude=std::abs(value); energy+=magnitude; if(magnitude>peak) peak=magnitude;
        }
        if(argc==4) wave.insert(wave.end(),pcm,pcm+n*channels*2);
        frames+=n;
    }
    nj_midi_stream_close(s);
    double seconds=std::chrono::duration<double>(std::chrono::steady_clock::now()-start).count();
    auto stats=nj_sf_get_stats();
    std::printf("{\"frames\":%u,\"channels\":%u,\"peak\":%d,\"saturated\":%llu,\"energy\":%llu,\"limited\":%llu,\"failures\":%llu,\"active\":%llu,\"seconds\":%.6f}\n",
        frames,channels,peak,(unsigned long long)saturated,(unsigned long long)energy,
        (unsigned long long)stats.limited_samples,(unsigned long long)stats.errors,(unsigned long long)stats.active,seconds);
    if(argc==4) {
        f=std::fopen(argv[3],"wb"); if(!f) return 8;
        std::fwrite("RIFF",1,4,f);word(f,(unsigned)wave.size()+36,4);std::fwrite("WAVEfmt ",1,8,f);
        word(f,16,4);word(f,1,2);word(f,channels,2);word(f,NJ_MIDI_RATE,4);word(f,NJ_MIDI_RATE*channels*2,4);
        word(f,channels*2,2);word(f,16,2);std::fwrite("data",1,4,f);word(f,(unsigned)wave.size(),4);
        std::fwrite(wave.data(),1,wave.size(),f);std::fclose(f);
    }
    return stats.active || stats.errors ? 9 : 0;
}
