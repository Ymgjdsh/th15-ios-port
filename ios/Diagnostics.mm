#import "Diagnostics.hpp"
#import "Preferences.hpp"
#include "NativeHost.hpp"
static NSMutableString* th15Log;
static NSString* th15State;
static NSString* th15LogPath(){NSArray* dirs=NSSearchPathForDirectoriesInDomains(NSLibraryDirectory,NSUserDomainMask,YES);NSString* dir=[dirs.firstObject stringByAppendingPathComponent:@"TH15"];[[NSFileManager defaultManager]createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:nil error:nil];return [dir stringByAppendingPathComponent:@"current.log"];}
namespace touhou::ios {
void diagnosticsStart(){th15Log=[NSMutableString string];diagnostic(@"TH15 iOS start %@ %@",UIDevice.currentDevice.systemName,UIDevice.currentDevice.systemVersion);}
void diagnostic(NSString* format,...){if(!th15Log)return;va_list args;va_start(args,format);NSString* line=[[NSString alloc]initWithFormat:format arguments:args];va_end(args);[th15Log appendFormat:@"%@\n",line];if(th15Log.length>150000)[th15Log deleteCharactersInRange:NSMakeRange(0,50000)];}
void diagnosticsState(NSString* state){th15State=state;diagnostic(@"state=%@",state);}
void diagnosticsFrame(double t,double work,std::uint64_t n){if(n%300==0){diagnostic(@"frame=%llu work_ms=%.3f state=%@",n,work*1000.,th15State?:@"running");diagnosticsFlush();}}
void diagnosticsFlush(){[th15Log writeToFile:th15LogPath() atomically:YES encoding:NSUTF8StringEncoding error:nil];}
}
// SDL's UIKit backend observes text changes with object:nil. Its handler starts
// the hidden SDL text field even for a native alert, stealing focus after the
// first character. Suspend only this window controller's keyboard observers
// while our native sheet owns input, then restore them after dismissal.
@interface TH15SDLKeyboardGuard:NSObject
@property(nonatomic,weak) UIViewController* owner;
@property(nonatomic,copy) NSArray<NSString*>* suspendedNames;
- (instancetype)initWithOwner:(UIViewController*)owner;
- (void)restore;
@end
@implementation TH15SDLKeyboardGuard
- (NSDictionary<NSString*,NSString*>*)selectors{return @{UITextFieldTextDidChangeNotification:@"textFieldTextDidChange:",UIKeyboardWillShowNotification:@"keyboardWillShow:",UIKeyboardWillHideNotification:@"keyboardWillHide:",UIKeyboardDidHideNotification:@"keyboardDidHide:"};}
- (instancetype)initWithOwner:(UIViewController*)owner{
 if((self=[super init])){self.owner=owner;NSMutableArray* names=[NSMutableArray array];NSDictionary* selectors=[self selectors];for(NSString* name in selectors){if([owner respondsToSelector:NSSelectorFromString(selectors[name])]){[NSNotificationCenter.defaultCenter removeObserver:owner name:name object:nil];[names addObject:name];}}self.suspendedNames=names;}return self;
}
- (void)restore{NSDictionary* selectors=[self selectors];for(NSString* name in self.suspendedNames)if(self.owner)[NSNotificationCenter.defaultCenter addObserver:self.owner selector:NSSelectorFromString(selectors[name]) name:name object:nil];self.suspendedNames=nil;}
- (void)dealloc{[self restore];}
@end
@interface TH15SettingsController:UITableViewController
@property(nonatomic,copy) void(^finished)(void);
@property(nonatomic,strong) TH15SDLKeyboardGuard* keyboardGuard;
@property(nonatomic,copy) void(^editLayout)(void);
@end
@implementation TH15SettingsController
- (instancetype)initWithFinished:(void(^)(void))finished{if((self=[super initWithStyle:UITableViewStyleInsetGrouped]))_finished=[finished copy];return self;}
- (void)viewDidLoad{[super viewDidLoad];self.title=@"设置";self.navigationItem.leftBarButtonItem=[[UIBarButtonItem alloc]initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(done)];self.navigationController.presentationController.delegate=(id<UIAdaptivePresentationControllerDelegate>)self;}
- (void)finish{[self.keyboardGuard restore];self.keyboardGuard=nil;if(self.finished){self.finished();self.finished=nil;}}
- (void)done{[self dismissViewControllerAnimated:YES completion:^{[self finish];}];}
- (void)presentationControllerDidDismiss:(UIPresentationController*)controller{[self finish];}
- (NSInteger)numberOfSectionsInTableView:(UITableView*)tv{return 5;}
- (NSInteger)tableView:(UITableView*)tv numberOfRowsInSection:(NSInteger)section{return [[self names][section] count];}
- (NSString*)tableView:(UITableView*)tv titleForHeaderInSection:(NSInteger)section{return @[@"操作",@"触摸与手势",@"显示",@"开发者与解锁",@"帮助与诊断"][section];}
- (NSArray*)names{return @[@[@"movement",@"autoFire",@"autoSlow",@"deadZone",@"dragLimited",@"autoBomb",@"toggleFire",@"toggleSlow",@"hidden",@"layout"],@[@"opacity",@"size",@"sensitivity",@"doubleTapBomb",@"twoFingerSlow"],@[@"smooth",@"portraitZoom"],@[@"developer",@"unlockCode"],@[@"help",@"reset"]];}
- (NSArray*)labels{return @[@[@"移动方式",@"自动射击",@"自动低速",@"摇杆死区",@"拖拽限速",@"Auto Bomb / 自动灵击",@"Z Toggle / 点击保持射击",@"S Toggle / 点击保持低速",@"No Button / 隐藏操作按键",@"自由调整操作布局"],@[@"按键透明度",@"按键大小",@"移动灵敏度",@"双击灵击",@"双指低速"],@[@"平滑缩放",@"竖屏战斗全屏"],@[@"开发者功能",@"输入作弊码解锁全部内容"],@[@"操作说明与日志",@"恢复默认设置"]];}
- (UITableViewCell*)tableView:(UITableView*)tv cellForRowAtIndexPath:(NSIndexPath*)p{
 using namespace touhou::ios;UITableViewCell* c=[[UITableViewCell alloc]initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:nil];NSString* n=[self names][p.section][p.row];c.textLabel.text=[self labels][p.section][p.row];
 if([n isEqualToString:@"movement"]){UISegmentedControl* s=[[UISegmentedControl alloc]initWithItems:@[@"拖动+摇杆",@"摇杆"]];s.selectedSegmentIndex=preference(n)>1?1:0;s.accessibilityIdentifier=n;[s addTarget:self action:@selector(changed:) forControlEvents:UIControlEventValueChanged];c.accessoryView=s;}
 else if([@[@"autoFire",@"autoSlow",@"autoBomb",@"toggleFire",@"toggleSlow",@"hidden",@"doubleTapBomb",@"twoFingerSlow",@"smooth",@"portraitZoom",@"dragLimited",@"developer"] containsObject:n]){UISwitch* s=[UISwitch new];s.on=preference(n)!=0;s.accessibilityIdentifier=n;[s addTarget:self action:@selector(changed:) forControlEvents:UIControlEventValueChanged];c.accessoryView=s;if([n isEqualToString:@"dragLimited"])c.detailTextLabel.text=@"开启：原版速度；关闭：角色立即跟随拖动";if([n isEqualToString:@"developer"])c.detailTextLabel.text=@"开启后，战斗中显示 DEV 悬浮按钮";if([n isEqualToString:@"autoBomb"])c.detailTextLabel.text=@"碰撞时在死亡效果前释放，消耗 1 个灵击；无库存则正常受击";if([n isEqualToString:@"toggleFire"]||[n isEqualToString:@"toggleSlow"])c.detailTextLabel.text=@"战斗中点击保持，再点一次关闭；菜单仍是普通按键";if([n isEqualToString:@"hidden"])c.detailTextLabel.text=@"战斗中隐藏摇杆和 Z/X/S；菜单仍显示按键";}
 else if([@[@"opacity",@"size",@"sensitivity",@"deadZone"] containsObject:n]){UISlider* s=[[UISlider alloc]initWithFrame:CGRectMake(0,0,140,30)];s.minimumValue=[n isEqualToString:@"deadZone"]?0:[n isEqualToString:@"opacity"]?.2:.5;s.maximumValue=[n isEqualToString:@"deadZone"]?.5:[n isEqualToString:@"opacity"]?1:2;s.value=preference(n);s.accessibilityIdentifier=n;[s addTarget:self action:@selector(changed:) forControlEvents:UIControlEventValueChanged];c.detailTextLabel.text=[NSString stringWithFormat:@"%.2f",s.value];c.accessoryView=s;}
 else {c.accessoryType=UITableViewCellAccessoryDisclosureIndicator;c.accessibilityIdentifier=n;if([n isEqualToString:@"layout"])c.detailTextLabel.text=@"拖动摇杆和按钮；横屏、竖屏分别保存，可重置或取消";}return c;
}
- (void)changed:(UIControl*)control{using namespace touhou::ios;NSString* n=control.accessibilityIdentifier;id value;if([control isKindOfClass:UISwitch.class])value=@(((UISwitch*)control).on);else if([control isKindOfClass:UISegmentedControl.class])value=@(((UISegmentedControl*)control).selectedSegmentIndex?3:0);else value=@(((UISlider*)control).value);setPreference(n,value);if([control isKindOfClass:UISlider.class]){UIView* parent=control;while(parent&&![parent isKindOfClass:UITableViewCell.class])parent=parent.superview;if(parent)((UITableViewCell*)parent).detailTextLabel.text=[NSString stringWithFormat:@"%.2f",[(NSNumber*)value doubleValue]];}diagnostic(@"preference %@=%@",n,value);}
- (void)tableView:(UITableView*)tv didSelectRowAtIndexPath:(NSIndexPath*)p{
 [tv deselectRowAtIndexPath:p animated:YES];
 if([[[self names][p.section] objectAtIndex:p.row] isEqualToString:@"layout"]){void(^edit)(void)=self.editLayout;[self dismissViewControllerAnimated:YES completion:^{[self.keyboardGuard restore];self.keyboardGuard=nil;self.finished=nil;if(edit)edit();}];return;}
 if(p.section==3&&p.row==1){
  UIAlertController* dialog=[UIAlertController alertControllerWithTitle:@"输入作弊码" message:@"确认后解锁 Extra、练习关卡、符卡记录和全部音乐，并保存到游戏记录。" preferredStyle:UIAlertControllerStyleAlert];
  [dialog addTextFieldWithConfigurationHandler:^(UITextField* field){field.placeholder=@"作弊码";field.accessibilityIdentifier=@"th15.unlock.input";field.autocapitalizationType=UITextAutocapitalizationTypeNone;field.autocorrectionType=UITextAutocorrectionTypeNo;field.keyboardType=UIKeyboardTypeASCIICapable;}];
  [dialog addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
  [dialog addAction:[UIAlertAction actionWithTitle:@"确认解锁" style:UIAlertActionStyleDefault handler:^(UIAlertAction*){
   NSString* code=[[dialog.textFields.firstObject.text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet] lowercaseString];
   int result=sdl_unlock_code(code.UTF8String);touhou::ios::diagnostic(@"Full unlock result=%d",result);touhou::ios::diagnosticsFlush();
   UIAlertController* message=[UIAlertController alertControllerWithTitle:result==1?@"解锁成功":result==0?@"作弊码不正确":@"保存失败" message:result==1?@"所有内容已解锁并保存，重新启动后仍然有效。":result==0?@"请检查输入的作弊码后再试。":[NSString stringWithUTF8String:sdl_file_error()] preferredStyle:UIAlertControllerStyleAlert];
   [message addAction:[UIAlertAction actionWithTitle:@"好" style:UIAlertActionStyleDefault handler:nil]];[self presentViewController:message animated:YES completion:nil];
  }]];[self presentViewController:dialog animated:YES completion:nil];return;
 }
 if(p.section!=4)return;
 if(p.row==1){touhou::ios::resetPreferences();[tv reloadData];return;}
 UIAlertController* a=[UIAlertController alertControllerWithTitle:@"东方绀珠传" message:@"Z：射击／确认\nX：灵击／取消\nS：低速\n拖动画面或左下摇杆移动\n双击画面灵击，双指按住低速\n菜单可滑动选择、轻点确认、双指轻点返回\n四指触摸暂停\n竖屏默认将原版积分板放在顶部，战斗区铺满下方，按键悬浮显示\n游戏内 Option 可调音乐与音效音量。\n\niOS 14+ 原生重建版。日志保存在应用 Library/TH15/current.log。" preferredStyle:UIAlertControllerStyleAlert];
 [a addAction:[UIAlertAction actionWithTitle:@"分享日志" style:UIAlertActionStyleDefault handler:^(UIAlertAction* action){touhou::ios::diagnosticsFlush();UIActivityViewController* share=[[UIActivityViewController alloc]initWithActivityItems:@[[NSURL fileURLWithPath:th15LogPath()]] applicationActivities:nil];share.popoverPresentationController.sourceView=self.view;share.popoverPresentationController.sourceRect=CGRectMake(self.view.bounds.size.width/2,self.view.bounds.size.height/2,1,1);[self presentViewController:share animated:YES completion:nil];}]];[a addAction:[UIAlertAction actionWithTitle:@"关闭" style:UIAlertActionStyleCancel handler:nil]];[self presentViewController:a animated:YES completion:nil];
}
@end
@interface TH15DeveloperController:UITableViewController
@property(nonatomic,copy) void(^finished)(void);
@property(nonatomic) NSInteger lastAction;
@end
@implementation TH15DeveloperController
- (instancetype)initWithFinished:(void(^)(void))finished{if((self=[super initWithStyle:UITableViewStyleInsetGrouped])){_finished=[finished copy];_lastAction=-1;}return self;}
- (void)viewDidLoad{[super viewDidLoad];self.title=@"开发者功能";self.navigationItem.leftBarButtonItem=[[UIBarButtonItem alloc]initWithTitle:@"返回游戏" style:UIBarButtonItemStyleDone target:self action:@selector(done)];}
- (void)done{[self dismissViewControllerAnimated:YES completion:^{if(self.finished){self.finished();self.finished=nil;}}];}
- (NSInteger)tableView:(UITableView*)tv numberOfRowsInSection:(NSInteger)section{return 7;}
- (UITableViewCell*)tableView:(UITableView*)tv cellForRowAtIndexPath:(NSIndexPath*)p{
 UITableViewCell* cell=[[UITableViewCell alloc]initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:nil];
 cell.textLabel.text=@[@"无敌",@"最大分数",@"最大道具",@"满火力",@"补满残机与灵击",@"一键最大化",@"清除弹幕"][p.row];
 cell.detailTextLabel.text=@[@"开启后持续防止碰撞伤害",@"分数设为 999,999,999",@"增加擦弹与得点道具，得点值补满",@"补满当前角色火力",@"残机与灵击各补至 8",@"同时补满分数、道具、火力与库存",@"清除当前子弹与激光"][p.row];
 if(p.row==0){UISwitch* toggle=[UISwitch new];toggle.on=sdl_developer_invincible();toggle.accessibilityIdentifier=@"th15.dev.invincible";[toggle addTarget:self action:@selector(invincible:) forControlEvents:UIControlEventValueChanged];cell.accessoryView=toggle;}
 else {cell.accessibilityIdentifier=[NSString stringWithFormat:@"th15.dev.action.%ld",(long)p.row];cell.accessoryType=self.lastAction==p.row?UITableViewCellAccessoryCheckmark:UITableViewCellAccessoryNone;}
 return cell;
}
- (void)apply:(NSInteger)action{BOOL ok=sdl_developer_action(int(action));touhou::ios::diagnostic(@"Developer action=%ld success=%d invincible=%d",(long)action,ok,sdl_developer_invincible());touhou::ios::diagnosticsFlush();if(ok){self.lastAction=action;[self.tableView reloadData];}else{UIAlertController* alert=[UIAlertController alertControllerWithTitle:@"操作未完成" message:[NSString stringWithUTF8String:sdl_file_error()] preferredStyle:UIAlertControllerStyleAlert];[alert addAction:[UIAlertAction actionWithTitle:@"好" style:UIAlertActionStyleDefault handler:nil]];[self presentViewController:alert animated:YES completion:nil];}}
- (void)invincible:(UISwitch*)toggle{[self apply:0];}
- (void)tableView:(UITableView*)tv didSelectRowAtIndexPath:(NSIndexPath*)p{[tv deselectRowAtIndexPath:p animated:YES];if(p.row)[self apply:p.row];}
@end
namespace touhou::ios {
void presentSettings(UIViewController* presenter,UIView* anchor,void(^finished)(void),void(^edit)(void)){TH15SettingsController* settings=[[TH15SettingsController alloc]initWithFinished:finished];settings.editLayout=edit;settings.keyboardGuard=[[TH15SDLKeyboardGuard alloc]initWithOwner:presenter];UINavigationController* nav=[[UINavigationController alloc]initWithRootViewController:settings];nav.modalPresentationStyle=UIModalPresentationPageSheet;nav.modalInPresentation=YES;[presenter presentViewController:nav animated:YES completion:nil];}
void presentDeveloper(UIViewController* presenter,void(^finished)(void)){TH15DeveloperController* developer=[[TH15DeveloperController alloc]initWithFinished:finished];UINavigationController* nav=[[UINavigationController alloc]initWithRootViewController:developer];nav.modalPresentationStyle=UIModalPresentationPageSheet;nav.modalInPresentation=YES;[presenter presentViewController:nav animated:YES completion:nil];}
}
