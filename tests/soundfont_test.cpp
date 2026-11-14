extern "C" {
#include "nj_midi.h"
}
#include "SoundFontSynth.h"
#include <algorithm>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <set>
#include <vector>
#include <thread>

#define CHECK(x) do { if (!(x)) { std::fprintf(stderr,"Failed: %s at %d\n",#x,__LINE__); std::exit(1); } } while(0)
static std::set<void *> allocations;
static void *allocate(void *, nj_size n) { void *p=std::malloc(n); if(p) allocations.insert(p); return p; }
static void release(void *, void *p) { if(p) { CHECK(allocations.erase(p)==1); std::free(p); } }
static const nj_midi_mem memory{nullptr,allocate,release};
static std::vector<unsigned char> midi(int program=0, int ch=0, bool effects=false) {
    std::vector<unsigned char> track{0,(unsigned char)(0xc0|ch),(unsigned char)program};
    if(effects) {
        for(int cc : {1,91,93}) track.insert(track.end(),{0,(unsigned char)(0xb0|ch),(unsigned char)cc,100});
    }
    track.insert(track.end(),{0,(unsigned char)(0x90|ch),60,100,96,(unsigned char)(0x80|ch),60,0,0,255,47,0});
    std::vector<unsigned char> data{'M','T','h','d',0,0,0,6,0,0,0,1,0,96,'M','T','r','k',0,0,0,(unsigned char)track.size()};
    data.insert(data.end(),track.begin(),track.end()); return data;
}
static nj_midi_stream *open(const std::vector<unsigned char> &data) {
    auto *s=nj_midi_stream_open(data.data(),(nj_u4)data.size(),&memory); CHECK(s); return s;
}
static std::vector<unsigned char> pull(nj_midi_stream *s,unsigned frames) {
    unsigned channels=nj_midi_stream_channels(s);
    std::vector<unsigned char> result(frames*channels*2);
    unsigned n=nj_midi_stream_pull(s,result.data(),frames); result.resize(n*channels*2); return result;
}
static long long energy(const std::vector<unsigned char> &data, size_t start=0) {
    long long sum=0;
    for(size_t i=start;i+1<data.size();i+=2) { int v=(short)(data[i]|(data[i+1]<<8)); sum+=std::abs(v); }
    return sum;
}
int main(int argc,char **argv) {
    CHECK(argc==2);
    auto song=midi();
    CHECK(!nj_sf_load_bank("missing-soundfont-test.sf2"));
    auto *old=open(song); CHECK(nj_midi_stream_channels(old)==1);
    auto waveform=pull(old,4096); CHECK(energy(waveform)>0); nj_midi_stream_close(old);
    CHECK(nj_sf_load_bank(argv[1]));
    CHECK(nj_sf_load_bank(argv[1])); // cached bank; streams must share only samples
    auto *s=open(song); CHECK(nj_midi_stream_channels(s)==2);
    auto first=pull(s,1024); CHECK(energy(first)>0);
    auto second=pull(s,1024);
    CHECK(nj_midi_stream_seek(s,1024)==1024);
    CHECK(second==pull(s,1024));
    CHECK(nj_midi_stream_restart(s)); CHECK(first==pull(s,1024));
    unsigned normal=nj_midi_stream_frames(s);
    CHECK(nj_midi_stream_set_rate(s,2000)==2000);
    CHECK(nj_midi_stream_frames(s)<normal);
    CHECK(nj_midi_stream_set_tempo(s,60000)==60000);
    CHECK(nj_midi_stream_frames(s)>normal);
    CHECK(nj_midi_stream_set_rate(s,1000)==1000);
    nj_midi_stream_event(s,0xb0,7,0);
    auto muted=pull(s,2048); CHECK(energy(muted,1024*4)==0);
    int volume=-1,bank=-1,program=-1;
    CHECK(nj_midi_stream_channel_state(s,0,&bank,&program,&volume)); CHECK(volume==0);
    nj_midi_stream_event(s,0xb0,7,100);
    nj_midi_stream_event(s,0xc0,40,0);
    nj_midi_stream_event(s,0x90,67,100);
    CHECK(energy(pull(s,1024))>0);
    CHECK(nj_midi_stream_channel_state(s,0,&bank,&program,&volume)); CHECK(program==40 && volume==100);
    nj_midi_stream_close(s);
    auto strings=midi(40), drums=midi(0,9), effected=midi(0,0,true);
    auto *a=open(song), *b=open(strings), *c=open(drums), *d=open(effected);
    auto piano=pull(a,8192), stringSound=pull(b,8192), drumSound=pull(c,8192), wet=pull(d,8192);
    CHECK(energy(piano)>0 && energy(stringSound)>0 && energy(drumSound)>0);
    CHECK(piano!=stringSound && piano!=drumSound && piano!=wet);
    for(auto *item : {a,b,c,d}) nj_midi_stream_close(item);
    // Controllers act on already-sounding voices; a second stream is isolated.
    a=open(song); b=open(song); CHECK(pull(a,1024)==pull(b,1024));
    nj_midi_stream_event(a,0xe0,0,96);
    CHECK(pull(a,1024)!=pull(b,1024));
    nj_midi_stream_event(a,0xb0,10,0);
    auto left=pull(a,1024);
    long long leftEnergy=0,rightEnergy=0;
    for(size_t i=0;i+3<left.size();i+=4) {
        leftEnergy+=std::abs((short)(left[i]|(left[i+1]<<8)));
        rightEnergy+=std::abs((short)(left[i+2]|(left[i+3]<<8)));
    }
    CHECK(leftEnergy>0 && rightEnergy==0);
    // The pinned longMidiEvent parser consumes delta-prefixed track bytes.
    auto live=midi(73);
    CHECK(nj_midi_stream_events(a,live.data()+22,(nj_u4)live.size()-22)>0);
    pull(a,128);
    CHECK(nj_midi_stream_channel_state(a,0,nullptr,&program,nullptr)); CHECK(program==73);
    nj_midi_stream_close(a);nj_midi_stream_close(b);
    // Pedal holds a released key, then releases it when CC64 is reset.
    a=open(song); b=open(song); pull(a,1024);pull(b,1024);
    nj_midi_stream_event(a,0xb0,64,127);
    nj_midi_stream_event(a,0x80,60,0);nj_midi_stream_event(b,0x80,60,0);
    auto held=pull(a,8000),released=pull(b,8000);
    CHECK(energy(held,4000*4)>energy(released,4000*4));
    nj_midi_stream_event(a,0xb0,64,0);pull(a,1024);
    nj_midi_stream_close(a);nj_midi_stream_close(b);
    // No-note files must return null without double-freeing parser arrays.
    auto empty=std::vector<unsigned char>{'M','T','h','d',0,0,0,6,0,0,0,1,0,96,
        'M','T','r','k',0,0,0,8,0,0xb0,7,100,0,255,47,0};
    CHECK(!nj_midi_stream_open(empty.data(),(nj_u4)empty.size(),&memory));
    CHECK(allocations.empty());
    auto stats=nj_sf_get_stats(); CHECK(stats.active==0 && stats.opened>=7 && stats.fallback==1);
    CHECK(stats.errors==0);
    // Some games leave Players open. Final cleanup is scoped to the VM worker.
    CHECK(nj_sf_create());
    std::thread worker([] {
        CHECK(nj_sf_create()); CHECK(nj_sf_create());
        CHECK(nj_sf_release_thread_streams()==2);
    });
    worker.join();
    CHECK(nj_sf_get_stats().active==1);
    CHECK(nj_sf_release_thread_streams()==1);
    CHECK(nj_sf_get_stats().active==0);
    std::puts("SoundFont: fallback, stereo, seek/restart, rate/tempo, MIDIControl, instruments/drums/effects, cleanup passed.");
}
