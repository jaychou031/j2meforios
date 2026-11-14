#pragma once
#include <algorithm>
#include <cmath>
#include <map>
#include <vector>
#include <cstdint>

namespace controls {
struct Rect {
    double x=0, y=0, w=0, h=0;
    bool contains(double px, double py) const { return px>=x && py>=y && px<x+w && py<y+h; }
};
struct Layout { Rect viewport, left, right; };
inline Layout layout(double w, double h) {
    const double gap=8;
    if (w>h) {
        double pad=std::min(w*0.235, 195.0);
        return {{pad+gap,0,w-2*pad-2*gap,h}, {0,0,pad,h}, {w-pad,0,pad,h}};
    }
    double padHeight=std::min(300.0,h*0.43), padWidth=(w-gap)/2;
    return {{0,0,w,h-padHeight-gap}, {0,h-padHeight,padWidth,padHeight}, {padWidth+gap,h-padHeight,padWidth,padHeight}};
}
inline Rect fit(Rect area, int width, int height, bool pixel, double scale) {
    double k=std::min(area.w/width,area.h/height);
    if(pixel && k*scale>=1) k=std::floor(k*scale)/scale;
    return {area.x+(area.w-width*k)/2,area.y+(area.h-height*k)/2,width*k,height*k};
}
inline Rect cell(Rect pad,int col,int row) {
    double w=pad.w/3,h=pad.h/5;
    return {pad.x+col*w+2,pad.y+row*h+2,w-4,h-4};
}
// The visual gutter is not a dead zone. Keep a small amount of hysteresis
// around the current cell so finger jitter does not release a held key.
inline Rect hitCell(Rect pad,int col,int row) {
    double w=pad.w/3,h=pad.h/5;
    return {pad.x+col*w,pad.y+row*h,w,h};
}
struct HitKey { int code; Rect rect; };
inline int hitTest(const std::vector<HitKey>& keys,double x,double y,int current) {
    for(const auto& key:keys) if(key.code==current) {
        const double slop=6;
        Rect expanded={key.rect.x-slop,key.rect.y-slop,key.rect.w+2*slop,key.rect.h+2*slop};
        if(expanded.contains(x,y)) return current;
    }
    for(const auto& key:keys) if(key.rect.contains(x,y)) return key.code;
    return 0;
}
// A key stays down until the last finger holding it leaves. One ordered
// transition stream preserves short taps between two VM polls.
class HeldKeys {
    std::map<uintptr_t,int> fingers;
    std::map<int,int> counts;
public:
    int keyForFinger(uintptr_t finger) const {
        auto it=fingers.find(finger); return it==fingers.end()?0:it->second;
    }
    template<class Emit> void move(uintptr_t finger,int key,Emit emit) {
        auto it=fingers.find(finger);
        int old=it==fingers.end()?0:it->second;
        if(old==key) return;
        if(old && --counts[old]==0) emit(old,false);
        fingers.erase(finger);
        if(key) { fingers[finger]=key; if(counts[key]++==0) emit(key,true); }
    }
    template<class Emit> void clear(Emit emit) {
        for(auto pair:counts) if(pair.second) emit(pair.first,false);
        fingers.clear(); counts.clear();
    }
    bool down(int key) const { auto it=counts.find(key); return it!=counts.end() && it->second>0; }
};
}
