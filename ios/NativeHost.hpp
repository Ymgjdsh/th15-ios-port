#pragma once
#include <cstdint>
void* sdl_game_open(bool smoke);
void* sdl_window();
const char* sdl_file_error();
const std::int32_t* sdl_game_status();
void sdl_loop_start(void*);
int sdl_loop_frame(double);
void sdl_loop_pause(int);
void sdl_key(const char*,int);
void sdl_keys_clear();
void sdl_touch_options(int,int,float);
void sdl_touch_mode(unsigned);
void sdl_touch_gestures(int,int);
void sdl_touch_controls(int,int,unsigned,unsigned,float,float);
void sdl_set_viewport(float,float,float,float);
void sdl_set_portrait_header(float,float);
void sdl_display_options(bool,bool);
bool sdl_zoom_active();
bool sdl_controls_gameplay();
void sdl_auto_bomb(bool);
void sdl_developer_enabled(bool);
bool sdl_developer_available();
bool sdl_developer_invincible();
bool sdl_developer_action(int);
int sdl_unlock_code(const char*);
#if TH15_DIAGNOSTICS
bool sdl_test_stage(int,int);
void sdl_test_protect();
bool sdl_test_auto_bomb();
void sdl_test_key(unsigned,bool);
const char* sdl_test_state();
#endif
