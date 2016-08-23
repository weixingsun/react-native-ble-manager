#import "BleManager.h"
#import "RCTBridge.h"
#import "RCTConvert.h"
#import "RCTEventDispatcher.h"
#import "NSData+Conversion.h"
#import "CBPeripheral+Extensions.h"
#import "BLECommandContext.h"
#import "STCentralTool.h"

@implementation BleManager


RCT_EXPORT_MODULE();

@synthesize bridge = _bridge;

@synthesize manager;
@synthesize peripherals;
@synthesize state;
@synthesize tool;
@synthesize peripheralManager;

  CBMutableCharacteristic *characteristic;
  CBMutableCharacteristic *characteristic1;
  CBMutableCharacteristic *characteristic2;
  CBMutableService *servicea;
  NSData *mainData;
  NSString *range;

- (instancetype)init
{
    
    if (self = [super init]) {
        NSLog(@"BleManager initialized");
        peripherals = [NSMutableSet set];
        manager = [[CBCentralManager   alloc] initWithDelegate:self queue:dispatch_get_main_queue()];
        peripheralManager = [[CBPeripheralManager alloc] initWithDelegate:self queue:dispatch_get_main_queue()];
        self.tool = [STCentralTool shareInstence];
        self.tool.delegate = self;
        connectCallbacks = [NSMutableDictionary new];
        connectCallbackLatches = [NSMutableDictionary new];
        readCallbacks = [NSMutableDictionary new];
        writeCallbacks = [NSMutableDictionary new];
        writeQueue = [NSMutableArray array];
        notificationCallbacks = [NSMutableDictionary new];
        stopNotificationCallbacks = [NSMutableDictionary new];
    }
    
    return self;
}


- (void)peripheral:(CBPeripheral *)peripheral didUpdateValueForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error {
    if (error) {
        NSLog(@"Error %@ :%@", characteristic.UUID, error);
        return;
    }
    NSLog(@"Read value [%@]: %@", characteristic.UUID, characteristic.value);
    
    NSString *key = [self keyForPeripheral: peripheral andCharacteristic:characteristic];
    RCTResponseSenderBlock readCallback = [readCallbacks objectForKey:key];
    
    NSString *stringFromData = [characteristic.value hexadecimalString];
    
    if (readCallback != NULL){
        readCallback(@[stringFromData]);
        [readCallbacks removeObjectForKey:key];
    } else {
        [self.bridge.eventDispatcher sendAppEventWithName:@"BleManagerDidUpdateValueForCharacteristic" body:@{@"peripheral": peripheral.uuidAsString, @"characteristic":characteristic.UUID.UUIDString, @"value": stringFromData}];
    }
}

- (void)peripheral:(CBPeripheral *)peripheral didUpdateNotificationStateForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error {
    if (error) {
        NSLog(@"Error in didUpdateNotificationStateForCharacteristic: %@", error);                
        return;
    }
    
    // Call didUpdateValueForCharacteristic only when we have a value.
    /*
     if (characteristic.value)
     {
     NSLog(@"Received value from notification: %@", characteristic.value);
     }*/
    
    NSString *key = [self keyForPeripheral: peripheral andCharacteristic:characteristic];
    
    if (characteristic.isNotifying) {
        NSLog(@"Notification began on %@", characteristic.UUID);
        RCTResponseSenderBlock notificationCallback = [notificationCallbacks objectForKey:key];
        notificationCallback(@[]);
        [notificationCallbacks removeObjectForKey:key];
    } else {
        // Notification has stopped
        NSLog(@"Notification ended on %@", characteristic.UUID);
        RCTResponseSenderBlock stopNotificationCallback = [stopNotificationCallbacks objectForKey:key];
        stopNotificationCallback(@[]);
        [stopNotificationCallbacks removeObjectForKey:key];
    }
}

- (NSString *) centralManagerStateToString: (int)state
{
    switch (state) {
        case CBCentralManagerStateUnknown:
            return @"unknown";
        case CBCentralManagerStateResetting:
            return @"resetting";
        case CBCentralManagerStateUnsupported:
            return @"unsupported";
        case CBCentralManagerStateUnauthorized:
            return @"unauthorized";
        case CBCentralManagerStatePoweredOff:
            return @"off";
        case CBCentralManagerStatePoweredOn:
            return @"on";
        default:
            return @"unknown";
    }
    
    return @"unknown";
}

