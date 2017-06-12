package com.bridgefy.react.sdk.framework;

import com.bridgefy.react.sdk.utils.Utils;
import com.bridgefy.sdk.client.Message;
import com.bridgefy.sdk.client.MessageListener;
import com.bridgefy.sdk.framework.exceptions.MessageException;
import com.facebook.react.bridge.Arguments;
import com.facebook.react.bridge.ReactContext;
import com.facebook.react.bridge.WritableMap;

/**
 * @author kekoyde on 6/9/17.
 */

class BridgefyMessages extends MessageListener {
    private ReactContext reactContext;

    public BridgefyMessages(ReactContext reactContext) {
        this.reactContext = reactContext;
    }

    @Override
    public void onMessageReceived(Message message) {
        Utils.sendEvent(reactContext,"onMessageReceived", Utils.getMapForMessage(message));
    }

    @Override
    public void onMessageSent(Message message) {
        Utils.sendEvent(reactContext,"onMessageSent", Utils.getMapForMessage(message));
    }

    @Override
    public void onMessageReceivedException(String sender, MessageException e) {
        WritableMap writableMap = Arguments.createMap();
        writableMap.putString("Sender", sender);
        writableMap.putString("MessageException", e.getMessage());
        Utils.sendEvent(reactContext,"onMessageReceivedException", writableMap);
    }

    @Override
    public void onMessageFailed(Message message, MessageException e) {
        WritableMap writableMap = Utils.getMapForMessage(message);
        writableMap.putString("MessageException", e.getMessage());
        Utils.sendEvent(reactContext,"onMessageFailed", writableMap);
    }

    @Override
    public void onBroadcastMessageReceived(Message message) {
        Utils.sendEvent(reactContext,"onBroadcastMessageReceived", Utils.getMapForMessage(message));
    }
}
