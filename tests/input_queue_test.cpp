#include "../ios/InputQueue.hpp"
#include <cassert>

static nj_event key(int type,int code) {
    nj_event e={}; e.type=(nj_u1)type; e.key=(nj_u1)code; return e;
}
int main() {
    controls::InputQueue q; nj_event e={};
    q.push(key(NJ_EV_KEY_DOWN,NJ_KEY_LEFT),10);
    q.push(key(NJ_EV_KEY_UP,NJ_KEY_LEFT),12);
    q.push(key(NJ_EV_KEY_DOWN,NJ_KEY_FIRE),13);
    q.push(key(NJ_EV_KEY_UP,NJ_KEY_FIRE),14);
    assert(q.pop(e,20) && e.type==NJ_EV_KEY_DOWN && e.key==NJ_KEY_LEFT);
    assert(!q.pop(e,20)); // the short tap must survive one input-drain boundary
    assert(q.pop(e,21) && e.type==NJ_EV_KEY_UP && e.key==NJ_KEY_LEFT);
    assert(q.pop(e,21) && e.type==NJ_EV_KEY_DOWN && e.key==NJ_KEY_FIRE);
    assert(!q.pop(e,21));
    assert(q.pop(e,22) && e.type==NJ_EV_KEY_UP);
    assert(!q.pop(e,22));
    assert(q.delivered==4 && q.peak==4 && q.latencyMax==10);
    // Simultaneous independent directions/actions stay in the same batch.
    q.push(key(NJ_EV_KEY_DOWN,NJ_KEY_UP),30);
    q.push(key(NJ_EV_KEY_DOWN,NJ_KEY_FIRE),30);
    assert(q.pop(e,31) && e.key==NJ_KEY_UP);
    assert(q.pop(e,31) && e.key==NJ_KEY_FIRE);
    assert(!q.pop(e,31));
    // Pointer motion coalesces only between consecutive moves, never across
    // a key transition, and does not erase pointer down/up.
    nj_event p={}; p.type=NJ_EV_POINTER_DOWN; q.push(p,40);
    p.type=NJ_EV_POINTER_MOVE; p.x=1; q.push(p,41); p.x=2; q.push(p,42);
    q.push(key(NJ_EV_KEY_UP,NJ_KEY_FIRE),43);
    p.x=3; q.push(p,44); p.type=NJ_EV_POINTER_UP; q.push(p,45);
    assert(q.pop(e,50) && e.type==NJ_EV_POINTER_DOWN);
    assert(q.pop(e,50) && e.type==NJ_EV_POINTER_MOVE && e.x==2);
    assert(q.pop(e,50) && e.type==NJ_EV_KEY_UP);
    assert(q.pop(e,50) && e.type==NJ_EV_POINTER_MOVE && e.x==3);
    assert(!q.pop(e,50));
    assert(q.pop(e,51) && e.type==NJ_EV_POINTER_UP);
    assert(!q.pop(e,51));
    // Sustained fast taps must retain every edge in order.
    for(int i=0;i<1000;++i) {
        q.push(key(NJ_EV_KEY_DOWN,NJ_KEY_5),60);
        q.push(key(NJ_EV_KEY_UP,NJ_KEY_5),60);
    }
    for(int i=0;i<2000;++i) {
        assert(q.pop(e,70) && e.type==(i%2?NJ_EV_KEY_UP:NJ_EV_KEY_DOWN));
        assert(!q.pop(e,70));
    }
    assert(!q.pop(e,71));
}
