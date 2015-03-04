//
//  SessionContainer.h
//  LogAnalyzer
//
//  Created by Vladimír Nevyhoštěný on 22.11.14.
//  Copyright (c) 2014 Vladimír Nevyhoštěný. All rights reserved.
//

@import Foundation;
@import MultipeerConnectivity;

extern NSString *const ConnectedPeersChangedNotification;

@protocol SessionContainerDelegate;

//==============================================================================
@interface SessionContainer : NSObject <MCSessionDelegate, MCNearbyServiceBrowserDelegate>

@property (readonly, nonatomic) MCPeerID                   *localPeerID;
@property (readonly, nonatomic) NSString                   *serviceType;
@property (readonly, nonatomic) MCSession                  *session;
@property (readonly, nonatomic) MCSessionState              sessionState;
@property (assign, nonatomic) id<SessionContainerDelegate>  delegate;

- (instancetype) initWithDisplayName:(NSString *)displayName serviceType:(NSString *)serviceType delegate:(id<SessionContainerDelegate>)delegate;

- (void) startBrowse;
- (void) stopBrowse;

@end

//==============================================================================
@protocol SessionContainerDelegate <NSObject>

@required
- (void) sessionContainerDidChangeState:(MCSessionState)state;
- (void) sessionContainerDidReceiveData:(NSData*)data fromPeer:(NSString*)peerName;
@end