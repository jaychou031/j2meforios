#include "../ios/SessionLifecycle.hpp"
#include <cassert>
#include <cstdio>
int main() {
    session::Lifecycle state;
    assert(!state.pauseVM() && !state.pauseAudio());
    state.active=false; assert(state.pauseVM() && state.pauseAudio());
    state.audioAvailable=false; // interruption during background suspension
    state.active=true; // no interruption-ended notification ever arrives
    assert(!state.pauseVM() && state.pauseAudio());
    state.audioAvailable=true; assert(!state.pauseVM() && !state.pauseAudio());
    state.menu=true;state.active=false;state.active=true;
    assert(state.pauseVM()); // foreground must not dismiss a user's pause menu
    state.menu=false;assert(!state.pauseVM());
    state.stopping=true;assert(state.pauseVM());
    session::Clock clock;
    assert(clock.now(100)==100);
    clock.setPaused(true,150);assert(clock.now(15150)==150);
    clock.setPaused(true,15150); // repeated notifications do not reset pause start
    clock.setPaused(false,20150);assert(clock.now(20200)==200);
    clock.setPaused(true,20300);clock.setPaused(false,20400);assert(clock.now(20500)==400);
    std::puts("Lifecycle: independent audio/VM gates and paused game clock passed.");
}
