#pragma once
#include "nj2me/nj_port.h"
#include <bitset>
#include <deque>
#include <algorithm>
#include <cstdint>

namespace controls {
// Serialized by the short-lived input mutex, never the frame/audio/log locks.
class InputQueue {
    struct Entry { nj_event event; uint64_t time; };
    std::deque<Entry> queue;
    std::bitset<256> batchKeys;
    bool batchPointer=false;
public:
    uint64_t delivered=0, latencyTotal=0, latencyMax=0;
    size_t peak=0;
    void push(nj_event event,uint64_t now) {
        if(event.type==NJ_EV_POINTER_MOVE && !queue.empty() &&
           queue.back().event.type==NJ_EV_POINTER_MOVE) queue.back()={event,now};
        else queue.push_back({event,now});
        peak=std::max(peak,queue.size());
    }
    bool pop(nj_event& event,uint64_t now) {
        if(queue.empty()) { batchKeys.reset(); batchPointer=false; return false; }
        const auto& next=queue.front();
        bool key=next.event.type==NJ_EV_KEY_DOWN || next.event.type==NJ_EV_KEY_UP;
        bool pointer=next.event.type==NJ_EV_POINTER_DOWN || next.event.type==NJ_EV_POINTER_UP;
        // Preserve a quick press for a VM update instead of draining down+up
        // together before the game's logic observes either state.
        if((key && batchKeys.test(next.event.key)) || (pointer && batchPointer)) {
            batchKeys.reset(); batchPointer=false; return false;
        }
        if(key) batchKeys.set(next.event.key);
        if(pointer) batchPointer=true;
        event=next.event;
        uint64_t latency=now>=next.time?now-next.time:0;
        ++delivered; latencyTotal+=latency; latencyMax=std::max(latencyMax,latency);
        queue.pop_front(); return true;
    }
};
}
