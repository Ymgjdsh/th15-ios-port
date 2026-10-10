#pragma once
#include "../th15_web/cpp/game/RecordStore.hpp"
#include <algorithm>
#include <cstring>
namespace touhou::ios {
inline bool validUnlockCode(const char* code){return code&&std::strcmp(code,"ymgjdsh")==0;}
inline bool unlockAllContents(th15::RecordStore& records){
    if(!records.unlock_all())return false;
    // The original code leaves music flags separate. The mobile full-unlock
    // command also exposes every track and every character's Extra/practice.
    records.music.fill(1);
    for(unsigned character=0;character<4;++character){
        auto& entry=records.characters[character];
        for(auto& mode:entry.modes)for(auto& clear:mode.without_continue)clear=std::max(clear,1);
        for(auto& difficulty:entry.practice)for(unsigned stage=1;stage<8;++stage)difficulty[stage].visited=1;
    }
    return true;
}
}