- (NSString *) periphalStateToString: (int)state
{
    switch (state) {
        case CBPeripheralStateDisconnected:
            return @"disconnected";
        case CBPeripheralStateDisconnecting:
            return @"disconnecting";
        case CBPeripheralStateConnected:
            return @"connected";
        case CBPeripheralStateConnecting:
            return @"connecting";
        default:
            return @"unknown";
    }
    
    return @"unknown";
}

- (NSString *) periphalManagerStateToString: (int)state
{
    switch (state) {
        case CBPeripheralManagerStateUnknown:
            return @"Unknown";
        case CBPeripheralManagerStatePoweredOn:
            return @"PoweredOn";
        case CBPeripheralManagerStatePoweredOff:
            return @"PoweredOff";
        default:
            return @"unknown";
    }
    
    return @"unknown";
}

- (CBPeripheral*)findPeripheralByUUID:(NSString*)uuid {
    
    CBPeripheral *peripheral = nil;
    
    for (CBPeripheral *p in peripherals) {
        
        NSString* other = p.identifier.UUIDString;
        
        if ([uuid isEqualToString:other]) {
            peripheral = p;
            break;
        }
    }
    return peripheral;
}

-(CBService *) findServiceFromUUID:(CBUUID *)UUID p:(CBPeripheral *)p
{
    for(int i = 0; i < p.services.count; i++)
    {
        CBService *s = [p.services objectAtIndex:i];
        if ([self compareCBUUID:s.UUID UUID2:UUID])
            return s;
    }
    
    return nil; //Service not found on this peripheral
}

-(int) compareCBUUID:(CBUUID *) UUID1 UUID2:(CBUUID *)UUID2
{
    char b1[16];
    char b2[16];
    [UUID1.data getBytes:b1 length:16];
    [UUID2.data getBytes:b2 length:16];
    
    if (memcmp(b1, b2, UUID1.data.length) == 0)
        return 1;
    else
        return 0;
}
RCT_EXPORT_METHOD(isEnabled: (RCTResponseSenderBlock)successCallback
                                failCallback:(RCTResponseSenderBlock)failCallback)
{
    CBCentralManagerState *stateName = [self state];
    if([self state] == CBCentralManagerStatePoweredOn)
        successCallback(@[]);
    else if([self state] == CBCentralManagerStatePoweredOff)
        failCallback(@[]);
}
RCT_EXPORT_METHOD(isAdvertisingSupported: (RCTResponseSenderBlock)successCallback
                  failCallback:(RCTResponseSenderBlock)failCallback)
{
    //NSOperatingSystemVersion ios8 = (NSOperatingSystemVersion){8,0,1};
    //[[NSProcessInfo processInfo] operatingSystemVersion]
    if([[[UIDevice currentDevice] systemVersion] floatValue]>7)
        successCallback(@[]);
    else
        failCallback(@[]);
}
RCT_EXPORT_METHOD(startAdvertisingService) //failCallback:(RCTResponseSenderBlock)failCallback)
{
    //[self.advtool startAdvertise];
    //[self.tool startScan];
    //successCallback(@[]);
}
RCT_EXPORT_METHOD(stopAdvertisingService) //failCallback:(RCTResponseSenderBlock)failCallback)
{
    //[self.advtool stopAdvertise];
    //[self.tool stopScan];
    //successCallback(@[]);
}
RCT_EXPORT_METHOD(broadcast:(NSString *)data callback:(nonnull RCTResponseSenderBlock)successCallback failCallback:(nonnull RCTResponseSenderBlock)failCallback)
{
    //NSLog(@"broadcast id:%@ :data:", broadcastUuid,data);
    //[self setBroadcastUuid:uuid];
    NSDictionary *advertisingData = @{CBAdvertisementDataServiceUUIDsKey : @[[CBUUID UUIDWithString:[self broadcastUuid]]]};
    [peripheralManager startAdvertising:advertisingData];
    successCallback(@[]);
}
- (void)peripheralManagerDidUpdateState:(CBPeripheralManager *)peripheral{
    NSLog(@"peripheralManagerDidUpdateState");
    switch (peripheral.state) {
        case CBPeripheralManagerStatePoweredOn:{
            CBUUID *cUDID = [CBUUID UUIDWithString:@"DA18"];
            CBUUID *cUDID1 = [CBUUID UUIDWithString:@"DA17"];
            CBUUID *cUDID2 = [CBUUID UUIDWithString:@"DA16"];
            NSString *broadcastUuid = [[NSUUID UUID] UUIDString];
            [self setBroadcastUuid:broadcastUuid];
            CBUUID *sUDID = [CBUUID UUIDWithString:[self broadcastUuid]];
            characteristic = [[CBMutableCharacteristic alloc]initWithType:cUDID properties:CBCharacteristicPropertyNotify value:nil permissions:CBAttributePermissionsReadable];
            characteristic1 = [[CBMutableCharacteristic alloc]initWithType:cUDID1 properties:CBCharacteristicPropertyWrite value:nil permissions:CBAttributePermissionsWriteable];
            characteristic2 = [[CBMutableCharacteristic alloc]initWithType:cUDID2 properties:CBCharacteristicPropertyRead value:nil permissions:CBAttributePermissionsReadable];
            //NSLog(@"%u",characteristic2.properties);
            servicea = [[CBMutableService alloc]initWithType:sUDID primary:YES];
            servicea.characteristics = @[characteristic,characteristic1,characteristic2];
            [peripheral addService:servicea];
        }
            break;
            
        default:
            NSLog(@"%i",peripheral.state);
            break;
    }
}
- (void)peripheralManager:(CBPeripheralManager *)peripheral didAddService:(CBService *)service error:(NSError *)error{
    NSLog(@"Added");
    NSDictionary *advertisingData = @{CBAdvertisementDataLocalNameKey : [[UIDevice currentDevice] name], CBAdvertisementDataServiceUUIDsKey : @[[CBUUID UUIDWithString:[self broadcastUuid]]]};

    [peripheral startAdvertising:advertisingData];
}

