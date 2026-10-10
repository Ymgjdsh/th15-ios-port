#pragma once
#include <algorithm>
#include <cmath>
namespace touhou::ios {
inline double controlCoordinate(double value,double extent,double leading,double trailing,double diameter){
    const double half=std::min(diameter/2,std::max(0.,extent-leading-trailing)/2);
    const double lo=leading+half,hi=std::max(lo,extent-trailing-half);
    return std::clamp(std::isfinite(value)?value:lo,lo,hi);
}
class ToggleButton {
public:
    bool held=false,latched=false,captured=false;
    void down(bool toggle){if(captured)return;captured=true;if(toggle)latched=!latched;else held=true;}
    void up(){captured=false;held=false;}
    void clear(){held=latched=captured=false;}
    bool active()const{return held||latched;}
};
}
