#pragma once
#include <cstdint>
namespace session {
// Audio interruption is deliberately independent of the VM pause gate. A
// missing interruption-ended notification must not strand the Java thread.
struct Lifecycle {
    bool active=true, menu=false, stopping=false, audioAvailable=true;
    bool pauseVM() const { return !active || menu || stopping; }
    bool pauseAudio() const { return pauseVM() || !audioAvailable; }
};
// Accessed under State::lock. System pause time is excluded from game timers.
class Clock {
    uint64_t pausedAt=0, excluded=0;
    bool paused=false;
public:
    void setPaused(bool value,uint64_t host) {
        if(value==paused) return;
        if(value) pausedAt=host;
        else excluded+=host-pausedAt;
        paused=value;
    }
    uint64_t now(uint64_t host) const { return (paused?pausedAt:host)-excluded; }
};
}
