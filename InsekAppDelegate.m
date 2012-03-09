//
//  Insek_AppDelegate.m
//  Insek
//
//  Created by Kevin Filteau on 2010-05-30.
//  Copyright 2010 Kevin Filteau. All rights reserved.
//

#import "InsekAppDelegate.h"
#import "AMSerialPortList.h"
#import "AMSerialPortAdditions.h"


@implementation InsekAppDelegate

@synthesize window;
@synthesize connection		= _connection;
@synthesize receivedData	= _receivedData;



- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
	
	baudRates = [[NSArray alloc] initWithObjects:
				 [NSDictionary dictionaryWithObjectsAndKeys:@"300", @"name", @"300", @"value", nil],
				 [NSDictionary dictionaryWithObjectsAndKeys:@"1200", @"name", @"1200", @"value", nil],
				 [NSDictionary dictionaryWithObjectsAndKeys:@"2400", @"name", @"2400", @"value", nil],
				 [NSDictionary dictionaryWithObjectsAndKeys:@"4800", @"name", @"4800", @"value", nil],
				 [NSDictionary dictionaryWithObjectsAndKeys:@"9600", @"name", @"9600", @"value", nil],
				 [NSDictionary dictionaryWithObjectsAndKeys:@"14400", @"name", @"14400", @"value", nil],
				 [NSDictionary dictionaryWithObjectsAndKeys:@"19200", @"name", @"19200", @"value", nil],
				 [NSDictionary dictionaryWithObjectsAndKeys:@"28800", @"name", @"28800", @"value", nil],
 				 [NSDictionary dictionaryWithObjectsAndKeys:@"38400", @"name", @"38400", @"value", nil],
 				 [NSDictionary dictionaryWithObjectsAndKeys:@"57600", @"name", @"57600", @"value", nil],
				 [NSDictionary dictionaryWithObjectsAndKeys:@"115200", @"name", @"115200", @"value", nil],				 
				 nil];
	[arrayController setContent:baudRates];
}


- (void)awakeFromNib
{
	

	
	NSImage *imageFromBundle = [NSImage imageNamed:@"Insek-Application-Header.jpg"];
	[headerImage setImage: imageFromBundle];
	//[imageFromBundle release];
	// Serial port stuff.

	// register for port add/remove notification
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didAddPorts:) name:AMSerialPortListDidAddPortsNotification object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didRemovePorts:) name:AMSerialPortListDidRemovePortsNotification object:nil];
	[AMSerialPortList sharedPortList]; // initialize port list to arm notifications
	
	
	[self initNetServer];

	[logTextView insertText:@"Ready!\n"];
	[logTextView setNeedsDisplay:YES];
}


- (id)init
{

	if(self = [super init]) {
	
		//serialInputBuffer = [NSMutableString stringWithCapacity:0]; // stringWithCapacity init with autorelease by default. this doesn't work.
		// Maybe check if it's related with the Garbage Collection.
		
		//NSMutableString *	titleString = [ NSMutableString stringWithCapacity: 0 ];
		
		
		serialBuffer = [NSMutableData new]; // It's ok to declare it like that ?
		
		//serialBuffer = [[NSMutableData alloc] init];
		//serialBuffer = [NSMutableString stringWithCapacity: 0];
		
		// Add this to a pref pane.
		char recSep = '\r'; // I want this to be \r\n because the serial.println() Arduino function send this to end a line.
		recordSeparator = [[NSMutableData dataWithBytes:&recSep length:sizeof(recSep)] retain]; // this should definitely be moved somewhere, maybe a preferance panel where the user/tester can modify the separator characters on the fly
		


	}
	return self;	

}
- (void)dealloc
{
	[serialBuffer release];
	
	[super dealloc];
}




#pragma mark Serial
/***************************************************
 SERIAL
 ***************************************************/

- (AMSerialPort *)port
{
    return port;
}

- (void)setPort:(AMSerialPort *)newPort
{
    id old = nil;
	
    if (newPort != port) {
        old = port;
        port = [newPort retain];
        [old release];
    }
}

