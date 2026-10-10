#pragma once
#include <SDL3/SDL.h>
#include <string>
namespace th15::sdl {
inline std::string asset_path(const std::string& name){
#ifdef __EMSCRIPTEN__
 return "/"+name;
#else
 const char* base=SDL_GetBasePath();return std::string(base?base:"")+"assets/"+name;
#endif
}
inline std::string save_path(){
#ifdef __EMSCRIPTEN__
 return "/save";
#else
 char* path=SDL_GetPrefPath("TouhouNative","TH15");std::string result=path?path:"";SDL_free(path);if(!result.empty()&&result.back()=='/')result.pop_back();return result;
#endif
}
}
