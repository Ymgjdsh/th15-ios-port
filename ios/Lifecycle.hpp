#pragma once
#include <cstdint>
namespace touhou::ios {
class Lifecycle {
public:
 enum Reason : std::uint32_t { inactive=1, audioInterruption=2, settings=4, stopped=8, developer=16, layout=32 };
 bool running() const noexcept { return reasons==0; }
 bool set(Reason reason,bool paused) noexcept { const bool before=running(); if(paused) reasons|=reason; else reasons&=~std::uint32_t(reason); return before!=running(); }
private: std::uint32_t reasons=0;
};
}
