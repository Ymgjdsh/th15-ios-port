#include "../ControlLayout.hpp"
#include <cassert>
#include <cstdio>
#include <limits>
using namespace touhou::ios;
int main(){
    ToggleButton button;
    button.down(false);assert(button.active());button.up();assert(!button.active());
    button.down(true);assert(button.active());button.down(true);assert(button.active());
    button.up();assert(button.active());button.down(true);assert(!button.active());button.up();
    button.down(true);button.clear();assert(!button.active()&&!button.captured);
    assert(controlCoordinate(-500,390,0,0,80)==40);
    assert(controlCoordinate(1000,390,0,0,80)==350);
    assert(controlCoordinate(0,844,138,34,80)==178);
    assert(controlCoordinate(1000,844,138,34,80)==770);
    assert(controlCoordinate(0,100,10,10,140)==50);
    assert(controlCoordinate(std::numeric_limits<double>::quiet_NaN(),390,0,0,80)==40);
    // Normalized positions scale when the screen dimensions change.
    assert(controlCoordinate(.75*1024,1024,0,0,80)==768);
    std::puts("PASS: held/toggle transitions, cancellation, finite layout and safe bounds");
}