- (void)initPort
{
	// Get from preferences insted of the text field.
	
	NSString * deviceName = [[NSUserDefaults standardUserDefaults] stringForKey:@"ISKSerialDevice"];
	
	int selectedBaudRate = [[[NSUserDefaults standardUserDefaults] stringForKey:@"ISKBaudRate"] intValue];
	
	int deviceBaudRate = [[[baudRates objectAtIndex:selectedBaudRate] objectForKey:@"value"] intValue];
	
	//NSString *deviceBaudRate = [[NSUserDefaults standardUserDefaults] stringForKey:@"ISKBaudRate"];
	//assert(deviceBaudRate != 9600);
	
	
	if (![deviceName isEqualToString:[port bsdPath]]) {
		[port close];
		
		[self setPort:[[[AMSerialPort alloc] init:deviceName withName:deviceName type:(NSString*)CFSTR(kIOSerialBSDModemType)] autorelease]];
		
		// register as self as delegate for port
		[port setDelegate:self];
		
		[logTextView insertText:@"Attempting to open port...\n"];
		[logTextView setNeedsDisplay:YES];
		[logTextView displayIfNeeded];
		
		// open port - may take a few seconds ...
		if ([port open]) {
			
			[logTextView insertText:@"Port opened.\n"];
			[logTextView setNeedsDisplay:YES];
			[logTextView displayIfNeeded];
			
			//TODO: Set appropriate baud rate here. 
			
			//The standard speeds defined in termios.h are listed near
			//the top of AMSerialPort.h. Those can be preceeded with a 'B' as below. However, I've had success
			//with non standard rates (such as the one for the MIDI protocol). Just omit the 'B' for those.
			
			//[port setSpeed:B9600]; 
			[port setSpeed:deviceBaudRate];
			
			
			[connectSerialButton setTitle:@"Disconnect"];
			
			// listen for data in a separate thread
			[port readDataInBackground];
			
		} else { // an error occured while creating port
			[logTextView insertText:@"Couldn't open port for device "];
			[logTextView insertText:deviceName];
			[logTextView insertText:@"\n"];
			[logTextView setNeedsDisplay:YES];
			[logTextView displayIfNeeded];
			[self setPort:nil];
		}
	}
}



- (void)serialPortReadData:(NSDictionary *)dataDictionary
{
	
	// Define used vars.
	

	
	
	// this method is called if data arrives 
	// @"data" is the actual data, @"serialPort" is the sending port
	
	AMSerialPort *sendPort = [dataDictionary objectForKey:@"serialPort"];
	NSData *data = [dataDictionary objectForKey:@"data"];
	int dataLength = [data length];
	
	if (dataLength > 0) {
	
		[serialBuffer appendBytes:[data bytes] length:dataLength];
		
		
		// Buffering data.
		if([serialBuffer length] > [recordSeparator length]) { // The buffer must be at least longer than the record separator.
			
			const char *separatorChars = [recordSeparator bytes];
			const char *serialBufferBytes = [serialBuffer bytes];
			unsigned serialBufferLength = [serialBuffer length] - [recordSeparator length] + 1; // Because arrays start with 0.
			unsigned i;
			
			for(i = 0; i < serialBufferLength; i++) {
			
				if( serialBufferBytes[i] == separatorChars[0]
				   && (memcmp(&serialBufferBytes[i], separatorChars, [recordSeparator length]) == 0)) {
					
					NSData *record = [NSData dataWithBytes:serialBufferBytes length:i];
					
					NSMutableString *text = [[NSMutableString alloc] initWithData:record encoding:NSASCIIStringEncoding];
					
					// Log
					[logTextView insertText:text];
					[logTextView insertText:@"\n"];
					

					// Trim white space and new line caracters like \r and \n.
					text = (NSMutableString*)[text stringByTrimmingCharactersInSet:
										   [NSCharacterSet whitespaceAndNewlineCharacterSet]];
					
					
					
					// Check if the connection is ready (not in use).
					if( ! self.isConnected ) {
						
						// Create the request.
						NSMutableURLRequest * request = [[[NSMutableURLRequest alloc] initWithURL:[NSURL URLWithString:[NSString stringWithFormat:@"%@?q=%@",
																														[[NSUserDefaults standardUserDefaults] stringForKey:@"ISKRequestURL"],
																																				 [text stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]]]
							cachePolicy:NSURLRequestReloadIgnoringCacheData timeoutInterval:60.0] autorelease];
						
						
						assert(request != nil);
						
						
						// create the connection using this request and begin loading data.
						self.connection = [[NSURLConnection alloc] initWithRequest:request delegate:self];
						assert(self.connection != nil);
						
						
						
						
						if (self.isConnected) {
							// Create the NSMutableData to hold the received data.
							// receivedData is an instance variable declared elsewhere.
						
							//receivedData = [[NSMutableData data] retain];
							
						} else {
							// Inform the user that the connection failed.
						}
						
						
					} else {
						[logTextView insertText:@"Connection in use."];
					}
					
					// Remove the processed data from string buffer.
					[serialBuffer replaceBytesInRange:NSMakeRange(0, i + [recordSeparator length]) withBytes:nil length:0];
					
				}
			} // End for 
		}
		
		
		
		
		
		
		

		
		[sendPort readDataInBackground];

	} else { // port closed
		[logTextView insertText:@"Port closed\n"];
	}
	
	
	[logTextView setNeedsDisplay:YES];
	[logTextView displayIfNeeded];
}

