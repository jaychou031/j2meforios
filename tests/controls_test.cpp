#include "../ios/Controls.hpp"
#include <cassert>
#include <utility>
int main() {
    for(auto size: {std::pair<double,double>{390,700},{750,340},{320,500},{844,390}}) {
        auto l=controls::layout(size.first,size.second);
        for(auto r:{l.viewport,l.left,l.right}) {
            assert(r.x>=0 && r.y>=0 && r.w>0 && r.h>0);
            assert(r.x+r.w<=size.first+0.001 && r.y+r.h<=size.second+0.001);
        }
        for(auto game:{std::pair<int,int>{240,320},{176,208},{128,160},{320,240}}) {
            for(bool pixel:{false,true}) {
                auto r=controls::fit(l.viewport,game.first,game.second,pixel,3);
                assert(r.w<=l.viewport.w+0.001 && r.h<=l.viewport.h+0.001);
                assert(std::abs(r.w/r.h-double(game.first)/game.second)<0.00001);
            }
        }
    }
    controls::HeldKeys keys;
    std::vector<std::pair<int,bool>> events;
    auto emit=[&](int k,bool down){ events.emplace_back(k,down); };
    keys.move(1,5,emit); keys.move(2,5,emit); keys.move(1,0,emit);
    assert(events.size()==1 && keys.down(5));
    keys.move(2,6,emit);
    assert(events.size()==3 && events[1]==std::make_pair(5,false));
    keys.move(3,7,emit); keys.clear(emit);
    assert(!keys.down(6) && !keys.down(7) && events.size()==6);
    keys.clear(emit); assert(events.size()==6);
}
