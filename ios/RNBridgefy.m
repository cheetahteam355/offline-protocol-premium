//
//  RNBridgefy.m
//  AwesomeProject
//
//  Created by Danno on 6/15/17.
//  Copyright © 2017 Facebook. All rights reserved.
//

#import "RNBridgefy.h"
#import <BFTransmitter/BFTransmitter.h>

#import <React/RCTConvert.h>
#import <React/RCTLog.h>
#import <React/RCTUtils.h>
#import <React/RCTBridge.h>

#ifndef BRIDGEFY_E
#define BRIDGEFY_E
#define kMessageReceived @"onMessageReceived"
#define kMessageSent @"onMessageSent"
#define kMessageReceivedError @"onMessageReceivedException"
#define kMessageSentError @"onMessageFailed"
#define kBroadcastReceived @"onBroadcastMessageReceived"
#define kStarted @"onStarted"
#define kStartedError @"onStartError"
#define kStopped @"onStopped"
#define kDeviceConnected @"onDeviceConnected"
#define kDeviceDisconnected @"onDeviceLost"
#define kEventOccurred @"onEventOccurred"
#endif

@interface RNBridgefy()<BFTransmitterDelegate> {
}

@property (nonatomic, retain) BFTransmitter * transmitter;
@property (nonatomic, retain) NSMutableDictionary * transitMessages;

@property (nonatomic,assign) BOOL hasListeners;

@end

@implementation RNBridgefy

RCTPromiseResolveBlock startResolve;
RCTPromiseRejectBlock startReject;

- (dispatch_queue_t)methodQueue
{
    // main queue (blocking UI)
    // return dispatch_get_main_queue();

    // try, dedicated queue
    return dispatch_queue_create("com.facebook.React.BridgefyQueue", DISPATCH_QUEUE_SERIAL);
}

- (void)invalidate
{
    RCTLogTrace(@"invalidate");
    self.hasListeners = NO;
    [self.transmitter stop];
}

// Will be called when this module's first listener is added.
-(void)startObserving {
    RCTLogTrace(@"RCT startObserving");
    self.hasListeners = YES;
}

// Will be called when this module's last listener is removed, or on dealloc.
-(void)stopObserving {
    RCTLogTrace(@"RCT stopObserving");
    self.hasListeners = NO;
}

RCT_EXPORT_MODULE();

- (NSArray<NSString *> *)supportedEvents {
    return @[
            kMessageReceived,
            kMessageSent,
            kMessageReceivedError,
            kMessageSentError,
            kBroadcastReceived,
            kStarted,
            kStartedError,
            kStopped,
            kDeviceConnected,
            kDeviceDisconnected,
            kEventOccurred
        ];
}

RCT_REMAP_METHOD(init, startWithApiKey:(NSString *)apiKey resolver:(RCTPromiseResolveBlock)resolve rejecter:(RCTPromiseRejectBlock)reject) {
    [BFTransmitter setLogLevel:BFLogLevelTrace]; // TODO remove
    
    if (self.transmitter != nil) {
        NSDictionary * dictionary = [self createClientDictionary];
        resolve(@[dictionary]);
        return;
    }
    self.transmitter = [[BFTransmitter alloc] initWithApiKey:apiKey];
    
    if (self.transmitter != nil) {
        self.transmitter.delegate = self;
        NSDictionary * dictionary = [self createClientDictionary];
        resolve(@[dictionary]);
        _transitMessages = [[NSMutableDictionary alloc] init];
    } else {
        self.transmitter.delegate = self;
        reject(@"initialization error", @"Bridgefy could not be initialized.",nil);
    }
    
}

RCT_EXPORT_METHOD(start:(RCTPromiseResolveBlock)resolve rejecter:(RCTPromiseRejectBlock)reject) {
    if ( self.transmitter == nil ) {
        RCTLogError(@"Bridgefy was not initialized, the operation won't continue.");
        return;
    }
    startResolve = resolve;
    startReject = reject;
    [self.transmitter start];
}

RCT_EXPORT_METHOD(stop) {
    [self.transmitter stop];
    if (self.hasListeners) {
        [self sendEventWithName:kStopped body:@{}];
    }
}

RCT_REMAP_METHOD(sendMessage, sendMessage:(NSDictionary *) message) {
    BFSendingOption options = (BFSendingOptionEncrypted | BFSendingOptionFullTransmission);
    [self sendMessage:message WithOptions:options];
}

RCT_REMAP_METHOD(sendBroadcastMessage, sendBroadcastMessage:(NSDictionary *) message) {
    NSLog(@"sending broadcast");
    BFSendingOption options = (BFSendingOptionBroadcastReceiver | BFSendingOptionMeshTransmission);
    [self sendMessage:message WithOptions:options];
}

