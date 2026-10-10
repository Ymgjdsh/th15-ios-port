#pragma once
#import <Foundation/Foundation.h>
namespace touhou::ios {
inline NSDictionary* defaults(){return @{ @"movement":@0, @"opacity":@0.62, @"size":@1.0, @"sensitivity":@1.0, @"deadZone":@0.16, @"dragLimited":@YES, @"developer":@NO, @"autoFire":@NO, @"autoSlow":@NO, @"autoBomb":@NO, @"toggleFire":@NO, @"toggleSlow":@NO, @"hidden":@NO, @"doubleTapBomb":@YES, @"twoFingerSlow":@YES, @"smooth":@YES, @"portraitZoom":@YES };}
inline NSString* key(NSString* name){return [@"TH15." stringByAppendingString:name];}
inline double preference(NSString* name){id value=[NSUserDefaults.standardUserDefaults objectForKey:key(name)];return [(value?:defaults()[name]) doubleValue];}
inline void setPreference(NSString* name,id value){[NSUserDefaults.standardUserDefaults setObject:value forKey:key(name)];}
inline void resetPreferences(){for(NSString* name in NSUserDefaults.standardUserDefaults.dictionaryRepresentation)if([name hasPrefix:@"TH15."]) [NSUserDefaults.standardUserDefaults removeObjectForKey:name];}
}
