#import <MASShortcut/Shortcut.h>
#import <DNLoginServiceKit/DNLoginServiceKit.h>

#import "AppDelegate.h"
#import "AppDelegate+StoreKit.h"
#import "MonoController.h"

static NSString *const kPreferenceStatusItemImages = @"StatusItemImages";
static NSString *const kPreferenceDefaultStatusItemImages = @"Speakers";
static NSString *const kPreferenceGlobalShortcut = @"GlobalShortcut";

void *kGlobalShortcutContext = &kGlobalShortcutContext;

@interface AppDelegate ()

@property (unsafe_unretained) IBOutlet NSPanel *preferencesPanel;

@property (unsafe_unretained) IBOutlet NSMenu *statusItemMenu;

@property (unsafe_unretained) IBOutlet NSMenuItem *toggleMonoMenuItem;

@property (unsafe_unretained) IBOutlet MonoController *monoController;

@property (unsafe_unretained) IBOutlet MASShortcutView *shortcutView;

@property (unsafe_unretained) IBOutlet NSButton *launchAtLoginButton;

@property (unsafe_unretained) IBOutlet NSPopUpButton *iconPopUpButton;

@property (unsafe_unretained) IBOutlet NSTextField *licenseLabel;

@property (strong) NSStatusItem *statusItem;

@property (strong) NSString *observableKeyPath;

@property (strong) NSImage *monoStatusItemImage;
@property (strong) NSImage *stereoStatusItemImage;

@end

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)notification {
    NSUserDefaults *userDefaults = NSUserDefaultsController.sharedUserDefaultsController.defaults;
    [userDefaults registerDefaults:@{ kPreferenceStatusItemImages: kPreferenceDefaultStatusItemImages }];
    NSString *setName = [userDefaults stringForKey:kPreferenceStatusItemImages];
    [self loadStatusItemImages:setName];
    [self.iconPopUpButton selectItemWithTitle:setName];
    
    [self.preferencesPanel center];
    
    NSStatusBar *statusBar = [NSStatusBar systemStatusBar];
    self.statusItem = [statusBar statusItemWithLength:NSSquareStatusItemLength];
    [self.statusItem setToolTip:@"MonoSwitch"];
    
    self.statusItem.action = @selector(statusItemButtonAction:);
    [self.statusItem sendActionOn:(NSEventMaskLeftMouseUp | NSEventMaskRightMouseUp)];
    
    self.preferencesPanel.level = NSFloatingWindowLevel;
    
    self.toggleMonoMenuItem.enabled = self.monoController.isPlayStereoAsMonoSupported;
    [self updateStatusItem:self];
    
    self.statusItemMenu.delegate = self;
    
    [[MASShortcutBinder sharedBinder] setBindingOptions:@{NSValueTransformerNameBindingOption:MASDictionaryTransformerName}];
    [self.shortcutView setAssociatedUserDefaultsKey:kPreferenceGlobalShortcut withTransformerName:MASDictionaryTransformerName];

    self.observableKeyPath = [@"values." stringByAppendingString:kPreferenceGlobalShortcut];
    [NSUserDefaultsController.sharedUserDefaultsController addObserver:self
                                                            forKeyPath:self.observableKeyPath
                                                               options:NSKeyValueObservingOptionInitial
                                                               context:kGlobalShortcutContext];
    
    self.shortcutView.style = MASShortcutViewStyleRegularSquare;
    
    [self bindShortcut];
    
    [self initStoreKit];
    
    self.launchAtLoginButton.state = DNLoginServiceKit.loginItemExists ? NSControlStateValueOn : NSControlStateValueOff;
    
    
    NSMutableAttributedString *licenseString = [[NSMutableAttributedString alloc] initWithString:@"Licensed under the European Union Public Licence (EUPL) v1.2"];
    if (@available(macOS 10.10, *)) {
        [licenseString addAttribute:NSForegroundColorAttributeName value:NSColor.labelColor range:NSMakeRange(0, 19)];
    }
    [licenseString addAttribute:NSLinkAttributeName value:@"https://github.com/mangizi/MonoSwitch/blob/master/LICENSE" range:NSMakeRange(19, 41)];
    NSMutableParagraphStyle *paragraphStyle = [NSMutableParagraphStyle new];
    paragraphStyle.alignment = NSTextAlignmentCenter;
    [licenseString addAttribute:NSParagraphStyleAttributeName value:paragraphStyle range:NSMakeRange(0, licenseString.length)];
    [licenseString addAttribute:NSFontAttributeName value:
     [NSFont labelFontOfSize:NSFont.smallSystemFontSize] range:NSMakeRange(0, licenseString.length)];
    self.licenseLabel.attributedStringValue = licenseString;
}

