#pragma once
#import <UIKit/UIKit.h>
#include <cstdint>
namespace touhou::ios {
void diagnosticsStart(); void diagnostic(NSString* format,...); void diagnosticsFlush(); void diagnosticsState(NSString*); void diagnosticsFrame(double,double,std::uint64_t);
void presentSettings(UIViewController*,UIView*,void(^)(void),void(^)(void));
void presentDeveloper(UIViewController*,void(^)(void));
}
