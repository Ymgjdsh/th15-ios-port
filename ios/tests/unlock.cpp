#include "../Unlock.hpp"
#include <cassert>
#include <cstdio>
int main(){
    using namespace touhou::ios;
    assert(!validUnlockCode(nullptr)&&!validUnlockCode("wrong")&&validUnlockCode("ymgjdsh"));
    th15::Rng rng;th15::RecordStore records;records.reset(rng);
    assert(!records.title_records().extra_available());
    const int originalScore=records.characters[0].modes[0].scores[0][0].score;
    assert(unlockAllContents(records));
    assert(records.music_mask()==0xfffff);
    for(unsigned character=0;character<4;++character){
        assert(records.title_records().extra_character(character));
        for(const auto& difficulty:records.characters[character].practice)
            for(unsigned stage=1;stage<8;++stage)assert(difficulty[stage].visited);
    }
    assert(records.characters[0].modes[0].scores[0][0].score==originalScore);
    std::vector<th15::u8> bytes;assert(records.save(bytes));
    th15::RecordStore reopened;reopened.reset(rng);assert(reopened.open(bytes.data(),th15::u32(bytes.size())));
    assert(reopened.music_mask()==0xfffff&&reopened.title_records().extra_available());
    for(unsigned character=0;character<4;++character){
        assert(reopened.title_records().extra_character(character));
        for(const auto& difficulty:reopened.characters[character].practice)
            for(unsigned stage=1;stage<8;++stage)assert(difficulty[stage].visited);
    }
    puts("PASS: unlock code, all characters' Extra/practice and music, score preservation and saved-file round trip");
}
