#pragma once
#include <array>
#include <cstdint>
#include <cstring>
#include <memory>
#include <mutex>
#include <vector>

namespace display {
using Frame=std::vector<uint32_t>;
// The VM publishes into a reusable pool. CGImage holds an immutable shared
// frame until its data provider is released; no second full-frame copy.
class FrameMailbox {
    std::mutex lock;
    std::array<std::shared_ptr<Frame>,3> pool;
    std::shared_ptr<Frame> latest;
    bool pending=false, sleeping=true;
public:
    struct Stats { uint64_t published=0, consumed=0, duplicates=0, busyDrops=0, copiedBytes=0; };
    struct Publish { bool changed=false, wake=false; };
    enum class Read { Frame, Idle, Busy };
private:
    Stats counters;
public:
    explicit FrameMailbox(size_t pixels) {
        for(auto& slot:pool) slot=std::make_shared<Frame>(pixels);
    }
    Publish publish(const uint32_t *pixels) {
        std::lock_guard<std::mutex> guard(lock);
        size_t bytes=pool[0]->size()*sizeof(uint32_t);
        if(latest && !std::memcmp(pixels,latest->data(),bytes)) { ++counters.duplicates; return {}; }
        for(auto& slot:pool) if(slot.use_count()==1 || (slot==latest && slot.use_count()==2)) {
            std::memcpy(slot->data(),pixels,bytes); latest=slot; pending=true;
            ++counters.published; counters.copiedBytes+=bytes;
            bool wake=sleeping; sleeping=false; return {true,wake};
        }
        ++counters.busyDrops; return {}; // never overwrite an image held by UIKit
    }
    Read take(std::shared_ptr<const Frame>& frame) {
        std::unique_lock<std::mutex> guard(lock,std::try_to_lock);
        if(!guard.owns_lock()) return Read::Busy;
        if(!pending) { sleeping=true; return Read::Idle; }
        frame=latest; pending=false; ++counters.consumed; return Read::Frame;
    }
    Stats stats() { std::lock_guard<std::mutex> guard(lock); return counters; }
};
}
