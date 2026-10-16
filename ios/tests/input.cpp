#include "../../portable/input/TouchController.hpp"
#include "../../portable/sdl/FrameCadence.hpp"
#include <cassert>
#include <cstdio>
int main(){
 using namespace touhou::input;TouchState s;s.context=1;s.instance=1;s.ready=true;s.x=0;s.y=300;s.fast=4;s.slow=2;s.min_x=-184;s.max_x=184;s.min_y=32;s.max_y=432;
 TouchController t;t.two_finger=true;t.double_tap=true;t.pointer(0,1,.5,.5,0,s,false);t.pointer(1,1,.55,.5,10,s,false);auto a=t.sample(s,11,false,false);assert(a.motion==1&&a.x>0);
 t.pointer(0,2,.7,.5,12,s,false);assert(t.sample(s,13,false,false).keys[16]);t.reset();assert(!t.sample(s,14,false,false).motion);
 t.pointer(0,1,.5,.5,20,s,false);t.pointer(2,1,.5,.5,40,s,false);t.pointer(0,2,.5,.5,80,s,false);assert(t.sample(s,81,false,false).keys[88]);
 // Both drag modes use the same bounded target. Only unrestricted dragging
 // requests mode 2, which PlayerMotion follows without its speed cap.
 t.reset();t.unlimited=false;t.pointer(0,1,.5,.5,82,s,false);t.pointer(1,1,.8,.5,83,s,false);auto limited=t.sample(s,84,false,false);
 assert(limited.motion==1&&limited.x==184);t.reset();t.unlimited=true;t.pointer(0,1,.5,.5,85,s,true);t.pointer(1,1,.8,.5,86,s,true);auto unrestricted=t.sample(s,87,true,false);
 assert(unrestricted.motion==2&&unrestricted.x==184);t.reset();assert(t.sample(s,88,false,false).motion==0);
 // Pending hits must suspend, rather than discard, a held drag. Shield
 // recovery and deathbomb recovery both reuse the same finger in both modes.
 for(bool unlimited:{false,true}){
  t.reset();t.unlimited=unlimited;s.ready=true;s.retain_drag=false;
  t.pointer(0,7,.5,.5,90,s,false);t.pointer(1,7,.52,.5,91,s,false);
  assert(t.sample(s,92,false,false).motion==(unlimited?2:1));
  s.ready=false;s.retain_drag=true;
  assert(!t.sample(s,93,false,false).motion&&t.active());
  t.pointer(1,7,.54,.5,94,s,false);assert(t.active());
  s.ready=true;s.retain_drag=false;t.pointer(1,7,.55,.5,95,s,false);
  auto resumed=t.sample(s,96,false,false);assert(resumed.motion==(unlimited?2:1)&&std::abs(resumed.x-6.4f)<.001f);
  t.pointer(2,7,.55,.5,97,s,false);assert(!t.active()&&!t.sample(s,98,false,false).motion);
  t.pointer(0,8,.5,.5,99,s,false);s.ready=false;s.retain_drag=true;
  t.pointer(2,8,.5,.5,100,s,false);s.ready=true;assert(!t.sample(s,101,false,false).motion);
  t.pointer(0,9,.5,.5,102,s,false);s.ready=false;s.retain_drag=false;
  assert(!t.sample(s,103,false,false).motion&&!t.active());s.ready=true;
  t.pointer(0,10,.5,.5,104,s,false);s.instance++;assert(!t.sample(s,105,false,false).motion);
 }
 t.reset();s.context=0;t.pointer(0,1,.5,.5,100,s,false);t.pointer(1,1,.5,.7,110,s,false);assert(t.sample(s,111,false,false).keys[40]);
 t.reset();t.pointer(0,1,.5,.5,120,s,false);t.pointer(2,1,.5,.5,140,s,false);assert(t.sample(s,141,false,false).keys[90]);
 for(double hz:{30.,60.,90.,120.}){touhou::sdl::FrameCadence c;unsigned total=0;for(int i=0;i<int(hz*10);i++)total+=c.advance(1/hz);assert(total==600);c.reset();assert(c.advance(.1)==4);}
 std::puts("TH15 gesture and fixed cadence checks passed");
}
