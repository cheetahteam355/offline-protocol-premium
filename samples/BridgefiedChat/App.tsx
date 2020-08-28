import React, { useState, useCallback, useEffect } from 'react';
import {
  Alert,
  View,
  Text,
  StyleSheet,
  NativeEventEmitter,
  PermissionsAndroid,
  Platform,
} from 'react-native';
import { GiftedChat, IMessage } from 'react-native-gifted-chat';
import 'react-native-get-random-values';
import { v4 as uuid } from 'uuid';
import BridgefySdk from 'react-native-bridgefy-sdk';

const BRDG_LICENSE_KEY:string = "370d04e6-5e17-40e9-b68b-264e21381665";

const bridgefyEmitter = new NativeEventEmitter(BridgefySdk);

var messages;
var setMessages;

var client;
var setClient;

var connected;
var setConnected;

const systemMessage = (msg:string) => {
  return ({
    _id: uuid(),
    text: msg,
    createdAt: new Date(),
    system: true,
  }) as IMessage;
}

export default function App() {

  const msgState = useState([]);
  messages = msgState[0];
  setMessages = msgState[1];
  const clientState = useState(null);
  client = clientState[0];
  setClient = clientState[1];
  const connectedState = useState(false);
  connected = connectedState[0];
  setConnected = connectedState[1];
  
  let clearListeners = () => {
    bridgefyEmitter.removeAllListeners('onMessageReceived');
    bridgefyEmitter.removeAllListeners('onBroadcastMessageReceived');
    bridgefyEmitter.removeAllListeners('onMessageFailed');
    bridgefyEmitter.removeAllListeners('onMessageSent');
    bridgefyEmitter.removeAllListeners('onMessageReceivedException');
    bridgefyEmitter.removeAllListeners('onStarted');
    bridgefyEmitter.removeAllListeners('onStartError');
    bridgefyEmitter.removeAllListeners('onStopped');
    bridgefyEmitter.removeAllListeners('onDeviceConnected');
    bridgefyEmitter.removeAllListeners('onDeviceLost');
    bridgefyEmitter.removeAllListeners('onEventOccurred');
  }

  let initListeners = () => {
    console.log('INITING THE BRDG RN LISTENERS');
    bridgefyEmitter.addListener('onMessageReceived', (message)=> {
      console.log('onMessageReceived: '+ JSON.stringify(message));
    });
  
    // This event is launched when a broadcast message has been received, the structure 
    // of the dictionary received is explained in the appendix.
    bridgefyEmitter.addListener('onBroadcastMessageReceived', (message)=> {
      console.log('onBroadcastMessageReceived: '+ JSON.stringify(message));
      if (message.content.message) {
        setMessages(
          GiftedChat.append(
            messages, 
            JSON.parse(message.content.message)
          )
        );
      }
    });
  
    // This event is launched when a message could not be sent, it receives an error
    // whose structure will be explained in the appendix
    bridgefyEmitter.addListener('onMessageFailed', (error)=> {
      console.log('onMessageFailed: '+ error);
      setMessages(
        GiftedChat.append(
          messages, 
          [systemMessage(`Send message failed: ${error.message}`)]
        )
      );
    });
  
    // This event is launched when a message was sent, contains the message
    // itself, and the structure of message is explained in the appendix.
    bridgefyEmitter.addListener('onMessageSent', (message)=> {
      console.log('onMessageSent: '+ JSON.stringify(message));
    });
  
    // This event is launched when a message was received but it contains errors, 
    // the structure for this kind of error is explained in the appendix.
    // This method is launched exclusively on Android.
    bridgefyEmitter.addListener('onMessageReceivedException', (error)=> {
      console.log('onMessageReceivedException: '+ error);
      setMessages(
        GiftedChat.append(
          messages, 
          [systemMessage(`Receive message error: ${error.message}`)]
        )
      );
    });
  
    //
    // Device listeners
    //   
  
    // This event is launched when the service has been started successfully, it receives
    // a device dictionary that will be descripted in the appendix.
    bridgefyEmitter.addListener('onStarted', (device)=> {
      // For now, device is an empty dictionary
      console.log('onStarted');
      setConnected(true);
      setMessages(
        GiftedChat.append(
          messages, 
          [systemMessage(`Bridgefy started successfully`)]
        )
      );
    });
  
    // This event is launched when the BridgefySdk service fails on the start, it receives
    // a dictionary (error) that will be explained in the appendix.
    bridgefyEmitter.addListener('onStartError', (error)=> {
      console.log('onStartError: ',error);
      setMessages(
        GiftedChat.append(
          messages, 
          [systemMessage(`Bridgefy could not start: ${error.description}`)]
        )
      );
    });
  
    // This event is launched when the BridgefySdk service stops.
    bridgefyEmitter.addListener('onStopped', ()=> {
        console.log('onStopped');
        setConnected(false);
        setMessages(
          GiftedChat.append(
            messages, 
            [systemMessage(`Bridgefy stopped`)]
          )
        );
    });
  
    // This method is launched when a device is nearby and has established connection with the local user.
    // It receives a device dictionary.
    bridgefyEmitter.addListener('onDeviceConnected', (device)=> {
      console.log('onDeviceConnected: ' + JSON.stringify(device));
      setMessages(
        GiftedChat.append(
          messages, 
          [systemMessage(`Connected to device: ${device.userId}`)]
        )
      );
    });
    // This method is launched when there is a disconnection of a user.
    bridgefyEmitter.addListener('onDeviceLost', (device)=> {
      console.log('onDeviceLost: ' + device);
      setMessages(
        GiftedChat.append(
          messages, 
          [systemMessage(`Device lost: ${device.userId}`)]
        )
      );
    });
  
    // This is method is launched exclusively on iOS devices, notifies about certain actions like when
    // the bluetooth interface  needs to be activated, when internet is needed and others.
    bridgefyEmitter.addListener('onEventOccurred', (event)=> {
      console.log('Event code: ' + event.code + ' Description: ' + event.description);
    });
  }

  let initBrdg = () => {
    function doInitBrdg() {
      BridgefySdk.init(BRDG_LICENSE_KEY)
        .then((brdgClient)=>{
          setClient({
            _id: brdgClient.userUuid,
            name: "Broadcast User",
            avatar: 'https://unsplash.it/200/300/?random'
          });
          console.log("Brdg client = ",brdgClient);
          BridgefySdk.start();
        })
        .catch((e)=>{
          console.log(e);
          setMessages(
            GiftedChat.append(
              messages, 
              [systemMessage(`Bridgefy could not init: ${error.message}`)]
            )
          );
        });
    }
    if (Platform.OS=="android") {
      PermissionsAndroid.requestMultiple(
        [
          PermissionsAndroid.PERMISSIONS.ACCESS_FINE_LOCATION,
          PermissionsAndroid.PERMISSIONS.ACCESS_COARSE_LOCATION,
        ]).then((result) => {
          if (
            result['android.permission.ACCESS_COARSE_LOCATION']||
            result['android.permission.ACCESS_FINE_LOCATION']
          ) {
            doInitBrdg();
          }
          else { 
            setMessages(
              GiftedChat.append(
                messages, 
                [systemMessage(`Could not get required permissions to start Bridgefy`)]
              )
            );
          }
        })
        .catch((e)=>{
          setMessages(
            GiftedChat.append(
              messages, 
              [systemMessage(`Could not get required permissions to start Bridgefy: ${e.message}`)]
            )
          );
        });
    }
    else {
      doInitBrdg();
    }
  }

  let onSend = (brdgMessages = []) => {

    if (!connected) {
      Alert.alert(
        "Bridgefy not ready",
        "Your Bridgefy could not start  yet"
      );
      return false;
    }

    var message = {
      content: { message: JSON.stringify(brdgMessages[0]) },
    };

    console.log('onSend',brdgMessages[0]);
    
    let nm = GiftedChat.append(messages, brdgMessages);
    console.log('1 - nms = ',messages,brdgMessages,nm);
    setMessages(nm);

    BridgefySdk.sendBroadcastMessage(message);
  }

  useEffect(() => {
    
    initListeners();
    initBrdg();
      
    return function cleanup() {

      if (connected) {
        BridgefySdk.stop();
      }
      clearListeners();
    };
  }, []);

  return (
    <GiftedChat
      messages={messages}
      onSend={msgs => onSend(msgs)}
      renderChatFooter={()=> ( <ChatFooter connected={connected} /> ) }
      user={client ? client : {
        _id: 1,
      }}
    />
  )
}

const ChatFooter = (props) => {
  let { connected } = props;
  return (
    <View style={connected?styles.connected:styles.disconnected}>
      { connected && (
        <Text style={styles.connectedText}>
          Bridgefy connecté
        </Text>
      )}
      { !connected && (
        <Text style={styles.disconnectedText}>
          Bridgefy déconnecté !
        </Text>
      )}
    </View>
  )
}

const styles = StyleSheet.create({
  connected: {
    backgroundColor: 'rgba(22,255,22,.3)'
  },
  connectedText: {
    color: 'green',
    textAlign: 'center',
  },
  disconnected: {
    backgroundColor: 'rgba(255,22,22,.3)'
  },
  disconnectedText: {
    color: 'red',
    textAlign: 'center',
  }
});
