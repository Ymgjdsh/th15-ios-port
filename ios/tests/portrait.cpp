#include "../PortraitLayout.hpp"
#include <cassert>
#include <cmath>
#include <cstdio>
int main(){
    using touhou::ios::displayLayout;
    // iPad, notched iPhone, SE, compact phone and iPad Pro, both orientations.
    for(auto device:{std::array<float,4>{768,1024,0,0},{390,844,47,34},{375,667,20,0},{320,568,20,0},{834,1194,24,20}}){
      for(bool landscape:{false,true})for(bool battle:{false,true}){
        const float width=device[landscape?1:0],height=device[landscape?0:1];
        const float left=landscape?device[2]:0,top=landscape?0:device[2],bottom=device[3],right=landscape?device[2]:0;
        const auto layout=displayLayout(width,height,left,top,right,bottom,battle);
        const auto& p=layout.playfield;const auto& h=layout.header;
        const float ratio=battle&&!landscape?384.f/448.f:640.f/480.f;
        assert(std::abs(p[2]*width/(p[3]*height)-ratio)<.00001f);
        assert(p[0]*width>=left-.001f&&p[1]*height>=top-.001f);
        assert((p[0]+p[2])*width<=width-right+.001f&&(p[1]+p[3])*height<=height-bottom+.001f);
        if(battle&&!landscape){
            assert(std::abs(h[1]+h[3]-p[1])<.00001f);
            assert(std::abs(h[2]*width*.5f/(h[3]*height)-224.f/160.f)<.00001f);
            assert(h[1]*height>=top-.001f);
        }
        // Equal on-screen X/Y distances must produce equal game distances.
        const float sourceWidth=battle&&!landscape?384:640,sourceHeight=battle&&!landscape?448:480;
        assert(std::abs(20/(p[2]*width)*sourceWidth-20/(p[3]*height)*sourceHeight)<.0001f);
      }
    }
    puts("PASS: iPhone/iPad 4:3 canvas, 384:448 portrait field, HUD aspect, safe areas and isotropic touch mapping");
}
