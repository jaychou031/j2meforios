#pragma once
#include <algorithm>
#include <cstdint>
#include <cstdio>
#include <vector>
namespace audio {
// Opt-in, one session. Capture the last opened PCM stream's first 30 seconds
// before AudioQueue; no file I/O on the VM's audio hot path or callback.
class PcmCapture {
    bool enabled=false;
    int rate=0,channels=0;
    size_t limit=0;
    std::vector<int16_t> samples;
    static void word(FILE *f,uint32_t value,int bytes) {
        while(bytes--) { std::fputc(value&255,f); value>>=8; }
    }
public:
    void enable(bool value) { enabled=value; }
    void open(int sampleRate,int count) {
        if(!enabled) return;
        rate=sampleRate;channels=count;samples.clear();
        limit=static_cast<size_t>(rate)*channels*30;
        samples.reserve(limit);
    }
    void append(const int16_t *data,int frames) {
        if(!enabled || frames<=0 || samples.size()>=limit) return;
        size_t count=std::min(limit-samples.size(),static_cast<size_t>(frames)*channels);
        samples.insert(samples.end(),data,data+count);
    }
    size_t frames() const { return channels?samples.size()/channels:0; }
    bool save(const char *path) const {
        if(samples.empty()) return false;
        FILE *f=std::fopen(path,"wb"); if(!f) return false;
        uint32_t bytes=static_cast<uint32_t>(samples.size()*2);
        std::fwrite("RIFF",1,4,f);word(f,bytes+36,4);std::fwrite("WAVEfmt ",1,8,f);
        word(f,16,4);word(f,1,2);word(f,channels,2);word(f,rate,4);word(f,rate*channels*2,4);
        word(f,channels*2,2);word(f,16,2);std::fwrite("data",1,4,f);word(f,bytes,4);
        bool ok=std::fwrite(samples.data(),1,bytes,f)==bytes && !std::ferror(f);
        if(std::fclose(f)!=0) ok=false;
        return ok;
    }
};
}
