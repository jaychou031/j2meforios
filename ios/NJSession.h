#import <UIKit/UIKit.h>
#include "nj2me/nj_port.h"
@interface NJSession : NSObject
@property(nonatomic,readonly) int width;
@property(nonatomic,readonly) int height;
- (instancetype)initWithWidth:(int)width height:(int)height;
- (void)startJar:(NSString *)path saveID:(NSString *)saveID completion:(void (^)(int))completion;
- (void)sendEvent:(nj_event)event;
- (void)stop;
- (void)setPaused:(BOOL)paused;
- (void)setVolume:(float)volume;
- (UIImage *)takeFrame;
- (NSUInteger)frameCount;
- (NSString *)logText;
@end