- (void)peripheralManagerDidStartAdvertising:(CBPeripheralManager *)peripheral error:(NSError *)error{
    NSLog(@"peripheralManagerDidStartAdvertising");
}

- (void)peripheralManager:(CBPeripheralManager *)peripheral central:(CBCentral *)central didSubscribeToCharacteristic:(CBCharacteristic *)characteristic12{
    NSLog(@"Connected Core:%@",characteristic12.UUID);
    [self writeData:peripheral];
}

- (void)writeData:(CBPeripheralManager *)peripheral{
    NSDictionary *dict = @{ @"NAME" : @"Weixing Sun",@"EMAIL":@"weixing.sun@gmail.com" };
    mainData = [NSJSONSerialization dataWithJSONObject:dict options:kNilOptions error:nil];
    while ([self hasData]) {
        if([peripheral updateValue:[self getNextData] forCharacteristic:characteristic onSubscribedCentrals:nil]){
            [self ridData];
        }else{
            return;
        }
    }
    NSString *stra = @"ENDAL";
    NSData *dataa = [stra dataUsingEncoding:NSUTF8StringEncoding];
    [peripheral updateValue:dataa forCharacteristic:characteristic onSubscribedCentrals:nil];
}
- (void)peripheralManagerIsReadyToUpdateSubscribers:(CBPeripheralManager *)peripheral{
    while ([self hasData]) {
        if([peripheral updateValue:[self getNextData] forCharacteristic:characteristic onSubscribedCentrals:nil]){
            [self ridData];
        }else{
            return;
        }
    }
    NSString *stra = @"ENDAL";
    NSData *dataa = [stra dataUsingEncoding:NSUTF8StringEncoding];
    [peripheral updateValue:dataa forCharacteristic:characteristic onSubscribedCentrals:nil];
}
- (BOOL)hasData{
    if ([mainData length]>0) {
        return YES;
    }else{
        return NO;
    }
}

- (void)ridData{
    if ([mainData length]>19) {
        mainData = [mainData subdataWithRange:NSRangeFromString(range)];
    }else{
        mainData = nil;
    }
}

- (NSData *)getNextData
{
    NSData *data;
    if ([mainData length]>19) {
        int datarest = [mainData length]-20;
        data = [mainData subdataWithRange:NSRangeFromString(@"{0,20}")];
        range = [NSString stringWithFormat:@"{20,%i}",datarest];
    }else{
        int datarest = [mainData length];
        range = [NSString stringWithFormat:@"{0,%i}",datarest];
        data = [mainData subdataWithRange:NSRangeFromString(range)];
    }
    return data;
}
- (void)peripheralManager:(CBPeripheralManager *)peripheral didReceiveReadRequest:(CBATTRequest *)request{
    NSString *mainString = [NSString stringWithFormat:@"GN123"];
    NSData *cmainData= [mainString dataUsingEncoding:NSUTF8StringEncoding];
    request.value = cmainData;
    [peripheral respondToRequest:request withResult:CBATTErrorSuccess];
}

