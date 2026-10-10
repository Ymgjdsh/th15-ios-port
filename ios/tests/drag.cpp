#include "../../th15_web/cpp/game/PlayerMotion.hpp"
#include <cassert>
#include <cstdio>
struct Visuals:th15::PlayerMotionVisuals {
    bool focus_begin(bool,float)override{return true;}bool pose(th15::i32)override{return true;}
    void focus_position(const th15::Vec3&)override{}void option_position(th15::u32,const th15::Vec3&)override{}
    bool option_remove(th15::u32)override{return true;}bool barrier_position(const th15::Vec3&)override{return true;}bool barrier_remove()override{return true;}
};
int main(){
    Visuals visuals;
    const auto move=[&](int mode,bool slow,float x,float y){
        th15::PlayerMotion motion;motion.position_fixed={0,300*128};motion.position={0,300,0};
        motion.normal_speed=4*128;motion.focus_speed=2*128;motion.input_frame=10;
        motion.touch={mode,x,y};assert(motion.update(slow?8:0,true,1,visuals));return motion.position;
    };
    assert(move(1,false,100,300).x==4);
    assert(move(1,true,100,300).x==2);
    assert(move(2,false,100,300).x==100&&move(2,true,100,300).x==100);
    const auto edge=move(2,false,300,500);assert(edge.x==184&&edge.y==432);
    puts("PASS: real player drag speed cap, focused speed, unrestricted following and playfield bounds");
}