- (void)didAddPorts:(NSNotification *)theNotification
{
	[logTextView insertText:@"didAddPorts:"];
	[logTextView insertText:@"\n"];
	[logTextView insertText:[[theNotification userInfo] description]];
	[logTextView insertText:@"\n"];
	[logTextView setNeedsDisplay:YES];
}

- (void)didRemovePorts:(NSNotification *)theNotification
{
	[logTextView insertText:@"didRemovePorts:"];
	[logTextView insertText:@"\n"];
	[logTextView insertText:[[theNotification userInfo] description]];
	[logTextView insertText:@"\n"];
	[logTextView setNeedsDisplay:YES];
}

- (IBAction)listSerialDevices:(id)sender
{
	// get an port enumerator
	NSEnumerator *enumerator = [AMSerialPortList portEnumerator];
	AMSerialPort *aPort;
	while (aPort = [enumerator nextObject]) {
		// print port name
		[logTextView insertText:[aPort name]];
		[logTextView insertText:@":"];
		[logTextView insertText:[aPort bsdPath]];
		[logTextView insertText:@"\n"];
	}
	[logTextView setNeedsDisplay:YES];
}

- (IBAction)chooseSerialDevice:(id)sender
{
	// new device selected
	[self initPort];
}

- (IBAction)sendToSerial:(id)sender
{
	NSString *sendString = [[inputTextField stringValue] stringByAppendingString:@"\r"];
	
	if(!port) {
		// open a new port if we don't already have one
		[self initPort];
	}
	
	if([port isOpen]) { // in case an error occured while opening the port
		[port writeString:sendString usingEncoding:NSUTF8StringEncoding error:NULL];
	}
}


- (IBAction)connectSerialDevice:(id)sender
{
	if([port isOpen]) {
		[port close];
		[self setPort:nil];
		[connectSerialButton setTitle:@"Connect"];
	} else {
		[self initPort];
	}
}



#pragma mark Outbound Internet Connection.

- (BOOL)isConnected
{
	return (self.connection != nil);
}


- (void)connection:(NSURLConnection *)theConnection didReceiveResponse:(NSURLResponse *)response
{
    // This method is called when the server has determined that it
    // has enough information to create the NSURLResponse.
	
    // It can be called multiple times, for example in the case of a
    // redirect, so each time we reset the data.
	
    // receivedData is an instance variable declared elsewhere.

    assert(theConnection == self.connection);
	
	// Empty receivedData object.
	[self.receivedData setLength:0];
	
}


- (void)connection:(NSURLConnection *)theConnection didReceiveData:(NSData *)data
{
    // Append the new data to receivedData.
    // receivedData is an instance variable declared elsewhere.
	
	assert(theConnection == self.connection);
	
    [self.receivedData appendData:data];
}


- (void)connection:(NSURLConnection *)theConnection didFailWithError:(NSError *)error
{
	
	assert(theConnection == self.connection);
	
    // release the connection, and the data object
    //[connection release];
    // receivedData is declared as a method instance elsewhere

	// Stop the connection.
	
	//[receivedData release];
	
    // inform the user
	
	[logTextView insertText:[NSString stringWithFormat:@"Connection failed! Error %@\n",[error localizedDescription]]];
	[logTextView setNeedsDisplay:YES];
	
    /*NSLog(@"Connection failed! Error - %@ %@",
          [error localizedDescription],
          [[error userInfo] objectForKey:NSErrorFailingURLStringErrorKey]);
	 */
	
	self.connection = nil;
	[self.receivedData setLength:0];
}

- (void)connectionDidFinishLoading:(NSURLConnection *)theConnection
{
    // do something with the data
    // receivedData is declared as a method instance elsewhere
    //NSLog(@"Succeeded! Received %d bytes of data",[receivedData length]);
	[logTextView insertText:@"Succeeded!\n"];
	[logTextView setNeedsDisplay:YES];
	
    // release the connection, and the data object
    //[connection release];
    //[receivedData release];
	self.connection = nil;
	[self.receivedData setLength:0];
}