- (void)peripheralManager:(CBPeripheralManager *)peripheral didReceiveWriteRequests:(NSArray *)requests{
    for (CBATTRequest *aReq in requests){
        //NSLog(@"%@",[[NSString alloc]initWithData:aReq.value encoding:NSUTF8StringEncoding]);
        //Log.text = [Log.text stringByAppendingString:[[NSString alloc]initWithData:aReq.value encoding:NSUTF8StringEncoding]];
        //Log.text = [Log.text stringByAppendingString:@"\n"];
        [peripheral respondToRequest:aReq withResult:CBATTErrorSuccess];
    }
}
//////////////////////////////////////////////////////////////////////////////////
//RCT_EXPORT_METHOD(scan:(NSArray *)serviceUUIDStrings timeoutSeconds:(nonnull NSNumber *)timeoutSeconds allowDuplicates:(BOOL)allowDuplicates callback:(nonnull RCTResponseSenderBlock)successCallback)
RCT_EXPORT_METHOD(scan:(NSArray *)serviceUUIDStrings allowDuplicates:(BOOL)allowDuplicates callback:(nonnull RCTResponseSenderBlock)successCallback)
{
    NSLog(@"BleManager.m:scan()");
    /*
    NSArray * services = [RCTConvert NSArray:serviceUUIDStrings];
    NSMutableArray *serviceUUIDs = [NSMutableArray new];
    NSDictionary *options = nil;
    if (allowDuplicates){
        options = [NSDictionary dictionaryWithObject:[NSNumber numberWithBool:YES] forKey:CBCentralManagerScanOptionAllowDuplicatesKey];
    }
    for (int i = 0; i < [services count]; i++) {
        CBUUID *serviceUUID =[CBUUID UUIDWithString:[serviceUUIDStrings objectAtIndex: i]];
        [serviceUUIDs addObject:serviceUUID];
    }
    [manager scanForPeripheralsWithServices:serviceUUIDs options:options];
    */
    [self.tool startScan];
    successCallback(@[]);
}

//-(void)stopScanTimer:(NSTimer *)timer {
RCT_EXPORT_METHOD(stop)
{
    NSLog(@"Stop scan");
    //[manager stopScan];
    [self.tool stopScan];
    [self.bridge.eventDispatcher sendAppEventWithName:@"BleManagerStopScan" body:@{}];
    //successCallback(@[]);
}

- (void)centralManager:(CBCentralManager *)central didDiscoverPeripheral:(CBPeripheral *)peripheral
     advertisementData:(NSDictionary *)advertisementData RSSI:(NSNumber *)RSSI
{
    [peripheral setAdvertisementData:advertisementData RSSI:RSSI];
    [peripherals setValue:peripheral forKey:[peripheral uuidAsString]];
    
    NSLog(@"BleManager.m:didDiscoverPeripheral: %@", [peripheral name]);
    [self.bridge.eventDispatcher
         sendAppEventWithName:@"BleManagerDiscoverPeripheral"
                         body:[peripheral asDictionary]];
    
}

RCT_EXPORT_METHOD(connect:(NSString *)peripheralUUID  successCallback:(nonnull RCTResponseSenderBlock)successCallback failCallback:(nonnull RCTResponseSenderBlock)failCallback)
{
    NSLog(@"connect");
    CBPeripheral *peripheral = [self findPeripheralByUUID:peripheralUUID];
    if (peripheral) {
        NSLog(@"Connecting to peripheral with UUID : %@", peripheralUUID);
        
        [connectCallbacks setObject:successCallback forKey:[peripheral uuidAsString]];
        [manager connectPeripheral:peripheral options:nil];
        
    } else {
        NSString *error = [NSString stringWithFormat:@"Could not find peripheral %@.", peripheralUUID];
        NSLog(@"%@", error);
        failCallback(@[error]);
    }
}

RCT_EXPORT_METHOD(disconnect:(NSString *)peripheralUUID  successCallback:(nonnull RCTResponseSenderBlock)successCallback failCallback:(nonnull RCTResponseSenderBlock)failCallback)
{
    CBPeripheral *peripheral = [self findPeripheralByUUID:peripheralUUID];
    if (peripheral) {
        NSLog(@"Disconnecting from peripheral with UUID : %@", peripheralUUID);
        
        if (peripheral.services != nil) {
            for (CBService *service in peripheral.services) {
                if (service.characteristics != nil) {
                    for (CBCharacteristic *characteristic in service.characteristics) {
                        if (characteristic.isNotifying) {
                            NSLog(@"Remove notification from: %@", characteristic.UUID);
                            [peripheral setNotifyValue:NO forCharacteristic:characteristic];
                        }
                    }
                }
            }
        }
        
        [manager cancelPeripheralConnection:peripheral];
        successCallback(@[]);
        
    } else {
        NSString *error = [NSString stringWithFormat:@"Could not find peripheral %@.", peripheralUUID];
        NSLog(@"%@", error);
        failCallback(@[error]);
    }
}

