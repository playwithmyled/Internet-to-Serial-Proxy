//
//  InsekAppDelegate.h
//  Insek
//
//  Created by Kevin Filteau on 2010-05-30.
//  Copyright 2010 Kevin Filteau. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "AMSerialPort.h"
#import "SimpleCocoaServer.h"
#import "BannerView.h"

@interface InsekAppDelegate : NSObject <NSApplicationDelegate> {

    
	// Declare instance variables.
	
	NSWindow *						window;
	
	// UI.
	IBOutlet BannerView *			headerImage;
	IBOutlet NSTextField *			inputTextField;
	IBOutlet NSTextView *			logTextView;
	IBOutlet NSButton *				connectSerialButton;
	IBOutlet NSTextField *			netConStatus;
	
	NSArray *						baudRates;
	IBOutlet NSArrayController *	arrayController;

	// Inbound Internet connection.
	SimpleCocoaServer *				server;

	// Serial connection.
	AMSerialPort *					port;
	int								connectionStatus;
	NSMutableData *					serialBuffer;
	NSMutableData *					recordSeparator;
	NSMutableData *					receivedData;
	
	// Outbound Internet connection.
	NSURLConnection *				_connection;
	NSMutableData *					_receivedData; // outch... confusion with receivedData.....
	
	
	
}



// Declare properties.
@property (assign) IBOutlet		NSWindow *			window;
@property (nonatomic, readonly)	BOOL				isConnected;
@property (nonatomic, retain)	NSURLConnection *	connection;
@property (nonatomic, retain)	NSMutableData *		receivedData;



// Declare methods.

- (AMSerialPort * )port;
- (void)setPort:(AMSerialPort *)newPort;

// Inbound internet connection.
- (void)initNetServer;
- (void)changeNetPort;

// Outbound Internet connection.

- (IBAction)listSerialDevices:(id)sender;
- (IBAction)sendToSerial:(id)sender;
- (IBAction)connectSerialDevice:(id)sender;
- (IBAction)connectNetServer:(id)sender;


@end