- (void)sendMessage:(NSDictionary *)message WithOptions: (BFSendingOption)options {
    
    if (![self transmitterCanWork]) {
        return;
    }
    
    if (message[@"content"] == nil) {
        RCTLogError(@"The field 'content' is missing, the message won't be sent: %@", [message description]);
        return;
    }
    
    if (message[@"receiver_id"] == nil && (options & BFSendingOptionBroadcastReceiver) == 0) {
        RCTLogError(@"The field 'receiver_id' is missing, the message won't be sent: %@", [message description]);
        return;
    }
    
    NSError * error = nil;
    
    NSString * packetID = [self.transmitter sendDictionary:message[@"content"]
                                                    toUser:message[@"receiver_id"]
                                                   options:options
                                                     error:&error];
    
    NSDictionary * createdMessage = [self createMessageDictionaryWithPayload:message[@"content"]
                                                                      sender:self.transmitter.currentUser
                                                                    receiver:message[@"receiver_id"]
                                                                        uuid:packetID];
    
    if (error == nil) {
        // Message began the sending process
        self.transitMessages[packetID] = createdMessage;
    } else {
        if (self.hasListeners) {
            // Error sending the message
            NSDictionary * errorDict = @{
                                         @"code": @(error.code),
                                         @"description": error.localizedDescription,
                                         @"origin": createdMessage
                                         };
            [self sendEventWithName:kMessageSentError body:errorDict];
        }
    }
    
}

#pragma mark - Utils

-(BOOL)transmitterCanWork {
    if ( self.transmitter == nil ) {
        RCTLogError(@"Bridgefy was not initialized, the operation won't continue.");
        return NO;
    }
    
    if (!self.transmitter.isStarted) {
        RCTLogError(@"Bridgefy was not started, the operation won't continue.");
        return NO;
    }
    
    return YES;
}

- (NSDictionary *)createClientDictionary {
    NSLog(@"Public %@", self.transmitter.localPublicKey);
    NSLog(@"userUUID %@", self.transmitter.currentUser);
    return @{
             @"api_key": @"",
             @"bundle_id": @"",
             @"public_key": self.transmitter.localPublicKey,
             @"secret_key": @"",
             @"userUuid": self.transmitter.currentUser,
             @"deviceProfile": @""
             };
}

- (NSDictionary *)createMessageDictionaryWithPayload:(NSDictionary *)payload
                                              sender:(NSString *)sender
                                            receiver:(NSString *) receiver
                                                uuid:(NSString *)uuid {
    NSString * msgReceiver = receiver != nil? receiver : @"";
    NSString * msgUUID = uuid != nil? uuid : @"";
    
    return @{
             @"receiverId": msgReceiver,
             @"senderId": sender,
             @"uuid": msgUUID,
             @"dateSent": [NSDate dateWithTimeIntervalSince1970:0],
             @"content": payload
             };
    
}

#pragma mark - BFTransmitterDelegate

- (void)transmitter:(BFTransmitter *)transmitter meshDidAddPacket:(NSString *)packetID {
    if (self.transitMessages[packetID] != nil) {
        [self.transitMessages removeObjectForKey:packetID];
    }
}

- (void)transmitter:(BFTransmitter *)transmitter didReachDestinationForPacket:( NSString *)packetID {
    NSLog(@"didReachDestinationForPacket !!");
}

- (void)transmitter:(BFTransmitter *)transmitter meshDidStartProcessForPacket:( NSString *)packetID {
    if (self.transitMessages[packetID] != nil) {
        [self.transitMessages removeObjectForKey:packetID];
    }
}

- (void)transmitter:(BFTransmitter *)transmitter didSendDirectPacket:(NSString *)packetID {
    NSDictionary * message = self.transitMessages[packetID];
    if (message == nil) {
        return;
    }
    if (self.hasListeners) {
        [self sendEventWithName:kMessageSent body:message];
    }
    [self.transitMessages removeObjectForKey:packetID];
}

- (void)transmitter:(BFTransmitter *)transmitter didFailForPacket:(NSString *)packetID error:(NSError * _Nullable)error {
    NSDictionary * message = self.transitMessages[packetID];
    if (message == nil) {
        return;
    }
    if (self.hasListeners) {
        NSDictionary * errorDict = @{
                                     @"code": @(error.code),
                                     @"description": error.localizedDescription,
                                     @"origin": message
                                     };
        [self sendEventWithName:kMessageSentError body:errorDict];
    }
    [self.transitMessages removeObjectForKey:packetID];
}

