#pragma once
#include <algorithm>
#include <cmath>
#include <cstdint>
namespace audio {
inline int16_t toneSample(unsigned frequency,unsigned frame,unsigned length,unsigned rate) {
    if(!frequency || !rate || !length || frame>=length) return 0;
    // Five-millisecond attack/release prevents a cut mid-wave from clicking.
    unsigned ramp=std::max(1u,std::min(rate/200,length/2));
    double envelope=std::min(1.0,static_cast<double>(std::min(frame,length-1-frame))/ramp);
    return static_cast<int16_t>(std::sin(6.283185307179586*frequency*frame/rate)*6000*envelope);
}
}