RCT_EXPORT_METHOD(checkState)
{
    if (manager != nil){
        [self centralManagerDidUpdateState:self.manager];
    }
}

- (void)centralManager:(CBCentralManager *)central didFailToConnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error
{
    NSLog(@"Peripheral connection failure: %@. (%@)", peripheral, [error localizedDescription]);
}

RCT_EXPORT_METHOD(write:(NSString *)deviceUUID serviceUUID:(NSString*)serviceUUID  characteristicUUID:(NSString*)characteristicUUID message:(NSString*)message  successCallback:(nonnull RCTResponseSenderBlock)successCallback failCallback:(nonnull RCTResponseSenderBlock)failCallback)
{
    NSLog(@"Write");
    
    BLECommandContext *context = [self getData:deviceUUID serviceUUIDString:serviceUUID characteristicUUIDString:characteristicUUID prop:CBCharacteristicPropertyWrite failCallback:failCallback];
    
    NSData* dataMessage = [[NSData alloc] initWithBase64EncodedString:message options:0];
    if (context) {
        CBPeripheral *peripheral = [context peripheral];
        CBCharacteristic *characteristic = [context characteristic];
        
        NSString *key = [self keyForPeripheral: peripheral andCharacteristic:characteristic];
        [writeCallbacks setObject:successCallback forKey:key];
        
        //NSLog(@"Message originale(%lu): %@ ", (unsigned long)[dataMessage length], [dataMessage hexadecimalString]);
        RCTLogInfo(@"Message to write(%lu): %@ ", (unsigned long)[dataMessage length], [dataMessage hexadecimalString]);
        if ([dataMessage length] > 20){
            int dataLength = (int)dataMessage.length;
            int count = 0;
            NSData* firstMessage;
            while(count < dataLength && (dataLength - count > 20)){
                if (count == 0){
                    firstMessage = [dataMessage subdataWithRange:NSMakeRange(count, 20)];
                }else{
                    NSData* splitMessage = [dataMessage subdataWithRange:NSMakeRange(count, 20)];
                    [writeQueue addObject:splitMessage];
                }
                count += 20;
            }
            if (count < dataLength) {
                NSData* splitMessage = [dataMessage subdataWithRange:NSMakeRange(count, dataLength - count)];
                [writeQueue addObject:splitMessage];
            }
            NSLog(@"Queued splitted message: %lu", (unsigned long)[writeQueue count]);
            [peripheral writeValue:firstMessage forCharacteristic:characteristic type:CBCharacteristicWriteWithResponse];
        } else {
            [peripheral writeValue:dataMessage forCharacteristic:characteristic type:CBCharacteristicWriteWithResponse];
        }
    }else
        failCallback(@[@"Error"]);
}


RCT_EXPORT_METHOD(writeWithoutResponse:(NSString *)deviceUUID serviceUUID:(NSString*)serviceUUID  characteristicUUID:(NSString*)characteristicUUID message:(NSString*)message  successCallback:(nonnull RCTResponseSenderBlock)successCallback failCallback:(nonnull RCTResponseSenderBlock)failCallback)
{
    NSLog(@"writeWithoutResponse");
    
    BLECommandContext *context = [self getData:deviceUUID serviceUUIDString:serviceUUID characteristicUUIDString:characteristicUUID prop:CBCharacteristicPropertyWriteWithoutResponse failCallback:failCallback];
    
    NSData* dataMessage = [[NSData alloc] initWithBase64EncodedString:message options:0];
    if (context) {
        CBPeripheral *peripheral = [context peripheral];
        CBCharacteristic *characteristic = [context characteristic];
        
        NSLog(@"Message to write(%lu): %@ ", (unsigned long)[dataMessage length], [dataMessage hexadecimalString]);
        /*
         const char bytes[] = {0x00,0x07,0x00,0x03,0x00};
         //const char bytes[] = {0x00,0x07,0x02,0x01,0x00};
         NSMutableData *mMessage = [[NSMutableData alloc] initWithBytes:bytes length:sizeof(bytes)];
         
         
         NSLog(@"Message originale(%lu): %@ ", (unsigned long)[mMessage length], [mMessage hexadecimalString]);
         NSMutableData *crc = [self crc16: mMessage];
         [mMessage appendData:crc];
         
         NSLog(@"Crc: %@", [crc hexadecimalString]);
         
         //NSString *sMessage = [[NSString alloc] initWithData:message encoding:NSASCIIStringEncoding];
         NSLog(@"Message finale(%lu): %@ ", (unsigned long)[mMessage length], [mMessage hexadecimalString]);*/
        
        // TODO need to check the max length
        [peripheral writeValue:dataMessage forCharacteristic:characteristic type:CBCharacteristicWriteWithoutResponse];
        successCallback(@[]);
    }else
        failCallback(@[@"Error"]);
}


