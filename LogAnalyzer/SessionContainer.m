//
//  SessionContainer.m
//  LogAnalyzer
//
//  Created by Vladimír Nevyhoštěný on 22.11.14.
//  Copyright (c) 2014 Vladimír Nevyhoštěný. All rights reserved.
//

@import AppKit;

#import "SessionContainer.h"

NSString *const ConnectedPeersChangedNotification = @"__connected_peers_changed_notification__";


//==============================================================================
@interface SessionContainer()
{
//    MCNearbyServiceAdvertiser *_advertiser;
    MCNearbyServiceBrowser    *_browser;
    NSMutableArray            *_acceptedPeerNames;
    NSMutableDictionary       *_sessions;
}
@end

//==============================================================================
@implementation SessionContainer

static NSString *const kConnectedPeers       = @"connectedPeers";
static NSString *const LoggerDataExchangeCtx = @"LoggerDataExchangeContext";

#pragma mark -
#pragma mark Init
//------------------------------------------------------------------------------
- (instancetype) initWithDisplayName:(NSString *)displayName serviceType:(NSString *)serviceType delegate:(id<SessionContainerDelegate>)delegate
{
    if ( ( self = [super init] ) ) {
        self->_sessions              = [NSMutableDictionary new];
        
        self.delegate                = delegate;
        self->_serviceType           = serviceType;
        self->_localPeerID           = [[MCPeerID alloc] initWithDisplayName:displayName];
        // Create the session that peers will be invited/join into.  You can provide an optinal security identity for custom authentication.  Also you can set the encryption preference for the session.
        self->_session               = [[MCSession alloc] initWithPeer:self->_localPeerID securityIdentity:nil encryptionPreference:MCEncryptionRequired];
        self->_session.delegate      = self;
        self->_acceptedPeerNames     = [NSMutableArray new];
        
        self->_browser               = [[MCNearbyServiceBrowser alloc] initWithPeer:self.localPeerID serviceType:serviceType];
        self->_browser.delegate      = self;
        
        [self startBrowse];
    }
    return self;
}

//------------------------------------------------------------------------------
- (void) dealloc
{
    [self stopBrowse];
}

//------------------------------------------------------------------------------
- (void) startBrowse
{
    [self->_browser startBrowsingForPeers];
}

//------------------------------------------------------------------------------
- (void) stopBrowse
{
    [self->_browser stopBrowsingForPeers];
    [self->_session disconnect];
    [self.delegate sessionContainerDidChangeState:MCSessionStateNotConnected];
}

#pragma mark -
#pragma mark MCNearbyServiceBrowserDelegate Methods
//------------------------------------------------------------------------------
- (void) browser:(MCNearbyServiceBrowser *)browser didNotStartBrowsingForPeers:(NSError *)error
{
    NSLog( @"MCNearbyServiceBrowser didNotStartBrowsingForPeers with error: %@", error );
}

//------------------------------------------------------------------------------
- (void)  browser:(MCNearbyServiceBrowser *)browser
        foundPeer:(MCPeerID *)peerID
withDiscoveryInfo:(NSDictionary *)info
{
    NSLog( @"Found peer: %@ with info: %@", peerID.displayName, info );
    if ( [self->_acceptedPeerNames indexOfObject:peerID.displayName] == NSNotFound ) {
        [browser invitePeer:peerID toSession:self->_session withContext:[LoggerDataExchangeCtx dataUsingEncoding:NSUTF8StringEncoding] timeout:30.0f];
    }
}

//------------------------------------------------------------------------------
- (void) browser:(MCNearbyServiceBrowser *)browser lostPeer:(MCPeerID *)peerID
{
    [self removePeer:peerID];
}


#pragma mark -
#pragma mark MCSessionDelegate Methods
//------------------------------------------------------------------------------
- (void) session:(MCSession *)session peer:(MCPeerID *)peerID didChangeState:(MCSessionState)state
{
    NSLog( @"Peer [%@] changed state to %@", peerID.displayName, [self stringForPeerConnectionState:state] );
    self->_sessionState = state;
    
    if ( state == MCSessionStateConnected ) {
        self->_sessions [peerID.displayName] = session;
    }
    else if ( state == MCSessionStateNotConnected ) {
        [session disconnect];
        [self->_sessions removeObjectForKey:peerID.displayName];
        [self->_acceptedPeerNames removeObject:peerID.displayName];
    }
    
    [self.delegate sessionContainerDidChangeState:state];
}

// MCSession Delegate callback when receiving data from a peer in a given session
//------------------------------------------------------------------------------
- (void) session:(MCSession *)session didReceiveData:(NSData *)data fromPeer:(MCPeerID *)peerID
{
    [self.delegate sessionContainerDidReceiveData:data fromPeer:peerID.displayName];
}

//------------------------------------------------------------------------------
- (void)      session:(MCSession *)session
didReceiveCertificate:(NSArray *)certificate
             fromPeer:(MCPeerID *)peerID
   certificateHandler:(void (^)(BOOL accept))certificateHandler
{
    certificateHandler(YES);
}

// Streaming API not utilized in this sample code
//------------------------------------------------------------------------------
- (void) session:(MCSession *)session didReceiveStream:(NSInputStream *)stream withName:(NSString *)streamName fromPeer:(MCPeerID *)peerID
{
    NSLog(@"Received data over stream with name %@ from peer %@", streamName, peerID.displayName);
}

//------------------------------------------------------------------------------
- (void) session:(MCSession *)session didStartReceivingResourceWithName:(NSString *)resourceName fromPeer:(MCPeerID *)peerID withProgress:(NSProgress *)progress
{
    NSLog( @"Start receviing resource name %@ from peer %@", resourceName, peerID.displayName);
}

//------------------------------------------------------------------------------
- (void) session:(MCSession *)session didFinishReceivingResourceWithName:(NSString *)resourceName fromPeer:(MCPeerID *)peerID atURL:(NSURL *)localURL withError:(NSError *)error
{
    NSLog( @"Received resource name %@ from peer %@", resourceName, peerID.displayName);
}

////------------------------------------------------------------------------------
//- (BOOL) sendData:(NSData*)data
//{
//    if ( ![self.session.connectedPeers count] ) {
//        return NO;
//    }
//    
//    NSError *error  = nil;
//    BOOL     result = [self.session sendData:data toPeers:self.session.connectedPeers withMode:MCSessionSendDataReliable error:&error];
//    
//    
//    return ( result && ( !error ) );
//}

#pragma mark -
#pragma mark Helper Methods
//------------------------------------------------------------------------------
- (NSString *) stringForPeerConnectionState:(MCSessionState)state
{
    switch (state) {
        case MCSessionStateConnected:
            return @"Connected";
            
        case MCSessionStateConnecting:
            return @"Connecting";
            
        case MCSessionStateNotConnected:
            return @"Not Connected";
    }
}

//------------------------------------------------------------------------------
- (void) removePeer:(MCPeerID*)peerID
{
    NSUInteger index = [self->_acceptedPeerNames indexOfObject:peerID.displayName];
    if ( index != NSNotFound ) {
        [self->_acceptedPeerNames removeObjectAtIndex:index];
    }
//    [self.peers removeObject:peerID];
    [[NSNotificationCenter defaultCenter] postNotificationName:ConnectedPeersChangedNotification object:nil];

}


@end
