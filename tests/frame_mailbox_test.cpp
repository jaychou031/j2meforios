#include "../ios/FrameMailbox.hpp"
#include <cassert>
#include <thread>
#include <atomic>
#include <algorithm>
#include <cstdio>
int main() {
    using M=display::FrameMailbox;
    M q(256); std::vector<uint32_t> pixels(256,1);
    auto p=q.publish(pixels.data()); assert(p.changed && p.wake);
    std::shared_ptr<const display::Frame> a,b,c;
    assert(q.take(a)==M::Read::Frame && a->front()==1);
    assert(!q.publish(pixels.data()).changed);
    assert(q.take(b)==M::Read::Idle);
    std::fill(pixels.begin(),pixels.end(),2); assert(q.publish(pixels.data()).wake);
    assert(q.take(b)==M::Read::Frame && b->front()==2 && a->front()==1);
    std::fill(pixels.begin(),pixels.end(),3); assert(q.publish(pixels.data()).changed);
    assert(q.take(c)==M::Read::Frame && c->front()==3);
    std::fill(pixels.begin(),pixels.end(),4); assert(!q.publish(pixels.data()).changed);
    assert(a->front()==1 && b->front()==2 && c->front()==3);
    a.reset(); assert(q.publish(pixels.data()).changed);
    assert(q.take(a)==M::Read::Frame && a->front()==4);
    auto stats=q.stats(); assert(stats.published==4 && stats.copiedBytes==4096 && stats.busyDrops==1);
    // A retained image must remain immutable while the producer publishes.
    M concurrent(4096); std::atomic<bool> done{false};
    std::thread worker([&]{ std::vector<uint32_t> v(4096); for(uint32_t n=1;n<10000;++n) {
        std::fill(v.begin(),v.end(),n); concurrent.publish(v.data());
    } done=true; });
    do { std::shared_ptr<const display::Frame> f;
        if(concurrent.take(f)==M::Read::Frame) {
            auto value=f->front(); std::this_thread::yield();
            for(auto pixel:*f) assert(pixel==value);
        }
    } while(!done);
    worker.join(); std::puts("Frame mailbox: pooled immutable frames, coalescing, wake and concurrent lifetime passed.");
}