RCT_EXPORT_METHOD(read:(NSString *)deviceUUID serviceUUID:(NSString*)serviceUUID  characteristicUUID:(NSString*)characteristicUUID successCallback:(nonnull RCTResponseSenderBlock)successCallback failCallback:(nonnull RCTResponseSenderBlock)failCallback)
{
    NSLog(@"read");
    
    BLECommandContext *context = [self getData:deviceUUID serviceUUIDString:serviceUUID characteristicUUIDString:characteristicUUID prop:CBCharacteristicPropertyRead failCallback:failCallback];
    if (context) {
        
        CBPeripheral *peripheral = [context peripheral];
        CBCharacteristic *characteristic = [context characteristic];
        
        NSString *key = [self keyForPeripheral: peripheral andCharacteristic:characteristic];
        [readCallbacks setObject:successCallback forKey:key];
        
        [peripheral readValueForCharacteristic:characteristic];  // callback sends value
    }
    
}

RCT_EXPORT_METHOD(startNotification:(NSString *)deviceUUID serviceUUID:(NSString*)serviceUUID  characteristicUUID:(NSString*)characteristicUUID successCallback:(nonnull RCTResponseSenderBlock)successCallback failCallback:(nonnull RCTResponseSenderBlock)failCallback)
{
    NSLog(@"startNotification");
    
    BLECommandContext *context = [self getData:deviceUUID serviceUUIDString:serviceUUID characteristicUUIDString:characteristicUUID prop:CBCharacteristicPropertyNotify failCallback:failCallback];
    
    if (context) {
        CBPeripheral *peripheral = [context peripheral];
        CBCharacteristic *characteristic = [context characteristic];
        
        NSString *key = [self keyForPeripheral: peripheral andCharacteristic:characteristic];
        [notificationCallbacks setObject: successCallback forKey: key];
        
        [peripheral setNotifyValue:YES forCharacteristic:characteristic];
    }
    
}

RCT_EXPORT_METHOD(stopNotification:(NSString *)deviceUUID serviceUUID:(NSString*)serviceUUID  characteristicUUID:(NSString*)characteristicUUID successCallback:(nonnull RCTResponseSenderBlock)successCallback failCallback:(nonnull RCTResponseSenderBlock)failCallback)
{
    NSLog(@"stopNotification");
    
    BLECommandContext *context = [self getData:deviceUUID serviceUUIDString:serviceUUID characteristicUUIDString:characteristicUUID prop:CBCharacteristicPropertyNotify failCallback:failCallback];
    
    if (context) {
        CBPeripheral *peripheral = [context peripheral];
        CBCharacteristic *characteristic = [context characteristic];
        
        NSString *key = [self keyForPeripheral: peripheral andCharacteristic:characteristic];
        [stopNotificationCallbacks setObject: successCallback forKey: key];
        
        if ([characteristic isNotifying]){
            [peripheral setNotifyValue:NO forCharacteristic:characteristic];
            NSLog(@"Characteristic stopped notifying");
        } else {
            NSLog(@"Characteristic is not notifying");
        }
        
    }
    
}


- (void)peripheral:(CBPeripheral *)peripheral didWriteValueForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error {
    NSLog(@"didWrite");
    
    NSString *key = [self keyForPeripheral: peripheral andCharacteristic:characteristic];
    RCTResponseSenderBlock writeCallback = [writeCallbacks objectForKey:key];
    
    if (writeCallback) {
        if (error) {
            NSLog(@"%@", error);
        } else {
            if ([writeQueue count] == 0) {
                writeCallback(@[@""]);
                [writeCallbacks removeObjectForKey:key];
            }else{
                // Rimuovo messaggio da coda e scrivo
                NSData *message = [writeQueue objectAtIndex:0];
                [writeQueue removeObjectAtIndex:0];
                //NSLog(@"Rimangono in coda: %i", [writeQueue count]);
                //NSLog(@"Scrivo messaggio (%lu): %@ ", (unsigned long)[message length], [message hexadecimalString]);
                [peripheral writeValue:message forCharacteristic:characteristic type:CBCharacteristicWriteWithResponse];
            }
            
        }
    }
    
}


