//
//  JukeboxPrefWindow.h
//  TinyJukebox
//
//  Created by Michael Mattozzi on 6/26/11.
//  Copyright 2011 Michael Mattozzi. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "DBPrefsWindowController.h"

@interface JukeboxPrefWindow : DBPrefsWindowController {
    NSView *generalPreferencesView;
    NSView *serversPreferencesView;
    NSView *licenseView;
    
    NSTextField *localDirectory;
    NSTextField *port;
    NSButton *allowRemoteControl;
    NSButton *shareFiles;
    NSTextField *hostname;
    
    NSTableView *serversTableView;
    NSTextField *serverName;
    NSPanel *addServerPanel;
    
    NSTextView *license;
    NSTextView *thirdPartyLicense;
}

@property (assign) IBOutlet NSView *generalPreferencesView;
@property (assign) IBOutlet NSView *serversPreferencesView;

@property (assign) IBOutlet NSTextField *localDirectory;
@property (assign) IBOutlet NSTextField *port;
@property (assign) IBOutlet NSButton *allowRemoteControl;
@property (assign) IBOutlet NSButton *shareFiles;
@property (assign) IBOutlet NSTextField *hostname;

@property (assign) IBOutlet NSView *licenseView;
@property (assign) IBOutlet NSTextView *license;
@property (assign) IBOutlet NSTextView *thirdPartyLicense;

@property (assign) IBOutlet NSTableView *serversTableView;
@property (assign) IBOutlet NSTextField *serverName;
@property (assign) IBOutlet NSPanel *addServerPanel;

- (void) loadConfigIntoGeneralView;

- (IBAction) addServer:(id)sender;
- (IBAction) deleteServer:(id)sender;

- (IBAction) selectDirectory:(id)sender;
- (IBAction) saveChanges:(id)sender;
- (IBAction) forgetChanges:(id)sender;

@end