#pragma mark Inbound Internet Listener.
/***************************************************
 INTERNET SOCKET
 ***************************************************/

- (void)initNetServer
{

	// start Simple Cocoa Server
	//simpleCocoaServer = [[SimpleCocoaServer alloc] initWithPort:55567 delegate:self];
	//[simpleCocoaServer startListening];
	
	
	
	//NSArray *allServerConnections = [SimpleCocoaServer connections];
	
	//stopListening;
	/*
	if(connectionStatus == SCSInitOK) {
		[server stopListening];
		[server release];
	}
	[connectNetServerButton setTitle:[NSString stringWithFormat:@"%d", connectionStatus]];*/
	//[self closeConnection];
	// Restart server.
	
	// Internet socket stuff.
	
	// Load net server port from preferences.
	
	
	NSString *netPort = [[NSUserDefaults standardUserDefaults] stringForKey:@"ISKNetPort"];
	
	
	
	//[self setPort:[[[AMSerialPort alloc] init:deviceName withName:deviceName type:(NSString*)CFSTR(kIOSerialBSDModemType)] autorelease]];
	
	// Initialize the socket server. (initial call). Before I make *server global.
	//SimpleCocoaServer *server = [[SimpleCocoaServer alloc] initWithPort:[netPort integerValue] delegate:self];
	
	server = [[SimpleCocoaServer alloc] initWithPort:[netPort integerValue] delegate:self];
	
	//- (void)closeConnection:(SimpleCocoaConnection *)con;
	
	
	//[self setNetServer:[[SimpleCocoaServer alloc] initWithPort:[netPort integerValue] autorelease]];
	
	 //[server setDelegate:self];
	
	// Show listening address.
	// [server setListenAddress:SCSListenLoopback];
	// NSString *addr = [server listenAddressAsString]; //returns 127.0.0.1
	// [ipTextField setStringValue:addr]; // Eve's Arduino Serial Port.
	
	connectionStatus = [server startListening];
	
	
	if(connectionStatus == SCSInitOK) {
		[netConStatus setStringValue:@"Connected"];
		//[netConStatus setStringValue:[NSString stringWithFormat:@"%d", connectionStatus]];
		
	}
	
	
	/*
	if(connectionStatus == SCSInitOK) {
		[connectNetServerButton setTitle:@"Stop Server"];
	} else {
		
		//connectionStatus = [server stopListening];
		
		//[connectNetServerButton setTitle:@"Start Server"];
		
		[connectNetServerButton setTitle:[NSString stringWithFormat:@"%d", connectionStatus]];
	}*/
	
}

- (IBAction)connectNetServer:(id)sender
{
	
	/*
	// Stop server if there is a connection.
	if(connectionStatus == SCSInitOK) {
		//[server stopListening];
		//[[self server] release];
		[connectNetServerButton setTitle:@"Start Server"];
	// Else start the server.
	} else {
		//[[self server] initNetServer];
	}*/
	
	
	[self initNetServer];
}


- (void)changeNetPort
{
	[self initNetServer];
}

- (void)processNewConnection:(SimpleCocoaConnection *)con
{
	//[server sendString:@"Welcome to SimpleCocoaServer" toConnection:con];
	
	[logTextView insertText:@"Net connection established.\n"];
	[logTextView setNeedsDisplay:YES];
	
	//Sample call.
	//[self sendContentsOfDirectory:self.selectedDirectory directories:YES toConnection:con];
    
	//Replies to the new client.
}
- (void)processClosingConnection:(SimpleCocoaConnection *)con
{
	[logTextView insertText:@"Net connection closed.\n"];
	[logTextView setNeedsDisplay:YES];
	
}
/**
 Get and process the message get from the Internet socket call.
 */
- (void)processMessage:(NSString *)message orData:(NSData *)data fromConnection:(SimpleCocoaConnection *)con
{
	
	// Do something.
	
	[logTextView insertText:@"\n"];
	[logTextView insertText:message];
	[logTextView insertText:@"\n"];
	[logTextView setNeedsDisplay:YES];
	
	
	// Add the carriage return a the end of the received string.
	NSString *sendString = [message stringByAppendingString:@"\r"];
	
	if(!port) {
		// Open a new port if we don't already have one
		[self initPort];
	}
	
	if([port isOpen]) { // in case an error occured while opening the port
		
		// Implement the function here...
		// If using async mode. (The input string will be buffered in Insek while the serial device gets it.
		
		// Transmit the received string to the serial port.
		[port writeString:sendString usingEncoding:NSUTF8StringEncoding error:NULL];
	}
	
}

@end
