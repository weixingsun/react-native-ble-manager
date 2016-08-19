#import "CBPeripheral+Extensions.h"

static char ADVERTISING_IDENTIFER;
static char ADVERTISEMENT_RSSI_IDENTIFER;

@implementation NSData (NSData_Conversion)

#pragma mark - String Conversion
- (NSString *)hexadecimalString
{
    /* Returns hexadecimal string of NSData. Empty string if data is empty.   */

    const unsigned char *dataBuffer = (const unsigned char *)[self bytes];

    if (!dataBuffer)
    {
        return [NSString string];
    }

    NSUInteger          dataLength  = [self length];
    NSMutableString     *hexString  = [NSMutableString stringWithCapacity:(dataLength * 2)];

    for (int i = 0; i < dataLength; ++i)
    {
        [hexString appendFormat:@"%02x", (unsigned int)dataBuffer[i]];
    }

    return [NSString stringWithString:hexString];
}
@end
@implementation CBPeripheral(com_megster_ble_extension)

-(NSString *)uuidAsString {
  if (self.identifier.UUIDString) {
    return self.identifier.UUIDString;
  } else {
    return @"";
  }
}


-(NSDictionary *)asDictionary {
  //NSLog(@"%@", [self class]);
  NSString *uuidString = NULL;
  if (self.identifier.UUIDString) {
    //NSLog(@"%@", self.identifier);
    uuidString = self.identifier.UUIDString;
  } else {
    uuidString = @"";
  }
  
  NSMutableDictionary *dictionary = [NSMutableDictionary dictionary];
  [dictionary setObject: uuidString forKey: @"id"];
  
  if ([self name]) {
    [dictionary setObject: [self name] forKey: @"name"];
  }
  
  
  if ([self RSSI]) {
    [dictionary setObject: [self RSSI] forKey: @"rssi"];
  } else if ([self advertisementRSSI]) {
    [dictionary setObject: [self advertisementRSSI] forKey: @"rssi"];
  }
  
  if ([self advertising]) {
      NSDictionary *advertising = [self advertising];
      if ([advertising objectForKey:@"kCBAdvDataIsConnectable"]) {
          [dictionary setObject: [advertising objectForKey:@"kCBAdvDataIsConnectable"] forKey: @"connectable"];
      }
      if ([advertising objectForKey:@"kCBAdvDataTxPowerLevel"]) {
          [dictionary setObject: [advertising objectForKey:@"kCBAdvDataTxPowerLevel"] forKey: @"tx_power_level"];
      }
      NSDictionary *mfg = [advertising objectForKey:CBAdvertisementDataManufacturerDataKey];
      if (mfg) {
          NSMutableDictionary *mfg_dict = [[NSMutableDictionary alloc] init];
          if([mfg objectForKey:@"data"]){
              NSString *rawMfg = [mfg objectForKey:@"data"];
              //NSLog(@"mfg: %@ ", rawMfg);
              NSString *mfgStringRevId = [rawMfg substringToIndex:4];  //0xE000 -> 00E0
              NSString *mfg1 = [mfgStringRevId substringWithRange:NSMakeRange(2, 2)];
              NSString *mfg2 = [mfgStringRevId substringToIndex:2];
              NSString *mfgStringId = [NSString stringWithFormat:@"%@%@", mfg1, mfg2];
              //NSLog(@"mfg_id: %@ ", mfgStringId);
              unsigned mfgid = 0;
              [[NSScanner scannerWithString:mfgStringId] scanHexInt:&mfgid];
              NSString *data = [rawMfg substringWithRange:NSMakeRange(4, [rawMfg length]-4)];
              NSLog(@"mfg_id: %@ data: %@", mfgStringId,data);
              [mfg_dict setValue:data forKey:@"data"];
              [mfg_dict setValue:[NSNumber numberWithInt:mfgid] forKey:@"id"];
          }
          [dictionary setObject:mfg_dict forKey: @"mfg"];
      }
      NSDictionary *serviceUUIDs = [advertising objectForKey:CBAdvertisementDataServiceUUIDsKey];
      NSDictionary *serviceData  = [advertising objectForKey:CBAdvertisementDataServiceDataKey];
      if (serviceUUIDs && serviceData){
          NSMutableDictionary *services = [[NSMutableDictionary alloc] init];
          for(CBUUID *key in serviceData) {
              NSDictionary *rawData = [serviceData objectForKey:key];
              [services setValue:key forKey:@"uuid"];
              [services setValue:[rawData objectForKey:@"data"] forKey:@"data"];
          }
          [dictionary setObject:services forKey: @"services"];
      }
      [dictionary setObject: [self advertising] forKey: @"advertising"];
  }
  
  if([[self services] count] > 0) {
    [self serviceAndCharacteristicInfo: dictionary];
  }
  
  return dictionary;
  
}

