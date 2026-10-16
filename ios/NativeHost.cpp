#include "NativeHost.hpp"
#include "RuntimeClock.hpp"
#include "Unlock.hpp"
#include "PortraitLayout.hpp"
#include "../th15_web/cpp/sdl/ApplicationState.hpp"
#include "../th15_web/cpp/game/GameKeyboard.hpp"
#include "../portable/input/TouchController.hpp"
#include "../portable/sdl/FrameCadence.hpp"
#include <SDL3/SDL.h>
#include <cstring>
#include <cstdio>
#include <unordered_map>
using namespace th15;
namespace {
std::unique_ptr<th15::sdl::ApplicationState> app;
touhou::input::TouchController gestures;GameInput input;
touhou::sdl::FrameCadence cadence;
bool keys[256]{},paused=false,focus_lost=false,discard_focus_events=false,zoom=false;
unsigned key_pulses[256]{};int previous_menu_x=0,previous_menu_y=0;
double previous=-1;std::string failure;
std::unordered_map<SDL_FingerID,int> fingers;int next_finger=1;unsigned last_bomb=0,menu_escape=0;
SDL_Gamepad* gamepad=nullptr;
bool developer_enabled=false,developer_invincible=false;
bool automatic_bombs=false;
float display_width=640,display_height=480,display_left=0,display_top=0,display_right=0,display_bottom=0;
#if TH15_DIAGNOSTICS
unsigned test_pointer_events=0,test_pointer_downs=0;
#endif
void update_presentation(){
 if(!app)return;
 const bool portrait=sdl_zoom_active();
 const auto layout=touhou::ios::displayLayout(display_width,display_height,display_left,display_top,display_right,display_bottom,portrait);
 auto& backend=app->graphics.backend;backend.portraitHud=portrait;
 backend.sourceRect=portrait?std::array<float,4>{32,16,384,448}:std::array<float,4>{0,0,640,480};
 backend.displayRect=layout.playfield;backend.portraitHeader=layout.header;
}
void open_gamepad(){
 if(gamepad)return;int count=0;auto* ids=SDL_GetGamepads(&count);
 for(int i=0;i<count&&!gamepad;i++)gamepad=SDL_OpenGamepad(ids[i]);
 SDL_free(ids);
}
u32 controller_sample(bool* merged){
 u32 buttons=0;
 if(gamepad){
  for(int i=0;i<SDL_GAMEPAD_BUTTON_COUNT&&i<31;i++)if(SDL_GetGamepadButton(gamepad,SDL_GamepadButton(i)))buttons|=1u<<i;
  const float x=SDL_GetGamepadAxis(gamepad,SDL_GAMEPAD_AXIS_LEFTX)/32767.f,y=SDL_GetGamepadAxis(gamepad,SDL_GAMEPAD_AXIS_LEFTY)/32767.f;
  merged[37]|=x<-.25f||SDL_GetGamepadButton(gamepad,SDL_GAMEPAD_BUTTON_DPAD_LEFT);
  merged[39]|=x>.25f||SDL_GetGamepadButton(gamepad,SDL_GAMEPAD_BUTTON_DPAD_RIGHT);
  merged[38]|=y<-.25f||SDL_GetGamepadButton(gamepad,SDL_GAMEPAD_BUTTON_DPAD_UP);
  merged[40]|=y>.25f||SDL_GetGamepadButton(gamepad,SDL_GAMEPAD_BUTTON_DPAD_DOWN);
  constexpr unsigned actions[]{90,88,16,27};
  for(int i=0;i<4;i++){const int binding=app->controller.values[i];if(binding>=0&&binding<31&&(buttons&(1u<<binding)))merged[actions[i]]=true;}
 }
 // The original Key Config waits for controller button numbers. Permit its
 // four assignments using Z/X/S/pause even when no MFi pad is attached.
 if(app->title&&app->title->state.screen==TitleScreen::Controller){
  if(merged[90])buttons|=1;if(merged[88])buttons|=2;if(merged[16])buttons|=4;if(merged[27])buttons|=8;
 }
 return buttons;
}
touhou::input::TouchState state(){
 touhou::input::TouchState s;if(!app||!app->scene()||!app->session)return s;
 if(app->pause&&app->pause->state.screen!=PauseScreen::Inactive)return s;
 if(app->progress.replay){s.context=3;return s;}
 auto& stage=*app->scene();if(stage.messages.active()){s.context=2;return s;}
 auto& player=*stage.battle.player;auto& motion=player.motion;s.context=1;s.instance=app->progress.stage;
 s.ready=player.life.state==1&&!(app->progress.scene_flags&(4|0x70|0x4000|0x10000));
 s.retain_drag=player.life.state==4&&!(app->progress.scene_flags&(4|0x70|0x4000|0x10000));
 s.x=motion.position.x;s.y=motion.position.y;s.fast=float(motion.normal_speed)/128;s.slow=float(motion.focus_speed)/128;
 s.min_x=-184;s.max_x=184;s.min_y=32;s.max_y=432;return s;
}
void pump(){
 SDL_Event e;while(SDL_PollEvent(&e)){
  if(e.type==SDL_EVENT_GAMEPAD_REMOVED&&gamepad&&SDL_GetGamepadID(gamepad)==e.gdevice.which){SDL_CloseGamepad(gamepad);gamepad=nullptr;}
  if(e.type==SDL_EVENT_GAMEPAD_ADDED)open_gamepad();
  if(e.type==SDL_EVENT_WINDOW_FOCUS_LOST){sdl_keys_clear();if(!discard_focus_events)focus_lost=true;}
  if(e.type==SDL_EVENT_FINGER_CANCELED){gestures.cancel();fingers.erase(e.tfinger.fingerID);continue;}
  if(e.type==SDL_EVENT_FINGER_DOWN||e.type==SDL_EVENT_FINGER_MOTION||e.type==SDL_EVENT_FINGER_UP||e.type==SDL_EVENT_FINGER_CANCELED){
#if TH15_DIAGNOSTICS
   ++test_pointer_events;if(e.type==SDL_EVENT_FINGER_DOWN)++test_pointer_downs;
#endif
   auto found=fingers.find(e.tfinger.fingerID);if(e.type==SDL_EVENT_FINGER_DOWN)found=fingers.emplace(e.tfinger.fingerID,next_finger++).first;
   if(found==fingers.end())continue;
   const auto r=app->graphics.backend.displayRect,c=app->graphics.backend.sourceRect;
   const float x=(e.tfinger.x-r[0])/r[2],y=(e.tfinger.y-r[1])/r[3];
#if TH15_DIAGNOSTICS
   std::fprintf(stderr,"POINTER type=%u raw=%.3f,%.3f mapped=%.3f,%.3f ready=%d mode=%d active=%d\n",e.type,e.tfinger.x,e.tfinger.y,x,y,state().ready,gestures.mode,gestures.active());
#endif
   if(e.type!=SDL_EVENT_FINGER_DOWN||(x>=0&&x<=1&&y>=0&&y<=1))
    gestures.pointer(e.type==SDL_EVENT_FINGER_DOWN?0:e.type==SDL_EVENT_FINGER_MOTION?1:2,found->second,(c[0]+x*c[2])/640,(c[1]+y*c[3])/480,SDL_GetTicks(),state(),keys[16]);
   if(e.type==SDL_EVENT_FINGER_UP||e.type==SDL_EVENT_FINGER_CANCELED)fingers.erase(found);
  }
 }
 discard_focus_events=false;
}
bool tick(){
 if(app&&app->scene())app->scene()->battle.automatic_bombs=automatic_bombs&&state().context==1&&state().ready;
 if(developer_enabled&&developer_invincible&&sdl_developer_available()){
  auto& life=app->scene()->battle.player->life;
  // Refresh a short protection window; turning the option off releases it
  // within four ticks without discarding a natural respawn/bomb shield.
  if(life.invulnerability.current<4)life.invulnerability.set(4);
 }
 bool merged[256];std::memcpy(merged,keys,sizeof keys);const auto* physical=SDL_GetKeyboardState(nullptr);
 for(int i=0;i<256;i++)if(key_pulses[i]){merged[i]=true;--key_pulses[i];}
 constexpr std::pair<SDL_Scancode,unsigned> map[]={{SDL_SCANCODE_Z,90},{SDL_SCANCODE_X,88},{SDL_SCANCODE_LSHIFT,16},{SDL_SCANCODE_RSHIFT,16},{SDL_SCANCODE_ESCAPE,27},{SDL_SCANCODE_RETURN,13},{SDL_SCANCODE_UP,38},{SDL_SCANCODE_DOWN,40},{SDL_SCANCODE_LEFT,37},{SDL_SCANCODE_RIGHT,39},{SDL_SCANCODE_LCTRL,17}};
 for(auto p:map)merged[p.second]|=physical[p.first];
 app->controller_buttons=controller_sample(merged);
 auto sample=gestures.sample(state(),SDL_GetTicks(),merged[16],merged[37]||merged[38]||merged[39]||merged[40]);
 for(int i=0;i<256;i++){merged[i]|=sample.keys[i];app->keyboard_state.keys[i]=merged[i]?128:0;}app->keyboard_state.format=2;
 app->touch={sample.motion,sample.x,sample.y};input.update(keyboard_keys(merged));
 const bool lost=focus_lost;focus_lost=false;
 const bool ok=app->step(input.held,input.pressed,input.repeated,60,lost);
 update_presentation();
 return ok;
}
}
void* sdl_game_open(bool){app=std::make_unique<th15::sdl::ApplicationState>();if(!app->initialize(true)){failure=app->failure;return nullptr;}app->graphics.backend.defer=true;open_gamepad();return app.get();}
void* sdl_window(){return SDL_GL_GetCurrentWindow();}
const char* sdl_file_error(){return failure.c_str();}
const std::int32_t* sdl_game_status(){static std::int32_t empty[16]{};return app?app->projection():empty;}
void sdl_loop_start(void*){previous=-1;cadence.reset();}
int sdl_loop_frame(double now){if(!app||paused)return 0;update_presentation();pump();const unsigned ticks=previous<0?1:cadence.advance(now-previous);previous=now;for(unsigned i=0;i<ticks;i++)if(!tick()){failure=app->failure;return app->exiting?1:2;}if(ticks)app->graphics.backend.commit();return 0;}
void sdl_loop_pause(int value){
 paused=value;touhou::ios::suspendClock(value);previous=-1;cadence.reset();sdl_keys_clear();
 // Native panels and UIKit lifecycle already suspend the complete game.
 // Feeding that suspension back as a desktop focus loss opens a second
 // in-game pause menu after closing settings and consumes the next Z tap.
 focus_lost=false;if(value)discard_focus_events=true;
 if(app){if(value)app->save_settings();app->audio_device.suspend(value);}
}
void sdl_key(const char* name,int held){
 int key=-1;if(!std::strcmp(name,"KeyZ"))key=90;else if(!std::strcmp(name,"KeyX"))key=88;else if(!std::strcmp(name,"ShiftLeft"))key=16;else if(!std::strcmp(name,"Escape"))key=27;
 if(key<0)return;
 // Preserve short UIKit taps until a logic tick consumes them. This matters
 // in title/menu transitions where a down/up can arrive between frames.
 if(held&&!keys[key]&&state().context!=1)key_pulses[key]=3;
 keys[key]=held;
}
void sdl_keys_clear(){SDL_ResetKeyboard();std::memset(keys,0,sizeof keys);std::memset(key_pulses,0,sizeof key_pulses);previous_menu_x=previous_menu_y=0;input={};gestures.reset();fingers.clear();if(app){app->touch={};app->keyboard_state={};}}
void sdl_touch_options(int enabled,int unlimited,float sensitivity){gestures.enabled=enabled;gestures.unlimited=unlimited;gestures.sensitivity=sensitivity;}
void sdl_touch_mode(unsigned mode){if(gestures.mode!=int(mode))gestures.clear_motion();gestures.mode=mode;}
void sdl_touch_gestures(int two,int bomb){gestures.two_finger=two;gestures.double_tap=bomb;}
void sdl_touch_controls(int shoot,int slow,unsigned bomb,unsigned escape,float x,float y){
 const int context=state().context;
 if(bomb!=last_bomb&&context!=1)++menu_escape;last_bomb=bomb;
 const int dx=x<-.25f*32767?-1:x>.25f*32767?1:0,dy=y<-.25f*32767?-1:y>.25f*32767?1:0;
 if(context!=1&&context!=3){if(dx&&dx!=previous_menu_x)key_pulses[dx<0?37:39]=3;if(dy&&dy!=previous_menu_y)key_pulses[dy<0?38:40]=3;}
 previous_menu_x=dx;previous_menu_y=dy;
 gestures.controls(shoot,slow,bomb,escape+menu_escape,x,y);
}
void sdl_display_geometry(float w,float h,float left,float top,float right,float bottom){display_width=w;display_height=h;display_left=left;display_top=top;display_right=right;display_bottom=bottom;update_presentation();}
void sdl_display_options(bool smooth,bool crop){zoom=crop;if(app)app->graphics.backend.smooth=smooth;}
bool sdl_zoom_active(){return zoom&&display_height>display_width&&app&&app->session&&app->scene()&&(!app->pause||app->pause->state.screen==PauseScreen::Inactive);}
bool sdl_controls_gameplay(){const auto context=state().context;return context==1||context==3;}
void sdl_auto_bomb(bool enabled){automatic_bombs=enabled;}
void sdl_developer_enabled(bool enabled){developer_enabled=enabled;if(!enabled)developer_invincible=false;}
bool sdl_developer_available(){return app&&app->session&&app->scene()&&!app->progress.replay;}
bool sdl_developer_invincible(){return developer_invincible;}
bool sdl_developer_action(int action){
 if(!developer_enabled||!sdl_developer_available()||action<0||action>6)return false;
 auto& scene=*app->scene();auto& battle=scene.battle;
 if(action==0){developer_invincible=!developer_invincible;return true;}
 if(action==1||action==5){battle.score.score=999999999;scene.hud.displayed_score=battle.score.score;scene.hud.score_increment=0;app->progress.high_score=app->progress.high_score_extra=battle.score.score;}
 if(action==2||action==5){battle.score.graze_total=battle.score.graze_chapter=999999;battle.score.point_items=9999;battle.score.point_value=battle.score.max_point_value;}
 if(action==3||action==5){battle.session.power=battle.score.max_power;if(!battle.player->configure_options()){failure=battle.player->error;return false;}}
 if(action==4||action==5){battle.session.extra_lives=8;battle.session.bombs=8;battle.session.life_pieces=battle.session.bomb_pieces=0;if(!scene.hud.life(8,0)||!scene.hud.bombs(8,0)){failure=scene.hud.error;return false;}}
 if(action==6&&(!battle.bullet_scene->cancel_all(0)||!battle.laser_scene->cancel_all(0,false))){failure="Developer bullet cancellation failed";return false;}
 return true;
}
int sdl_unlock_code(const char* code){
 if(!touhou::ios::validUnlockCode(code))return 0;
 if(!app||!touhou::ios::unlockAllContents(app->records)||!app->save_settings()){failure=app?app->failure:"Game records unavailable";return -1;}
 // Rebuild existing title animations/cursor so a previously disabled Extra
 // entry becomes selectable immediately after the settings sheet closes.
 if(app->title&&!app->begin_title(0)){failure=app->failure;return -1;}
 return 1;
}
#if TH15_DIAGNOSTICS
bool sdl_test_stage(int stage,int character){
 if(!app||stage<1||stage>7||character<0||character>3)return false;
 if(!app->begin_title(0))return false;
 app->progress={};app->progress.character=character;app->progress.difficulty=stage==7?4:1;app->progress.starting_stage=stage;
 app->selected_stage=stage;app->selection_player={};app->selection_player.mode_flags=stage==7?0:0x100;app->current_destination=13;app->selected_replay.clear();
 sdl_keys_clear();const bool ok=app->begin_run();if(!ok)failure=app->failure;return ok;
}
void sdl_test_protect(){if(app&&app->scene())app->scene()->battle.player->life.invulnerability.set(600);}
bool sdl_test_auto_bomb(){
 if(!app||!app->scene())return false;
 auto& b=app->scene()->battle;auto& p=*b.player;auto& c=p.frame.collision;
 auto prepare=[&](bool enabled,int bombs){b.automatic_bombs=enabled;p.life.state=1;p.life.invulnerability.set(0);b.session.bombs=bombs;b.session.bomb_state=0;c.state=1;c.invulnerability=0;c.bomb_active=false;};
 prepare(true,3);const int lives=b.session.extra_lives;
 c.circle(c.position,1,false,&p);
 if(!p.error.empty()||p.life.state!=1||b.session.bombs!=2||b.session.bomb_state!=1||p.life.invulnerability.current<=0||b.session.extra_lives!=lives){failure="Auto Bomb collision did not activate original character Bomb";return false;}
 b.player_collision().circle(c.position,1,false,&p);
 if(p.life.state!=1||b.session.bombs!=2){failure="Auto Bomb repeated during live protection query";return false;}
 prepare(false,3);c.circle(c.position,1,false,&p);
 if(!p.error.empty()||p.life.state!=4||b.session.bombs!=3){failure="Disabled Auto Bomb changed ordinary hit";return false;}
 prepare(true,0);c.circle(c.position,1,false,&p);
 if(!p.error.empty()||p.life.state!=4||b.session.bombs!=0){failure="Empty Bomb stock changed ordinary hit";return false;}
 return true;
}
bool sdl_test_reisen_drag(){
 automatic_bombs=developer_invincible=false;
 for(bool unlimited:{false,true}){
  if(!sdl_test_stage(1,3))return false;
  auto& b=app->scene()->battle;auto& p=*b.player;
  gestures.enabled=true;gestures.mode=0;gestures.unlimited=unlimited;gestures.sensitivity=1;
  gestures.double_tap=gestures.two_finger=false;gestures.controls(false,false,0,0,0,0);
  for(int i=0;i<180;i++){p.life.invulnerability.set(600);if(!tick())return false;}
  b.session.bombs=3;
  if(!b.bomb->begin()){failure=b.bomb->error;return false;}
  auto& shield=static_cast<BombReisen&>(*b.bomb);
  float finger=.30f;gestures.pointer(0,701,finger,.6f,0,state(),false);
  if(!gestures.active()){failure="Shield check could not begin drag";return false;}
  for(int charge=3;charge>0;--charge){
   for(int i=0;i<32;i++){p.life.invulnerability.set(600);if(!tick())return false;}
   p.life.invulnerability.set(0);auto& c=p.frame.collision;c.state=1;c.invulnerability=0;c.bomb_active=false;
   c.circle(c.position,1,false,&p);
   if(p.life.state!=4){failure="Shield collision did not enter pending hit";return false;}
   finger+=.005f;gestures.pointer(1,701,finger,.6f,1,state(),false);
   if(!tick()||p.life.state!=1||shield.charges!=charge-1||!gestures.active()){
    failure="Reisen shield recovery discarded the captured drag";return false;
   }
   const float before=p.motion.position.x;finger+=.015f;
   gestures.pointer(1,701,finger,.6f,2,state(),false);
   if(!tick()||p.motion.position.x<=before||p.motion.touch.mode!=(unlimited?2:1)){
    failure="Held finger did not move Reisen after shield recovery";return false;
   }
  }
  gestures.pointer(2,701,finger,.6f,3,state(),false);
  if(gestures.active()){failure="Recovered drag did not release";return false;}
  std::printf("REISEN DRAG PASS: %s, three real shield collisions, same finger resumes, release\n",unlimited?"unlimited":"limited");std::fflush(stdout);
 }
 return true;
}
void sdl_test_key(unsigned key,bool held){if(key<256)keys[key]=held;}
const char* sdl_test_state(){
 static char text[1024];const auto* p=sdl_game_status();const auto* battle=app&&app->scene()?&app->scene()->battle:nullptr;
 std::snprintf(text,sizeof text,"scene=%d screen=%d sub=%d cursor=%d music=%d binding=%d stageFrame=%d dev=%d invincible=%d score=%d power=%d lives=%d bombs=%d musicMask=%u extra=%d autoBomb=%d context=%d pause=%d ",p[0],p[8],p[9],p[10],app?app->volumes.music_volume:0,app?app->controller.values[0]:-1,p[5],developer_enabled,developer_invincible,battle?battle->score.score:0,battle?battle->session.power:0,battle?battle->session.extra_lives:0,battle?battle->session.bombs:0,app?app->records.music_mask():0,app&&app->records.title_records().extra_available(),automatic_bombs,state().context,p[14]);
 if(app){const auto& r=app->graphics.backend.displayRect;const auto& c=app->graphics.backend.sourceRect;
  std::snprintf(text+std::strlen(text),sizeof(text)-std::strlen(text),"viewX=%.3f viewY=%.3f viewW=%.3f viewH=%.3f sourceW=%.0f sourceH=%.0f playerX=%.3f playerY=%.3f dragActive=%d ready=%d pointerEvents=%u pointerDowns=%u ",r[0]*display_width,r[1]*display_height,r[2]*display_width,r[3]*display_height,c[2],c[3],battle?battle->player->motion.position.x:0,battle?battle->player->motion.position.y:0,gestures.active(),state().ready,test_pointer_events,test_pointer_downs);}
 return text;
}
#endif
