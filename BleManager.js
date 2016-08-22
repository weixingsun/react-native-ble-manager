'use strict';
var React = require('react-native');
var bleManager = React.NativeModules.BleManager;

class BleManager  {

  read(peripheralId, serviceUUID, characteristicUUID) {
    return new Promise((fulfill, reject) => {
      bleManager.read(peripheralId, serviceUUID, characteristicUUID, (success) => {
        fulfill(success);
      }, (fail) => {
        reject(fail);
      });
    });
  }

  write(peripheralId, serviceUUID, characteristicUUID, data) {
    return new Promise((fulfill, reject) => {
      bleManager.write(peripheralId, serviceUUID, characteristicUUID, data, (success) => {
        fulfill();
      }, (fail) => {
        reject(fail);
      });
    });
  }

  connect(peripheralId) {
    return new Promise((fulfill, reject) => {
      bleManager.connect(peripheralId,(success) => {
        fulfill();
      }, (fail) => {
        reject(fail);
      });
    });
  }

  disconnect(peripheralId) {
    return new Promise((fulfill, reject) => {
      bleManager.disconnect(peripheralId,(success) => {
        fulfill();
      }, (fail) => {
        reject(fail);
      });
    });
  }

  startNotification(peripheralId, serviceUUID, characteristicUUID) {
    return new Promise((fulfill, reject) => {
      bleManager.startNotification(peripheralId, serviceUUID, characteristicUUID, (success) => {
        fulfill();
      }, (fail) => {
        reject(fail);
      });
    });
  }

  stopNotification(peripheralId, serviceUUID, characteristicUUID) {
    return new Promise((fulfill, reject) => {
      bleManager.stopNotification(peripheralId, serviceUUID, characteristicUUID, (success) => {
        fulfill();
      }, (fail) => {
        reject(fail);
      });
    });
  }

  checkState() {
    bleManager.checkState();
  }

  scan(serviceUUIDs, allowDuplicates) {
    return new Promise((fulfill, reject) => {
      if (allowDuplicates == null) {
        allowDuplicates = false;
      }
      bleManager.scan(serviceUUIDs, allowDuplicates, (success) => {
        fulfill();
      });
    });
  }

  stop(){
     bleManager.stop();
  }
  
  broadcast(id,data){
    return new Promise((fulfill, reject) => {
      bleManager.broadcast(id,data, (success) => {
        fulfill();
      }, (fail) => {
        reject(fail);
      });
    });
  }

  isEnabled(){
    return bleManager.isEnabled()
  }

  startAdvertisingService(){
    bleManager.startAdvertisingService();
  }
  stopAdvertisingService(){
    bleManager.stopAdvertisingService();
  }
}

module.exports = new BleManager();
