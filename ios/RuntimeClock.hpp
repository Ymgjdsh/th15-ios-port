#pragma once
#include <SDL3/SDL.h>
namespace touhou::ios {
inline double pausedSeconds=0,pauseOrigin=-1;
inline double rawSeconds(){return double(SDL_GetTicksNS())/1.e9;}
inline double activeSeconds(){return (pauseOrigin<0?rawSeconds():pauseOrigin)-pausedSeconds;}
inline void suspendClock(bool paused){if(paused&&pauseOrigin<0)pauseOrigin=rawSeconds();else if(!paused&&pauseOrigin>=0){pausedSeconds+=rawSeconds()-pauseOrigin;pauseOrigin=-1;}}
}
