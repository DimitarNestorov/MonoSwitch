#import <AudioToolbox/AudioServices.h>

#import "MonoController.h"

UInt32 MixStereoToMonoSize = 4;

AudioObjectPropertyAddress mixStereoToMonoAddressFactory() {
    AudioObjectPropertyAddress mixStereoToMonoAddress;

    mixStereoToMonoAddress.mElement = kAudioObjectPropertyElementMaster;
    mixStereoToMonoAddress.mScope = kAudioDevicePropertyScopeOutput;
    mixStereoToMonoAddress.mSelector = kAudioHardwarePropertyMixStereoToMono;
    return mixStereoToMonoAddress;
}

NSString *SoundSettingsDidChangeNotification = @"UniversalAccessDomainSoundSettingsDidChangeNotification";

@interface MonoController ()

@property AudioObjectPropertyAddress mixStereoToMonoAddress;

@end


@implementation MonoController

- (instancetype)init {
    self = [super init];
    if (self) {
        self.mixStereoToMonoAddress = mixStereoToMonoAddressFactory();
        [NSDistributedNotificationCenter.defaultCenter addObserver:self selector:@selector(receiveNotification:) name:SoundSettingsDidChangeNotification object:nil];
    }
    return self;
}

- (void)dealloc {
    [NSDistributedNotificationCenter.defaultCenter removeObserver:self name:SoundSettingsDidChangeNotification object:nil];
}

- (void)receiveNotification:(NSNotification *)notification {
    [self sendAction:self.action to:self.target];
}

- (BOOL)isPlayStereoAsMonoSupported {
    AudioObjectPropertyAddress mixStereoToMonoAddress = self.mixStereoToMonoAddress;
    return AudioObjectHasProperty(1, &mixStereoToMonoAddress);
}

- (BOOL)isPlayStereoAsMonoEnabled {
    if (![self isPlayStereoAsMonoSupported]) return NO;
    
    AudioObjectPropertyAddress mixStereoToMonoAddress = self.mixStereoToMonoAddress;
    UInt32 result = 0;
    OSStatus status = AudioObjectGetPropertyData(1, &mixStereoToMonoAddress, 0, nil, &MixStereoToMonoSize, &result);
    if (status == 0) {
        return result;
    } else {
        // TODO: Sentry
        NSLog(@"Bad OSStatus %d", status);
    }

    return NO;
}

- (void)setPlayStereoAsMonoEnabled:(BOOL)isEnabled {
    if (![self isPlayStereoAsMonoSupported]) return;
    AudioObjectPropertyAddress mixStereoToMonoAddress = self.mixStereoToMonoAddress;
    int newData = isEnabled ? 1 : 0;
    OSStatus status = AudioObjectSetPropertyData(1, &mixStereoToMonoAddress, 0, nil, MixStereoToMonoSize, &newData);
    if (status == 0) {
#ifndef SANDBOX
        [NSDistributedNotificationCenter.defaultCenter postNotificationName:SoundSettingsDidChangeNotification object:nil userInfo:@{@"stereoAsMono": [NSNumber numberWithBool:isEnabled]}];
#else
        [self sendAction:self.action to:self.target];
#endif
    } else {
        // TODO: Sentry
        NSLog(@"Bad OSStatus %d", status);
    }
}

- (IBAction)togglePlayStereoAsMonoEnabled:(id)sender {
    [self setPlayStereoAsMonoEnabled:!self.isPlayStereoAsMonoEnabled];
}

@end
