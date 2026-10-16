#pragma once
#include <algorithm>
#include <array>

namespace touhou::ios {
struct PortraitLayout {
    std::array<float,4> playfield{0,0,1,1};
    std::array<float,4> header{0,0,1,0};
};
// All rectangles are normalized screen coordinates. Drawing and touch input
// consume the same result, including letterboxing and device safe areas.
inline PortraitLayout displayLayout(float width,float height,float left,float top,float right,float bottom,bool portraitBattle){
    if(width<=0||height<=0)return {};
    left=std::clamp(left,0.f,width);right=std::clamp(right,0.f,width-left);
    top=std::clamp(top,0.f,height);bottom=std::clamp(bottom,0.f,height-top);
    const float availableWidth=std::max(1.f,width-left-right),availableHeight=std::max(1.f,height-top-bottom);
    if(portraitBattle&&height>width){
        // Original playfield 384x448, with two 224-wide HUD columns above it.
        // The shorter right HUD column is padded to 160 source pixels.
        constexpr float headerRatio=160.f/448.f,playfieldRatio=448.f/384.f;
        const float contentWidth=std::min(availableWidth,availableHeight/(headerRatio+playfieldRatio));
        const float headerHeight=contentWidth*headerRatio,playfieldHeight=contentWidth*playfieldRatio;
        const float x=left+(availableWidth-contentWidth)*.5f;
        const float y=top+(availableHeight-headerHeight-playfieldHeight)*.5f;
        return {{x/width,(y+headerHeight)/height,contentWidth/width,playfieldHeight/height},
                {x/width,y/height,contentWidth/width,headerHeight/height}};
    }
    // TH07's ordinary presentation fits the complete original 4:3 canvas.
    const float scale=std::min(availableWidth/640.f,availableHeight/480.f);
    const float w=640*scale,h=480*scale;
    return {{(left+(availableWidth-w)*.5f)/width,(top+(availableHeight-h)*.5f)/height,w/width,h/height},{0,0,0,0}};
}
}
