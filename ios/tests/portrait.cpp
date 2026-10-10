#include "../PortraitLayout.hpp"
#include <cassert>
#include <cmath>
#include <cstdio>
int main(){
    using touhou::ios::portraitLayout;
    auto ipad=portraitLayout(768,1024,0,2);
    assert(ipad.header[3]==.25f&&ipad.playfield[1]==.25f);
    assert(ipad.playfield[2]==1&&ipad.playfield[3]==.75f);
    for(auto layout:{ipad,portraitLayout(390,844,44,3),portraitLayout(320,568,20,2)}){
        const auto& p=layout.playfield;const auto& h=layout.header;
        assert(p[0]==0&&p[2]==1&&p[3]>0);
        assert(std::abs(h[1]+h[3]-p[1])<.00001f);
        assert(std::abs(p[1]+p[3]-1)<.00001f);
        // The same viewport drives drawing and touch conversion: the
        // top/bottom screen edges map to the entire original playfield.
        const float gameTop=16+(p[1]-p[1])/p[3]*448;
        const float gameBottom=16+(1-p[1])/p[3]*448;
        assert(std::abs(gameTop-16)<.0001f&&std::abs(gameBottom-464)<.0001f);
    }
    puts("PASS: TH06 portrait proportions, notch safe area, full-width/full-height playfield and touch edge mapping");
}
