#include "../../th15_web/cpp/game/AutomaticBomb.hpp"
#include <cassert>
#include <cstdio>
struct Life {int state=1;struct {int current=0;} invulnerability;};
struct Session {int bombs=3,bomb_state=0;};
struct Host {Session& s;int calls=0;bool allowed=true,accept=true,consume=true;
    bool allow_bomb(){return allowed;}
    bool begin_bomb(){++calls;if(!accept)return false;if(consume){--s.bombs;s.bomb_state=1;}return true;}
};
int main(){
    Life l;Session s;Host h{s};
    assert(th15::automatic_bomb(false,l,s,h)==0&&h.calls==0);
    l.invulnerability.current=1;assert(th15::automatic_bomb(true,l,s,h)==0);l.invulnerability.current=0;
    l.state=4;assert(th15::automatic_bomb(true,l,s,h)==0);l.state=1;
    s.bombs=0;assert(th15::automatic_bomb(true,l,s,h)==0);s.bombs=3;
    h.allowed=false;assert(th15::automatic_bomb(true,l,s,h)==0);h.allowed=true;
    assert(th15::automatic_bomb(true,l,s,h)==1&&s.bombs==2&&h.calls==1);
    assert(th15::automatic_bomb(true,l,s,h)==0&&h.calls==1);
    s.bomb_state=2;assert(th15::automatic_bomb(true,l,s,h)==0&&h.calls==1);
    s.bomb_state=0;h.accept=false;assert(th15::automatic_bomb(true,l,s,h)==-1&&s.bombs==2);
    h.accept=true;h.consume=false;assert(th15::automatic_bomb(true,l,s,h)==-1&&s.bombs==2);
    std::puts("PASS: auto Bomb eligibility, single consumption, active bomb and failed service");
}