- (void)transmitter:(BFTransmitter *)transmitter meshDidDiscardPackets:(NSArray<NSString *> *)packetIDs {
    //TODO: Implement
    NSLog(@"meshDidDiscardPackets !!");
    
}

- (void)transmitter:(BFTransmitter *)transmitter meshDidRejectPacketBySize:(NSString *)packetID {
    //TODO: Implement
    NSLog(@"meshDidRejectPacketBySize !!");
    
}

- (void)transmitter:(BFTransmitter *)transmitter
didReceiveDictionary:(NSDictionary<NSString *, id> * _Nullable) dictionary
           withData:(NSData * _Nullable)data
           fromUser:(NSString *)user
           packetID:(NSString *)packetID
          broadcast:(BOOL)broadcast
               mesh:(BOOL)mesh {
    NSDictionary * message;
    if (self.hasListeners) {
        if (broadcast) {
            message = [self createMessageDictionaryWithPayload:dictionary
                                                        sender:user
                                                      receiver:nil
                                                          uuid:packetID];
            [self sendEventWithName:kBroadcastReceived body:message];
        } else {
            message = [self createMessageDictionaryWithPayload:dictionary
                                                        sender:user
                                                      receiver: transmitter.currentUser
                                                          uuid:packetID];
            [self sendEventWithName:kMessageReceived body:message];
        }
    }
}

- (void)transmitter:(BFTransmitter *)transmitter didDetectConnectionWithUser:(NSString *)user {
    //TODO: Implement
    NSLog(@"didDetectConnectionWithUser !!");
    
}

- (void)transmitter:(BFTransmitter *)transmitter didDetectDisconnectionWithUser:(NSString *)user {
    if (self.hasListeners) {
        NSDictionary * userDict = @{
                                    @"userId": user
                                    };
        [self sendEventWithName:kDeviceDisconnected body:userDict];
    }
}

- (void)transmitter:(BFTransmitter *)transmitter didFailAtStartWithError:(NSError *)error {
    if (self.hasListeners) {
        NSDictionary * errorDict = @{
                                     @"code": @(error.code),
                                     @"message": error.localizedDescription
                                     };
        [self sendEventWithName:kStartedError body:errorDict];
    }

    if (startReject != nil) {
        startReject(kStartedError,error.localizedDescription, error);
    }
}

- (void)transmitter:(BFTransmitter *)transmitter didOccurEvent:(BFEvent)event description:(NSString *)description {
    NSLog(@"didOccurEvent %lu",event);
    if (event == BFEventStartFinished ) {
        if (self.hasListeners) {
            [self sendEventWithName:kStarted body:@{}]; // should we keep it?
        }

        if (startResolve != nil) {
            startResolve(@{});
        }

    } else if (self.hasListeners) {
        NSDictionary * eventDict = @{
                                     @"code": @(event),
                                     @"description": description
                                     };
        [self sendEventWithName:kEventOccurred body:eventDict];
    }
}

- (void)transmitter:(BFTransmitter *)transmitter didDetectSecureConnectionWithUser:(NSString *)user {
    NSLog(kDeviceConnected);
    if (self.hasListeners) {
        NSDictionary * userDict = @{
                                    @"userId": user
                                    };
        [self sendEventWithName:kDeviceConnected body:userDict];
    }
}

- (BOOL)transmitter:(BFTransmitter *)transmitter shouldConnectSecurelyWithUser:(NSString *)user {
    return YES;
    // return NO;
}

- (void)transmitterNeedsInterfaceActivation:(BFTransmitter *)transmitter {
    NSLog(@"transmitterNeedsInterfaceActivation");
    //TODO: Implement?
}

- (void)transmitterDidDetectAnotherInterfaceStarted:(BFTransmitter *)transmitter {
    NSLog(@"transmitterDidDetectAnotherInterfaceStarted");
    //TODO: Implement?
}

- (void)transmitter:(nonnull BFTransmitter *)transmitter didDetectNearbyUser:(nonnull NSString *)user {
    NSLog(@"didDetectNearbyUser");
    // TODO Implement?
}


- (void)transmitter:(nonnull BFTransmitter *)transmitter didFailConnectingToUser:(nonnull NSString *)user error:(nonnull NSError *)error {
    NSLog(@"didFailConnectingToUser");
    // TODO Implement?
}


- (void)transmitter:(nonnull BFTransmitter *)transmitter userIsNotAvailable:(nonnull NSString *)user {
    NSLog(@"userIsNotAvailable");
    // TODO Implement?
}


@end