// AdvertisementData is from didDiscoverPeripheral. RFduino advertises a service name in the Mfg Data Field.
-(void)setAdvertisementData:(NSDictionary *)advertisementData RSSI:(NSNumber *)rssi{
  
  [self setAdvertising:[self serializableAdvertisementData: advertisementData]];
  [self setAdvertisementRSSI: rssi];
  
}

// Translates the Advertisement Data from didDiscoverPeripheral into a structure that can be serialized as JSON
//
// This version keeps the iOS constants for keys, future versions could create more friendly keys
//
// Advertisement Data from a Peripheral could look something like
//
// advertising = {
//     kCBAdvDataChannel = 39;
//     kCBAdvDataIsConnectable = 1;
//     kCBAdvDataLocalName = foo;
//     kCBAdvDataManufacturerData = {
//         CDVType = ArrayBuffer;
//         data = "AABoZWxsbw==";
//         data = "0000BEAC010203040506070809";
//     };
//     kCBAdvDataServiceData = {
//         FED8 = {
//             CDVType = ArrayBuffer;
//             data = "ACAAYWJjBw==";
//         };
//     };
//     kCBAdvDataServiceUUIDs = (
//         FED8
//     );
//     kCBAdvDataTxPowerLevel = 32;
//};
- (NSDictionary *) serializableAdvertisementData: (NSDictionary *) advertisementData {
  
  NSMutableDictionary *dict = [advertisementData mutableCopy];
  
  // Service Data is a dictionary of CBUUID and NSData
  // Convert to String keys with Array Buffer values
  NSMutableDictionary *serviceData = [dict objectForKey:CBAdvertisementDataServiceDataKey];
  if (serviceData) {
    //NSLog(@"%@", serviceData);
    
    for(CBUUID *key in serviceData) {
      [serviceData setObject:dataToArrayBuffer([serviceData objectForKey:key]) forKey:[key UUIDString]];
      [serviceData removeObjectForKey:key];
    }
  }
  
  // Create a new list of Service UUIDs as Strings instead of CBUUIDs
  NSMutableArray *serviceUUIDs = [dict objectForKey:CBAdvertisementDataServiceUUIDsKey];
  NSMutableArray *serviceUUIDStrings;
  if (serviceUUIDs) {
    serviceUUIDStrings = [[NSMutableArray alloc] initWithCapacity:serviceUUIDs.count];
    
    for (CBUUID *uuid in serviceUUIDs) {
      [serviceUUIDStrings addObject:[uuid UUIDString]];
    }
    
    // replace the UUID list with list of strings
    [dict removeObjectForKey:CBAdvertisementDataServiceUUIDsKey];
    [dict setObject:serviceUUIDStrings forKey:CBAdvertisementDataServiceUUIDsKey];
    
  }
  
  // Solicited Services UUIDs is an array of CBUUIDs, convert into Strings
  NSMutableArray *solicitiedServiceUUIDs = [dict objectForKey:CBAdvertisementDataSolicitedServiceUUIDsKey];
  NSMutableArray *solicitiedServiceUUIDStrings;
  if (solicitiedServiceUUIDs) {
    // NSLog(@"%@", solicitiedServiceUUIDs);
    solicitiedServiceUUIDStrings = [[NSMutableArray alloc] initWithCapacity:solicitiedServiceUUIDs.count];
    
    for (CBUUID *uuid in solicitiedServiceUUIDs) {
      [solicitiedServiceUUIDStrings addObject:[uuid UUIDString]];
    }
    
    // replace the UUID list with list of strings
    [dict removeObjectForKey:CBAdvertisementDataSolicitedServiceUUIDsKey];
    [dict setObject:solicitiedServiceUUIDStrings forKey:CBAdvertisementDataSolicitedServiceUUIDsKey];
  }
  
  // Convert the manufacturer data
  NSData *mfgData = [dict objectForKey:CBAdvertisementDataManufacturerDataKey];
  if (mfgData) {
    [dict setObject:dataToArrayBuffer([dict objectForKey:CBAdvertisementDataManufacturerDataKey]) forKey:CBAdvertisementDataManufacturerDataKey];
  }
  
  return dict;
}

