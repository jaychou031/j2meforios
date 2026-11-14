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
- (void)setAudioAvailable:(BOOL)available;
- (void)setVolume:(float)volume;
- (void)setFrameRate:(NSInteger)frameRate;
- (void)setFrameReadyHandler:(void (^)(void))handler;
- (void)setAudioCapture:(BOOL)enabled;
- (UIImage *)takeFrameWithIdle:(BOOL *)idle;
- (NSUInteger)frameCount;
- (NSString *)logText;
@end
