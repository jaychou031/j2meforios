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

    // Numeric keys cover their gutters, including both sides of a seam.
    // A stationary hold and small finger jitter must not generate releases.
    for(auto size: {std::pair<double,double>{390,700},{750,340}}) {
        auto pad=controls::layout(size.first,size.second).right;
        std::vector<controls::HitKey> caps;
        for(int i=0;i<9;i++) caps.push_back({i+1,controls::hitCell(pad,i%3,i/3)});
        auto a=caps[3].rect, b=caps[4].rect;
        double seam=a.x+a.w, y=a.y+a.h/2;
        assert(controls::hitTest(caps,seam-0.1,y,0)==4);
        assert(controls::hitTest(caps,seam+0.1,y,0)==5);
        keys.move(10,controls::hitTest(caps,a.x+a.w/2,y,0),emit);
        auto heldCount=events.size();
        for(int i=0;i<1000;i++) {
            double x=seam+(i%2?3.0:-3.0);
            keys.move(10,controls::hitTest(caps,x,y,keys.keyForFinger(10)),emit);
        }
        assert(events.size()==heldCount && keys.down(4));
        // Deliberately sliding to the next cell gives one release then press.
        keys.move(10,controls::hitTest(caps,b.x+b.w/2,y,keys.keyForFinger(10)),emit);
        assert(events.size()==heldCount+2 && !keys.down(4) && keys.down(5));
        assert(events[heldCount]==std::make_pair(4,false));
        assert(events[heldCount+1]==std::make_pair(5,true));
        // Moving well away from the keypad releases the old key.
        keys.move(10,controls::hitTest(caps,pad.x-20,y,keys.keyForFinger(10)),emit);
        assert(!keys.down(5) && keys.keyForFinger(10)==0);
    }
    // Direction and fire are independent. Cancelling one finger must not
    // release another finger on the same key; cancelling all releases both.
    keys.move(11,4,emit); keys.move(12,5,emit); keys.move(13,4,emit);
    keys.move(11,0,emit);
    assert(keys.down(4) && keys.down(5));
    auto cancelCount=events.size(); keys.clear(emit);
    assert(events.size()==cancelCount+2 && !keys.down(4) && !keys.down(5));
    assert(keys.keyForFinger(12)==0 && keys.keyForFinger(13)==0);
}