- (void)centralManager:(CBCentralManager *)central didConnectPeripheral:(CBPeripheral *)peripheral
{
    NSLog(@"Peripheral Connected: %@", [peripheral uuidAsString]);
    peripheral.delegate = self;
    [peripheral discoverServices:nil];
}

- (void)centralManager:(CBCentralManager *)central didDisconnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error {
    NSLog(@"Peripheral Disconnected: %@", [peripheral uuidAsString]);
    if (error) {
        NSLog(@"Error: %@", error);
    }
    [self.bridge.eventDispatcher sendAppEventWithName:@"BleManagerDisconnectPeripheral" body:@{@"peripheral": [peripheral uuidAsString]}];
}

- (void)peripheral:(CBPeripheral *)peripheral didDiscoverServices:(NSError *)error {
    if (error) {
        NSLog(@"Error: %@", error);
        return;
    }
    NSLog(@"Services Discover");
    
    NSMutableSet *servicesForPeriperal = [NSMutableSet new];
    [servicesForPeriperal addObjectsFromArray:peripheral.services];
    [connectCallbackLatches setObject:servicesForPeriperal forKey:[peripheral uuidAsString]];
    for (CBService *service in peripheral.services) {
        NSLog(@"Servizio %@ %@", service.UUID, service.description);
        [peripheral discoverCharacteristics:nil forService:service]; // discover all is slow
    }
}

- (void)peripheral:(CBPeripheral *)peripheral didDiscoverCharacteristicsForService:(CBService *)service error:(NSError *)error {
    if (error) {
        NSLog(@"Error: %@", error);
        return;
    }
    NSLog(@"Characteristics For Service Discover");
    
    NSString *peripheralUUIDString = [peripheral uuidAsString];
    RCTResponseSenderBlock connectCallback = [connectCallbacks valueForKey:peripheralUUIDString];
    NSMutableSet *latch = [connectCallbackLatches valueForKey:peripheralUUIDString];
    [latch removeObject:service];
    
    if ([latch count] == 0) {
        // Call success callback for connect
        if (connectCallback) {
            connectCallback(@[[peripheral asDictionary]]);
        }
        [connectCallbackLatches removeObjectForKey:peripheralUUIDString];
    }
    
    /*
     NSLog(@"Found characteristics for service %@", service);
     for (CBCharacteristic *characteristic in service.characteristics) {
     NSLog(@"Characteristic %@", characteristic);
     }*/
    
}

// Find a characteristic in service with a specific property
-(CBCharacteristic *) findCharacteristicFromUUID:(CBUUID *)UUID service:(CBService*)service prop:(CBCharacteristicProperties)prop
{
    NSLog(@"Looking for %@ with properties %lu", UUID, (unsigned long)prop);
    for(int i=0; i < service.characteristics.count; i++)
    {
        CBCharacteristic *c = [service.characteristics objectAtIndex:i];
        if ((c.properties & prop) != 0x0 && [c.UUID.UUIDString isEqualToString: UUID.UUIDString]) {
            NSLog(@"Found %@", UUID);
            return c;
        }
    }
    return nil; //Characteristic with prop not found on this service
}

// Find a characteristic in service by UUID
-(CBCharacteristic *) findCharacteristicFromUUID:(CBUUID *)UUID service:(CBService*)service
{
    NSLog(@"Looking for %@", UUID);
    for(int i=0; i < service.characteristics.count; i++)
    {
        CBCharacteristic *c = [service.characteristics objectAtIndex:i];
        if ([c.UUID.UUIDString isEqualToString: UUID.UUIDString]) {
            NSLog(@"Found %@", UUID);
            return c;
        }
    }
    return nil; //Characteristic not found on this service
}

- (void)centralManagerDidUpdateState:(CBCentralManager *)central
{
    NSString *stateName = [self centralManagerStateToString:central.state];
    [self setState:central.state];
    [self.bridge.eventDispatcher sendAppEventWithName:@"BleManagerDidUpdateState" body:@{@"state":stateName}];
}

