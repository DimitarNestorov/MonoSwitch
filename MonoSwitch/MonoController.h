#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@interface MonoController : NSControl

@property (getter=isPlayStereoAsMonoEnabled) BOOL playStereoAsMonoEnabled;

- (BOOL)isPlayStereoAsMonoSupported;

- (IBAction)togglePlayStereoAsMonoEnabled:(id)sender;

@end

NS_ASSUME_NONNULL_END
