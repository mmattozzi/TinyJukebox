//
//  JukeboxPrefWindow.m
//  TinyJukebox
//
//  Created by Michael Mattozzi on 6/26/11.
//  Copyright 2011 Michael Mattozzi. All rights reserved.
//

#import "JukeboxPrefWindow.h"
#import "JukeboxData.h"
#import "JukeboxConfig.h"
#import "TinyJukeboxAppDelegate.h"

@implementation JukeboxPrefWindow

@synthesize generalPreferencesView;
@synthesize serversPreferencesView;
@synthesize licenseView;

@synthesize license;
@synthesize thirdPartyLicense;
@synthesize serversTableView;
@synthesize addServerPanel;
@synthesize serverName;
@synthesize localDirectory;
@synthesize shareFiles;
@synthesize port;
@synthesize allowRemoteControl;
@synthesize hostname;

- (void)setupToolbar {
	[self addView:generalPreferencesView label:@"General" image:[NSImage imageNamed: NSImageNamePreferencesGeneral]];
	[self addView:serversPreferencesView label:@"Servers" image:[NSImage imageNamed: NSImageNameNetwork]];
    [self addView:licenseView label:@"License" image:[NSImage imageNamed: NSImageNameInfo]];
	
    // Optional configuration settings.
	[self setCrossFade:YES];
	[self setShiftSlowsAnimation:YES];
}

- (void)displayViewForIdentifier:(NSString *)identifier animate:(BOOL)animate {
    [super displayViewForIdentifier:identifier animate:animate];
    
    if ([identifier isEqualToString:@"License"]) {
        if ([license string] == nil || [[license string] isEqualToString:@""]) {
            [license setString:[NSString stringWithContentsOfFile:[[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:@"LICENSE.txt"] encoding:NSUTF8StringEncoding error:nil]];
        }
        
        if ([thirdPartyLicense string] == nil || [[thirdPartyLicense string] isEqualToString:@""]) {
            [thirdPartyLicense setString:[NSString stringWithContentsOfFile:[[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:@"THIRDPARTY-LICENSES.txt"] encoding:NSUTF8StringEncoding error:nil]];
        }
    } else if ([identifier isEqualToString:@"General"]) {
        [self loadConfigIntoGeneralView];
    }
}

- (void) loadConfigIntoGeneralView {
    JukeboxConfig *config = [[JukeboxData singleton] getConfig];
    [localDirectory setStringValue:config.localLibraryDirectory];
    [port setStringValue:[NSString stringWithFormat:@"%d", config.port]];
    if (config.allowRemoteControl) {
        [allowRemoteControl setState:NSOnState];
    } else {
        [allowRemoteControl setState:NSOffState];
    }
    if (config.shareFiles) {
        [shareFiles setState:NSOnState];
    } else {
        [shareFiles setState:NSOffState];
    }
    [hostname setStringValue:config.hostname];
}

#pragma mark Table view methods
- (NSInteger) numberOfRowsInTableView:(NSTableView *) tableView {
	NSInteger count;
	
	if(tableView == serversTableView)
		count = [[JukeboxData singleton] getServerCount];
	
	return count;
	
}

- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
	
	id object;
	
	if(tableView == serversTableView)
		object = [[JukeboxData singleton] getServerValueForColumn:[tableColumn identifier] row:row];
	
	return object;
}

- (IBAction) addServer:(id)sender {
    [NSApp beginSheet:addServerPanel modalForWindow:[self window]
        modalDelegate:self didEndSelector:NULL contextInfo:nil];
}

- (IBAction) doneSaveRequest:(id)sender {
	if ([sender isKindOfClass:[NSTextField class]] || ! [[sender title] isEqualToString:@"Cancel"]) {
		[[JukeboxData singleton] addServerUrl:[serverName stringValue] withType:@"Manual"];
	}
	[addServerPanel orderOut:nil];
    [NSApp endSheet:addServerPanel];
    [serversTableView reloadData];
}

- (void) deleteServer:(id)sender {
    [[JukeboxData singleton] deleteServerForRow:[serversTableView selectedRow]];
    [serversTableView reloadData];
}

- (IBAction) selectDirectory:(id)sender {
    NSOpenPanel* openDlg = [NSOpenPanel openPanel];
    [openDlg setCanChooseFiles:NO];
    [openDlg setCanChooseDirectories:YES];
    [openDlg setAllowsMultipleSelection:NO];
    
    if ( [openDlg runModalForDirectory:nil file:nil] == NSOKButton ) {
        [localDirectory setStringValue:[openDlg filename]];
    }
}

- (IBAction) saveChanges:(id)sender {
    JukeboxConfig *config = [[[JukeboxConfig alloc] initWithDirectory:[localDirectory stringValue] 
                                                                 port:[port intValue] 
                                                   allowRemoteControl:[allowRemoteControl state]  
                                                           shareFiles:[shareFiles state]
                                                             hostname:[hostname stringValue]] autorelease];
    [[JukeboxData singleton] saveConfig:config];
    [[TinyJukeboxAppDelegate singleton] reloadServer];
    
    // Remove all local songs, the urls could be wrong!
    [[TinyJukeboxAppDelegate singleton] rescan:nil];
}

- (IBAction) forgetChanges:(id)sender {
    [self loadConfigIntoGeneralView];
}

@end
