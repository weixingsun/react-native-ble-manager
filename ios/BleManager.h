#import "RCTBridgeModule.h"
#import <CoreBluetooth/CoreBluetooth.h>
#import "STCentralTool.h"

@interface BleManager : NSObject <RCTBridgeModule, CBCentralManagerDelegate, CBPeripheralDelegate>{
    NSString* discoverPeripherialCallbackId;
    NSMutableDictionary* connectCallbacks;
    NSMutableDictionary *readCallbacks;
    NSMutableDictionary *writeCallbacks;
    NSMutableArray *writeQueue;
    NSMutableDictionary *notificationCallbacks;
    NSMutableDictionary *stopNotificationCallbacks;
    NSMutableDictionary *connectCallbackLatches;
    NSTimer *advTimer;
}

@property (strong, nonatomic) NSMutableDictionary *peripherals;
@property (strong, nonatomic) CBCentralManager *manager;
@property (strong, nonatomic) CBPeripheralManager *peripheralManager;
@property (strong, nonatomic) NSString *broadcastUuid;
@property (nonatomic) CBCentralManagerState *state;
@property (strong, nonatomic) STCentralTool *tool;

-(void)timerAction:(NSTimer *)timer;

@end
