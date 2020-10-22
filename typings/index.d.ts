import { EventSubscriptionVendor } from 'react-native';

declare module "react-native-bridgefy-sdk" {

    export interface MessageFailedEvent<T> {
        code: number,
        description: string,
        origin: BridgefyMessage<T>
    }

    export interface MessageReceivedExceptionEvent<T> {
        sender: string,
        message: BridgefyMessage<T>
        description: string,
        code: number
    }
    
    export interface StartErrorEvent {
        code: number,
        message: string
    }
    
    export interface StoppedEvent {}
    
    export interface DeviceConnectedEvent {
        userId: string,
    }
    
    export interface DeviceLostEvent {
        userId: string,
    }
    
    export interface EventOccurredEvent {
        code: number,
        description: string
    }

    export interface BridgefyMessage<T> {
        content: T;
        receiver_id?: string;
        senderId?: string;
        uuid?: string;
        dateSent?: number;
    }

    export interface BridgefyClient {
        api_key: string;
        bundle_id: string;
        public_key: string;
        secret_key: string;
        userUuid: string;
        deviceProfile: string;
    }

    export default class BridgefySdk extends EventSubscriptionVendor {

        static init(apiKey: string): Promise<BridgefyClient>;
        
        static start(): Promise<{}>;
        
        static stop(): void;
        
        static sendMessage<T>(msg: BridgefyMessage<T>): void;
        
        static sendBroadcastMessage<T>(msg: BridgefyMessage<T>): void;
    }
}