// expecting deviceUUID, serviceUUID, characteristicUUID in command.arguments
-(BLECommandContext*) getData:(NSString*)deviceUUIDString  serviceUUIDString:(NSString*)serviceUUIDString characteristicUUIDString:(NSString*)characteristicUUIDString prop:(CBCharacteristicProperties)prop failCallback:(nonnull RCTResponseSenderBlock)failCallback
{
    CBUUID *serviceUUID = [CBUUID UUIDWithString:serviceUUIDString];
    CBUUID *characteristicUUID = [CBUUID UUIDWithString:characteristicUUIDString];
    
    CBPeripheral *peripheral = [self findPeripheralByUUID:deviceUUIDString];
    
    if (!peripheral) {
        NSString* err = [NSString stringWithFormat:@"Could not find peripherial with UUID %@", deviceUUIDString];
        NSLog(@"Could not find peripherial with UUID %@", deviceUUIDString);
        failCallback(@[err]);
        
        return nil;
    }
    
    CBService *service = [self findServiceFromUUID:serviceUUID p:peripheral];
    
    if (!service)
    {
        NSString* err = [NSString stringWithFormat:@"Could not find service with UUID %@ on peripheral with UUID %@",
                         serviceUUIDString,
                         peripheral.identifier.UUIDString];
        NSLog(@"Could not find service with UUID %@ on peripheral with UUID %@",
              serviceUUIDString,
              peripheral.identifier.UUIDString);
        failCallback(@[err]);
        return nil;
    }
    
    CBCharacteristic *characteristic = [self findCharacteristicFromUUID:characteristicUUID service:service prop:prop];
    
    // Special handling for INDICATE. If charateristic with notify is not found, check for indicate.
    if (prop == CBCharacteristicPropertyNotify && !characteristic) {
        characteristic = [self findCharacteristicFromUUID:characteristicUUID service:service prop:CBCharacteristicPropertyIndicate];
    }
    
    // As a last resort, try and find ANY characteristic with this UUID, even if it doesn't have the correct properties
    if (!characteristic) {
        characteristic = [self findCharacteristicFromUUID:characteristicUUID service:service];
    }
    
    if (!characteristic)
    {
        NSString* err = [NSString stringWithFormat:@"Could not find characteristic with UUID %@ on service with UUID %@ on peripheral with UUID %@", characteristicUUIDString,serviceUUIDString, peripheral.identifier.UUIDString];
        NSLog(@"Could not find characteristic with UUID %@ on service with UUID %@ on peripheral with UUID %@",
              characteristicUUIDString,
              serviceUUIDString,
              peripheral.identifier.UUIDString);
        failCallback(@[err]);
        return nil;
    }
    
    BLECommandContext *context = [[BLECommandContext alloc] init];
    [context setPeripheral:peripheral];
    [context setService:service];
    [context setCharacteristic:characteristic];
    return context;
    
}

-(NSString *) keyForPeripheral: (CBPeripheral *)peripheral andCharacteristic:(CBCharacteristic *)characteristic {
    return [NSString stringWithFormat:@"%@|%@", [peripheral uuidAsString], [characteristic UUID]];
}

#pragma mark - STCentralToolDelegate
- (void)centralTool:(STCentralTool *)centralTool findAPeripheral:(CBPeripheral *)peripheral{
    //NSLog(@"BleManager.m:findAPeripheral%@",[peripheral name]);
    //[self.tool selectPeripheral:[peripherals firstObject]];
    //[peripheral setAdvertisementData:advertisementData RSSI:RSSI];
    //NSLog(@"Discover peripheral: %@", [peripheral name]);
    [self.bridge.eventDispatcher sendAppEventWithName:@"BleManagerDiscoverPeripheral" body:[peripheral asDictionary]];
}
- (void)centralTool:(STCentralTool *)centralTool connectFailure:(NSError *)error {
    NSLog(@"连接错误 ---- %@", error);
}

- (void)centralTool:(STCentralTool *)centralTool connectSuccess:(CBPeripheral *)peripheral {
    NSLog(@"连接成功 ---- %@", peripheral);
}

- (void)centralTool:(STCentralTool *)centralTool disconnectPeripheral:(CBPeripheral *)peripheral {
    NSLog(@"准备断开连接");
}

- (void)centralTool:(STCentralTool *)centralTool recievedData:(NSData *)data {
    NSLog(@"收到数据 ---- %@", data);
}

#pragma mark - STCentralToolOTADelegate

- (void)centralTool:(STCentralTool *)centralTool otaWriteFinishWithError:(NSError *)error {
    NSLog(@"传输完成，有错吗  ----- %@", error);
}

- (void)centralTool:(STCentralTool *)centralTool otaWriteLength:(NSInteger)length {
    NSLog(@"已经传了这么长了啊 ------  %ld", length);
}

@end
