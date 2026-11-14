extern "C" {
#include "nj2me/nj.h"
}
#include "SoundFontSynth.h"
#include <cstdlib>
#include <cstdio>
int main(int argc,char **argv) {
    if((argc!=6 && argc!=7) || !nj_sf_load_bank(argv[1])) return 2;
    nj_port port{};
    if(nj_port_headless_ex(&port,240,320,120,argc==7?argv[6]:nullptr)!=NJ_OK) return 3;
    port.fps_cap=60;
    port.rms_dir=argv[3];
    nj_run_opts opts{};
    opts.jar_path=argv[2];opts.heap_bytes=32u*1024u*1024u;
    opts.device=nj_device_find("nokia6230");opts.stats=1;
    opts.run_frames=(nj_u4)std::strtoul(argv[4],nullptr,10);opts.keys=argv[5];
    int result=nj_run(&port,&opts);nj_port_shutdown(&port);
    unsigned released=nj_sf_release_thread_streams();
    std::printf("SOUNDFONT teardown released=%u\n",released);
    auto stats=nj_sf_get_stats();
    std::printf("SOUNDFONT opened=%llu fallback=%llu failures=%llu active=%llu\n",
        (unsigned long long)stats.opened,(unsigned long long)stats.fallback,
        (unsigned long long)stats.errors,(unsigned long long)stats.active);
    return result || stats.errors || stats.active ? 1 : 0;
}
