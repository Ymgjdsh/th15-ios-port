#pragma once
#include <algorithm>
#include <array>

namespace touhou::ios {
struct PortraitLayout {
    std::array<float,4> playfield{0,0,1,1};
    std::array<float,4> header{0,0,1,0};
};
// TH06's header uses 36% of the width, capped at 25% of the height.
// The remaining display is entirely occupied by the original playfield.
inline PortraitLayout portraitLayout(float width,float height,float safeTop,float scale){
    if(width<=0||height<=0)return {};
    safeTop=std::clamp(safeTop,0.f,height);
    const float header=std::min(height-safeTop,std::max(96.f/std::max(1.f,scale),std::min(width*.36f,height*.25f)));
    const float y=(safeTop+header)/height;
    return {{0,y,1,1-y},{0,safeTop/height,1,header/height}};
}
}