- (void)menuWillOpen:(NSMenu *)menu {
    [self unbindShortcut];
}

- (void)menuDidClose:(NSMenu *)menu {
    [self bindShortcut];
}

- (void)showUpgradeAlert {
    NSAlert *alert = [NSAlert new];
    alert.messageText = @"Buy Pro Version?";
    alert.informativeText = @"Keyboard shortcut and changing the icon is only available in the pro version";
    [alert addButtonWithTitle:@"Purchase Pro Version"];
    [alert addButtonWithTitle:@"Cancel"];
    
    if (@available(macOS 10.12, *)) {
        alert.alertStyle = NSAlertStyleCritical;
    } else {
        alert.alertStyle = NSCriticalAlertStyle;
    }
    
    [NSApplication.sharedApplication activateIgnoringOtherApps:true];
    NSModalResponse response = [alert runModal];
    
    if (response == NSAlertFirstButtonReturn) {
        [self purchaseProVersion:self];
    }
}

- (void)bindShortcut {
    dispatch_block_t action = ^{
        if (self.proVersionPurchased) {
            [self.monoController togglePlayStereoAsMonoEnabled:self];
        } else {
            [self showUpgradeAlert];
        }
    };
    
    [MASShortcutBinder.sharedBinder bindShortcutWithDefaultsKey:kPreferenceGlobalShortcut
                                                       toAction:action];
}

- (void)unbindShortcut {
    [MASShortcutBinder.sharedBinder breakBindingWithDefaultsKey:kPreferenceGlobalShortcut];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)obj change:(NSDictionary *)change context:(void *)ctx {
    if (ctx == kGlobalShortcutContext) {
        // https://github.com/shpakovski/MASShortcut/issues/117
        MASShortcut *shortcut = [[NSValueTransformer valueTransformerForName:MASDictionaryTransformerName] transformedValue:[NSUserDefaults.standardUserDefaults dictionaryForKey:kPreferenceGlobalShortcut]];
        if (shortcut == nil) {
            [self.toggleMonoMenuItem setKeyEquivalent:@""];
            [self.toggleMonoMenuItem setKeyEquivalentModifierMask:0];
        } else {
            [self.toggleMonoMenuItem setKeyEquivalent:shortcut.keyCodeStringForKeyEquivalent];
            [self.toggleMonoMenuItem setKeyEquivalentModifierMask:shortcut.modifierFlags];
        }
        return;
    }
    
    [super observeValueForKeyPath:keyPath ofObject:obj change:change context:ctx];
}

- (void)applicationWillTerminate:(NSNotification *)aNotification {
    [NSUserDefaultsController.sharedUserDefaultsController removeObserver:self forKeyPath:self.observableKeyPath];
}

- (void)statusItemButtonAction:(id)sender {
    NSEventType type = NSApp.currentEvent.type;
    if (type == NSEventTypeLeftMouseUp) {
        [self.monoController togglePlayStereoAsMonoEnabled:self];
    } else if (type == NSEventTypeRightMouseUp) {
        [self.statusItem popUpStatusItemMenu:self.statusItemMenu];
    }
}