// Put the service, characteristic, and descriptor data in a format that will serialize through JSON
// sending a list of services and a list of characteristics
- (void) serviceAndCharacteristicInfo: (NSMutableDictionary *) info {
  
  NSMutableArray *serviceList = [NSMutableArray new];
  NSMutableArray *characteristicList = [NSMutableArray new];
  
  // This can move into the CBPeripherial Extension
  for (CBService *service in [self services]) {
    [serviceList addObject:[[service UUID] UUIDString]];
    for (CBCharacteristic *characteristic in service.characteristics) {
      NSMutableDictionary *characteristicDictionary = [NSMutableDictionary new];
      [characteristicDictionary setObject:[[service UUID] UUIDString] forKey:@"service"];
      [characteristicDictionary setObject:[[characteristic UUID] UUIDString] forKey:@"characteristic"];
      
      if ([characteristic value]) {
        [characteristicDictionary setObject:dataToArrayBuffer([characteristic value]) forKey:@"value"];
      }
      if ([characteristic properties]) {
        //[characteristicDictionary setObject:[NSNumber numberWithInt:[characteristic properties]] forKey:@"propertiesValue"];
        [characteristicDictionary setObject:[self decodeCharacteristicProperties:characteristic] forKey:@"properties"];
      }
      // permissions only exist on CBMutableCharacteristics
      [characteristicDictionary setObject:[NSNumber numberWithBool:[characteristic isNotifying]] forKey:@"isNotifying"];
      [characteristicList addObject:characteristicDictionary];
      
      // descriptors always seem to be nil, probably a bug here
      NSMutableArray *descriptorList = [NSMutableArray new];
      for (CBDescriptor *descriptor in characteristic.descriptors) {
        NSMutableDictionary *descriptorDictionary = [NSMutableDictionary new];
        [descriptorDictionary setObject:[[descriptor UUID] UUIDString] forKey:@"descriptor"];
        if ([descriptor value]) { // should always have a value?
          [descriptorDictionary setObject:[descriptor value] forKey:@"value"];
        }
        [descriptorList addObject:descriptorDictionary];
      }
      if ([descriptorList count] > 0) {
        [characteristicDictionary setObject:descriptorList forKey:@"descriptors"];
      }
      
    }
  }
  
  [info setObject:serviceList forKey:@"services"];
  [info setObject:characteristicList forKey:@"characteristics"];
  
}

-(NSArray *) decodeCharacteristicProperties: (CBCharacteristic *) characteristic {
  NSMutableArray *props = [NSMutableArray new];
  
  CBCharacteristicProperties p = [characteristic properties];
  
  // NOTE: props strings need to be consistent across iOS and Android
  if ((p & CBCharacteristicPropertyBroadcast) != 0x0) {
    [props addObject:@"Broadcast"];
  }
  
  if ((p & CBCharacteristicPropertyRead) != 0x0) {
    [props addObject:@"Read"];
  }
  
  if ((p & CBCharacteristicPropertyWriteWithoutResponse) != 0x0) {
    [props addObject:@"WriteWithoutResponse"];
  }
  
  if ((p & CBCharacteristicPropertyWrite) != 0x0) {
    [props addObject:@"Write"];
  }
  
  if ((p & CBCharacteristicPropertyNotify) != 0x0) {
    [props addObject:@"Notify"];
  }
  
  if ((p & CBCharacteristicPropertyIndicate) != 0x0) {
    [props addObject:@"Indicate"];
  }
  
  if ((p & CBCharacteristicPropertyAuthenticatedSignedWrites) != 0x0) {
    [props addObject:@"AutheticateSignedWrites"];
  }
  
  if ((p & CBCharacteristicPropertyExtendedProperties) != 0x0) {
    [props addObject:@"ExtendedProperties"];
  }
  
  if ((p & CBCharacteristicPropertyNotifyEncryptionRequired) != 0x0) {
    [props addObject:@"NotifyEncryptionRequired"];
  }
  
  if ((p & CBCharacteristicPropertyIndicateEncryptionRequired) != 0x0) {
    [props addObject:@"IndicateEncryptionRequired"];
  }
  
  return props;
}

// Borrowed from Cordova messageFromArrayBuffer since Cordova doesn't handle NSData in NSDictionary
id dataToArrayBuffer(NSData* data)
{
  return @{
           @"CDVType" : @"ArrayBuffer",
           //@"data" :[data base64EncodedStringWithOptions:0]
           @"data" :[data hexadecimalString]
           };
}


-(void)setAdvertising:(NSDictionary *)newAdvertisingValue{
  objc_setAssociatedObject(self, &ADVERTISING_IDENTIFER, newAdvertisingValue, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

-(NSString*)advertising{
  return objc_getAssociatedObject(self, &ADVERTISING_IDENTIFER);
}


-(void)setAdvertisementRSSI:(NSNumber *)newAdvertisementRSSIValue {
  objc_setAssociatedObject(self, &ADVERTISEMENT_RSSI_IDENTIFER, newAdvertisementRSSIValue, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

-(NSString*)advertisementRSSI{
  return objc_getAssociatedObject(self, &ADVERTISEMENT_RSSI_IDENTIFER);
}

@end
