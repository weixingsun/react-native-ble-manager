//
//  STPeripheral.h
//  BleManager
//
//  Created by Sun on 8/24/16.
//  Copyright © 2016 Facebook. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreBluetooth/CoreBluetooth.h>
@class STPeripheralTool;

//static NSString * const STCentralErrorConnectTimeOut = @"time out";

@protocol STPeripheralToolDelegate <NSObject>

@optional
/*
// 找到 Central
- (void)peripheralTool:(STPeripheralTool *)peripheralTool findACentral:(CBCentral *)central;
// 连接失败（包括超时、连接错误等）
- (void)centralTool:(STCentralTool *)centralTool connectFailure:(NSError *)error;

// 连接成功（仅仅是 Peripheral 连接成功，如果内部的 Service 或者 Characteristic 连接失败，会走失败代理）
- (void)centralTool:(STCentralTool *)centralTool connectSuccess:(CBPeripheral *)peripheral;

// 断开连接（准备断开就会走这个方法，具体是否真正断开要看苹果底层的实现，如果有其他 app 正连接着，不会断开）
- (void)centralTool:(STCentralTool *)centralTool disconnectPeripheral:(CBPeripheral *)peripheral;

// 收到 Peripheral 发过来的数据
- (void)centralTool:(STCentralTool *)centralTool recievedData:(NSData *)data;

// 写入 Peripheral 结束，如果错误则返回 error
- (void)centralTool:(STCentralTool *)centralTool writeFinishWithError:(NSError *)error;
*/
@end

//@protocol STCentralToolOTADelegate <NSObject>

@optional
/*
// ota 发送已写入的数据长度，可用于做进度条
- (void)centralTool:(STCentralTool *)centralTool otaWriteLength:(NSInteger)length;

// ota 写入完毕，也有可能是中途出错退出，可通过判断 error 来得到结果
- (void)centralTool:(STCentralTool *)centralTool otaWriteFinishWithError:(NSError *)error;
*/
@end

@interface STPeripheralTool : NSObject

@property (weak, nonatomic) id<STPeripheralToolDelegate, STPeripheralToolOTADelegate> delegate;
@property (assign, nonatomic) BOOL isConnected; ///< 当前是否是连接状态
@property (strong, nonatomic, readonly) CBCharacteristic *writeCharacteristic; ///< 需要写入的 chaeacteristic，因为有可能不止一个需要写入，所以在写入数据时，需要外部处理要写入哪一个

+ (instancetype)shareInstence;

// 开始扫描
- (void)startAdvertise;

// 停止扫描
- (void)stopAdvertise;

// 选择一个 Peripheral
//- (void)selectPeripheral:(CBPeripheral *)peripheral;

// 断开连接
//- (void)disconnectWithPeripheral:(CBPeripheral *)peripheral;

// 发送普通数据，一般用于简单的命令
//- (void)sendData:(NSData *)data toCharacteristic:(CBCharacteristic *)toCharacteristic;

// 发送 OTA 数据，也可用于文件传输，默认 20 byte 一发
//- (void)otaUpdateData:(NSData *)data toCharacteristic:(CBCharacteristic *)toCharacteristic;

@end