- (IBAction)updateStatusItem:(id)sender {
    BOOL isPlayStereoAsMonoEnabled = self.monoController.playStereoAsMonoEnabled;
    self.toggleMonoMenuItem.state = isPlayStereoAsMonoEnabled ? NSControlStateValueOn : NSControlStateValueOff;
    NSImage *image = isPlayStereoAsMonoEnabled ? self.monoStatusItemImage : self.stereoStatusItemImage;
    
    if (@available(macOS 10.10, *)) {
        self.statusItem.button.image = image;
        [self.statusItem.button setNeedsDisplay:true];
    } else {
        self.statusItem.image = image;
    }
}

- (IBAction)syncLaunchAtLogin:(id)sender {
    if (self.launchAtLoginButton.state == NSControlStateValueOn) {
        [DNLoginServiceKit addLoginItem];
    } else {
        [DNLoginServiceKit removeLoginItem];
    }
}

- (NSDictionary *)map {
    static NSDictionary *map = nil;
    
    if (!map) {
        map = @{
            kPreferenceDefaultStatusItemImages: @[@"One Speaker", @"Two Speakers"],
            @"3.5 mm (0.14 in) Jack": @[@"One Mono 3.5 mm Plug", @"One Stereo 3.5 mm Plug"],
            @"6.35 mm (¼ inch) Jack": @[@"One Mono 6.35 mm Plug", @"One Stereo 6.35 mm Plug"],
            @"6.35 mm (¼ inch) Jacks": @[@"One Mono 6.35 mm Plug", @"Two Mono 6.35 mm Plugs"],
            @"RCA Connectors": @[@"One RCA Connector", @"Two RCA Connectors"],
        };
    }
    
    return map;
}

- (void)loadStatusItemImages:(NSString *)setName {
    NSArray *imageNames = [self.map objectForKey:setName];
    self.monoStatusItemImage = [NSImage imageNamed:[imageNames objectAtIndex:0]];
    self.monoStatusItemImage.template = YES;
    self.stereoStatusItemImage = [NSImage imageNamed:[imageNames objectAtIndex:1]];
    self.stereoStatusItemImage.template = YES;
}

- (IBAction)changeStatusItemIcons:(id)sender {
    if (self.proVersionPurchased) {
        NSString *setName = self.iconPopUpButton.selectedItem.title;
        if ([self.map objectForKey:setName] == nil) {
            @throw [NSError errorWithDomain:@"IconSets" code:1 userInfo:@{ @"message": @"No such icon set in map", @"setName": setName }];
        }
        
        [NSUserDefaultsController.sharedUserDefaultsController.defaults setObject:setName forKey:kPreferenceStatusItemImages];
        [self loadStatusItemImages:setName];
        [self updateStatusItem:self];
        [self.iconPopUpButton selectItemWithTitle:setName];
    } else {
        [self.iconPopUpButton selectItemWithTitle:[NSUserDefaultsController.sharedUserDefaultsController.defaults stringForKey:kPreferenceStatusItemImages]];
        [self showUpgradeAlert];
    }
}

- (IBAction)sourceCodeButtonAction:(NSButton *)sender {
    [NSWorkspace.sharedWorkspace openURL:[NSURL URLWithString:@"https://github.com/mangizi/MonoSwitch"]];
}

- (IBAction)issuesButtonAction:(NSButton *)sender {
    [NSWorkspace.sharedWorkspace openURL:[NSURL URLWithString:@"https://github.com/mangizi/MonoSwitch/issues?q=is%3Aissue+is%3Aopen+sort%3Aupdated-desc"]];
}

- (IBAction)discussionsButtonAction:(NSButton *)sender {
    [NSWorkspace.sharedWorkspace openURL:[NSURL URLWithString:@"https://github.com/mangizi/MonoSwitch/discussions"]];
}

- (IBAction)websiteButtonAction:(NSButton *)sender {
    [NSWorkspace.sharedWorkspace openURL:[NSURL URLWithString:@"https://monoswitch.app/"]];
}

- (IBAction)privacyPolicyButtonAction:(NSButton *)sender {
    [NSWorkspace.sharedWorkspace openURL:[NSURL URLWithString:@"https://monoswitch.app/privacy"]];
}

@end
