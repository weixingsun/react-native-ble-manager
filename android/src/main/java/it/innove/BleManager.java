package it.innove;

import android.bluetooth.*;
import android.bluetooth.le.*;
import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.content.IntentFilter;
import android.os.*;
import android.support.annotation.Nullable;
import android.util.Base64;
import android.util.Log;
import com.facebook.react.bridge.*;
import com.facebook.react.modules.core.RCTNativeAppEventEmitter;
import org.json.JSONException;

import java.util.*;
import java.nio.charset.*;

import static android.os.Build.VERSION_CODES.LOLLIPOP;
import static com.facebook.react.bridge.UiThreadUtil.runOnUiThread;


class BleManager extends ReactContextBaseJavaModule {

	private static final String LOG_TAG = "BLE_MANAGER";


	private BluetoothAdapter bluetoothAdapter;
	private Context context;
	private ReactContext reactContext;
        private BluetoothLeScanner scanner;
        //private BluetoothLeAdvertiser advertiser;
        //private AdvertiseSettings advSettings;
	// key is the MAC Address
	private Map<String, Peripheral> peripherals = new LinkedHashMap<>();


	public BleManager(ReactApplicationContext reactContext) {
		super(reactContext);
		context = reactContext;
                scanner = getBluetoothAdapter().getBluetoothLeScanner();
                //advertiser = BluetoothAdapter.getDefaultAdapter().getBluetoothLeAdvertiser();
                //advertiser = getBluetoothAdapter().getBluetoothLeAdvertiser();
                //Log.e(LOG_TAG, "BLE.isMultipleAdvertisementSupported:"+BluetoothAdapter.getDefaultAdapter().isMultipleAdvertisementSupported());
		this.reactContext = reactContext;

		Log.d(LOG_TAG, "BleManager initialized");

		IntentFilter filter = new IntentFilter(BluetoothAdapter.ACTION_STATE_CHANGED);
		context.registerReceiver(mReceiver, filter);
	}

	@Override
	public String getName() {
		return "BleManager";
	}

	private BluetoothAdapter getBluetoothAdapter() {
		if (bluetoothAdapter == null) {
			BluetoothManager manager = (BluetoothManager) context.getSystemService(Context.BLUETOOTH_SERVICE);
			bluetoothAdapter = manager.getAdapter();
		}
		return bluetoothAdapter;
	}

	private void sendEvent(String eventName, @Nullable WritableMap params) {
		getReactApplicationContext()
				.getJSModule(RCTNativeAppEventEmitter.class)
				.emit(eventName, params);
	}
        private Intent getServiceIntent() {
            return new Intent(getReactApplicationContext(), AdvertiserService.class);
        }
        @ReactMethod
        public void isEnabled(Callback successCallback,Callback failCallback){
            boolean enabled = getBluetoothAdapter().isEnabled();
            if(enabled) successCallback.invoke(enabled);
            else failCallback.invoke(enabled);
        }
        @ReactMethod
        public void isAdvertisingSupported(Callback successCallback, Callback failCallback){
            boolean supported = getBluetoothAdapter().isMultipleAdvertisementSupported();
            if(supported) successCallback.invoke(supported);
            else failCallback.invoke(supported);
        }

	@ReactMethod
        public void startAdvertisingService() {
            Context c = getReactApplicationContext();
            c.startService(new Intent(c,AdvertiserService.class));
            WritableMap map = Arguments.createMap();
            sendEvent("BleManagerStartAdvertisingService", map);
        }

	@ReactMethod
        public void stopAdvertisingService() {
            Context c = getReactApplicationContext();
            c.stopService(new Intent(c,AdvertiserService.class));
            WritableMap map = Arguments.createMap();
            sendEvent("BleManagerStopAdvertisingService", map);
        }
	@ReactMethod
	public void broadcast(String id, String data, Callback successCallback, Callback failCallback) {
            boolean support = BluetoothAdapter.getDefaultAdapter().isMultipleAdvertisementSupported();
            if(!support){
                failCallback.invoke();
            }else{
                ParcelUuid pUuid = new ParcelUuid( UUID.fromString( id ) );
                AdvertiseData advData = new AdvertiseData.Builder()
                  .setIncludeDeviceName( true )
                  .addServiceUuid( pUuid )
                  .addServiceData( pUuid, data.getBytes( Charset.forName( "UTF-8" ) ) )
                  .build();
                AdvertiseCallback advertisingCallback = new AdvertiseCallback() {
                  @Override
                  public void onStartSuccess(AdvertiseSettings settingsInEffect) {
                    super.onStartSuccess(settingsInEffect);
                  }
                  @Override
                  public void onStartFailure(int errorCode) {
                    Log.e( "BLE", "Advertising onStartFailure: " + errorCode );
                    super.onStartFailure(errorCode);
                  }
                };
                AdvertiseSettings advSettings = new AdvertiseSettings.Builder()
                  .setAdvertiseMode( AdvertiseSettings.ADVERTISE_MODE_LOW_LATENCY )
                  .setTxPowerLevel( AdvertiseSettings.ADVERTISE_TX_POWER_HIGH )
                  .setConnectable( false )
                  .build();
                Log.e(LOG_TAG, "BLE.isMultipleAdvertisementSupported:"+BluetoothAdapter.getDefaultAdapter().isMultipleAdvertisementSupported());
                BluetoothLeAdvertiser advertiser = BluetoothAdapter.getDefaultAdapter().getBluetoothLeAdvertiser();
                advertiser.startAdvertising( advSettings, advData, advertisingCallback );
                successCallback.invoke();
            }
        }
	@ReactMethod
	public void scan(ReadableArray serviceUUIDs, boolean allowDuplicates, Callback successCallback) {
		Log.d(LOG_TAG, "scan");
		if (!getBluetoothAdapter().isEnabled()){
                    Log.e(LOG_TAG, "BLE disabled");
                    return;
                }
		for (Iterator<Map.Entry<String, Peripheral>> iterator = peripherals.entrySet().iterator(); iterator.hasNext(); ) {
			Map.Entry<String, Peripheral> entry = iterator.next();
			if (!entry.getValue().isConnected()) {
				iterator.remove();
			}
		}

		if (serviceUUIDs.size() > 0) {
			UUID[] services = new UUID[serviceUUIDs.size()];
			for(int i = 0; i < serviceUUIDs.size(); i++){
				services[i] = UUIDHelper.uuidFromString(serviceUUIDs.getString(i));
				Log.d(LOG_TAG, "Filter service: " + serviceUUIDs.getString(i));
			}
			if (Build.VERSION.SDK_INT >= LOLLIPOP) {
				Log.d(LOG_TAG, "scan con filter");
				//getBluetoothAdapter().startLeScan(services, mLeScanCallback);
                                //ScanSettings.Builder scanSettingsBuilder = new ScanSettings.Builder();
                                //scanSettingsBuilder.setScanMode(ScanSettings.SCAN_MODE_LOW_POWER);
                                //ScanSettings scanSettings = scanSettingsBuilder.build();
                                scanner.startScan(scanCallback);
			}else {
				Log.d(LOG_TAG, "scan senza filter");
				getBluetoothAdapter().startLeScan(services,mLeScanCallback);
			}
		} else {
                    if (Build.VERSION.SDK_INT >= LOLLIPOP) {
                        //BluetoothLeScanner scanner = getBluetoothAdapter().getBluetoothLeScanner();
                        //ScanSettings.Builder scanSettingsBuilder = new ScanSettings.Builder();
                        //scanSettingsBuilder.setScanMode(ScanSettings.SCAN_MODE_LOW_POWER);
                        //ScanSettings scanSettings = scanSettingsBuilder.build();
                        scanner.startScan(scanCallback);
                    }else {
			getBluetoothAdapter().startLeScan(mLeScanCallback);
                    }
		}

		/*if (scanSeconds > 0) {
			Thread thread = new Thread() {
				@Override
				public void run() {
					try {
						Thread.sleep(scanSeconds * 1000);
					} catch (InterruptedException ignored) {
					}
					runOnUiThread(new Runnable() {
						@Override
						public void run() {
							if (Build.VERSION.SDK_INT < LOLLIPOP) {
								getBluetoothAdapter().stopLeScan(mLeScanCallback);
							}else{
								scanner.stopScan(scanCallback);
							}
							WritableMap map = Arguments.createMap();
							sendEvent("BleManagerStopScan", map);
						}
					});
				}
			};
			thread.start();
		}*/

		successCallback.invoke();
	}

        @ReactMethod
        public void stop(){
            if (Build.VERSION.SDK_INT < LOLLIPOP) {
                getBluetoothAdapter().stopLeScan(mLeScanCallback);
            }else{
                scanner.stopScan(scanCallback);
            }
            WritableMap map = Arguments.createMap();
            sendEvent("BleManagerStopScan", map);
        }

	@ReactMethod
	public void connect(String peripheralUUID, Callback successCallback, Callback failCallback) {
		Log.d(LOG_TAG, "Connect to: " + peripheralUUID );

		Peripheral peripheral = peripherals.get(peripheralUUID);
		if (peripheral != null){
			peripheral.connect(successCallback, failCallback, getCurrentActivity());
		} else
			failCallback.invoke();
	}

	@ReactMethod
	public void disconnect(String peripheralUUID, Callback successCallback, Callback failCallback) {
		Log.d(LOG_TAG, "Disconnect from: " + peripheralUUID);

		Peripheral peripheral = peripherals.get(peripheralUUID);
		if (peripheral != null){
			peripheral.disconnect();
			successCallback.invoke();
		} else
			failCallback.invoke();
	}

	@ReactMethod
	public void startNotification(String deviceUUID, String serviceUUID, String characteristicUUID, Callback successCallback, Callback failCallback) {
		Log.d(LOG_TAG, "startNotification");

		Peripheral peripheral = peripherals.get(deviceUUID);
		if (peripheral != null){
			peripheral.registerNotify(UUID.fromString(serviceUUID), UUID.fromString(characteristicUUID), successCallback, failCallback);
		} else
			failCallback.invoke();
	}

	@ReactMethod
	public void stopNotification(String deviceUUID, String serviceUUID, String characteristicUUID, Callback successCallback, Callback failCallback) {
		Log.d(LOG_TAG, "stopNotification");

		Peripheral peripheral = peripherals.get(deviceUUID);
		if (peripheral != null){
			peripheral.removeNotify(UUID.fromString(serviceUUID), UUID.fromString(characteristicUUID), successCallback, failCallback);
		} else
			failCallback.invoke();
	}


	@ReactMethod
	public void write(String deviceUUID, String serviceUUID, String characteristicUUID, String message, Callback successCallback, Callback failCallback) {
		Log.d(LOG_TAG, "Write to: " + deviceUUID);

		Peripheral peripheral = peripherals.get(deviceUUID);
		if (peripheral != null){
			byte[] decoded = Base64.decode(message.getBytes(), Base64.DEFAULT);
			Log.d(LOG_TAG, "Message(" + decoded.length + "): " + bytesToHex(decoded));
			peripheral.write(UUID.fromString(serviceUUID), UUID.fromString(characteristicUUID), decoded, successCallback, failCallback, BluetoothGattCharacteristic.WRITE_TYPE_DEFAULT);
		} else
			failCallback.invoke();
	}

	@ReactMethod
	public void read(String deviceUUID, String serviceUUID, String characteristicUUID, Callback successCallback, Callback failCallback) {
		Log.d(LOG_TAG, "Read from: " + deviceUUID);

		Peripheral peripheral = peripherals.get(deviceUUID);
		if (peripheral != null){
			peripheral.read(UUID.fromString(serviceUUID), UUID.fromString(characteristicUUID), successCallback, failCallback);
		} else
			failCallback.invoke();
	}

	private final ScanCallback scanCallback = new ScanCallback() {
	    @Override
            public void onScanResult(int callbackType, ScanResult result) {
                BluetoothDevice device = result.getDevice();
                String address = device.getAddress();
                //if (!peripherals.containsKey(address)) {
                Peripheral peripheral = new Peripheral(device, result.getRssi(), result.getScanRecord(), reactContext);
                peripherals.put(device.getAddress(), peripheral);
                BundleJSONConverter bjc = new BundleJSONConverter();
                try {
                    Bundle bundle = bjc.convertToBundle(peripheral.asJSONObject());
                    WritableMap map = Arguments.fromBundle(bundle);
                    sendEvent("BleManagerDiscoverPeripheral", map);
                } catch (JSONException ignored) {}
                //}
            }
	};
	private BluetoothAdapter.LeScanCallback mLeScanCallback =
		new BluetoothAdapter.LeScanCallback() {
		    @Override
		    public void onLeScan(final BluetoothDevice device, final int rssi, final byte[] scanRecord) {
			runOnUiThread(new Runnable() {
			    @Override
			    public void run() {
				Log.i(LOG_TAG, "DiscoverPeripheral: " + device.getName());
				String address = device.getAddress();
				if (!peripherals.containsKey(address)) {
					Peripheral peripheral = new Peripheral(device, rssi, scanRecord, reactContext);
					peripherals.put(device.getAddress(), peripheral);
					BundleJSONConverter bjc = new BundleJSONConverter();
					try {
						Bundle bundle = bjc.convertToBundle(peripheral.asJSONObject());
						WritableMap map = Arguments.fromBundle(bundle);
						sendEvent("BleManagerDiscoverPeripheral", map);
					} catch (JSONException ignored) {}
				} else {
					// this isn't necessary
					Peripheral peripheral = peripherals.get(address);
					peripheral.updateRssi(rssi);
				}
			    }
			});
		    }
		};

	@ReactMethod
	public void checkState(){
		Log.d(LOG_TAG, "checkState");

		BluetoothAdapter adapter = getBluetoothAdapter();
		String state = "off";
		switch (adapter.getState()){
			case BluetoothAdapter.STATE_ON:
				state = "on";
				break;
			case BluetoothAdapter.STATE_OFF:
				state = "off";
		}

		WritableMap map = Arguments.createMap();
		map.putString("state", state);
		Log.d(LOG_TAG, "state:" + state);
		sendEvent("BleManagerDidUpdateState", map);
	}

	private final BroadcastReceiver mReceiver = new BroadcastReceiver() {
		@Override
		public void onReceive(Context context, Intent intent) {
			Log.d(LOG_TAG, "onReceive");
			final String action = intent.getAction();

			String stringState = "";
			if (action.equals(BluetoothAdapter.ACTION_STATE_CHANGED)) {
				final int state = intent.getIntExtra(BluetoothAdapter.EXTRA_STATE,
						BluetoothAdapter.ERROR);
				switch (state) {
					case BluetoothAdapter.STATE_OFF:
						stringState = "off";
						break;
					case BluetoothAdapter.STATE_TURNING_OFF:
						stringState = "turning_off";
						break;
					case BluetoothAdapter.STATE_ON:
						stringState = "on";
						break;
					case BluetoothAdapter.STATE_TURNING_ON:
						stringState = "turning_on";
						break;
				}
			}

			WritableMap map = Arguments.createMap();
			map.putString("state", stringState);
			Log.d(LOG_TAG, "state: " + stringState);
			sendEvent("BleManagerDidUpdateState", map);
		}
	};

	private final static char[] hexArray = "0123456789ABCDEF".toCharArray();

	public static String bytesToHex(byte[] bytes) {
		char[] hexChars = new char[bytes.length * 2];
		for (int j = 0; j < bytes.length; j++) {
			int v = bytes[j] & 0xFF;
			hexChars[j * 2] = hexArray[v >>> 4];
			hexChars[j * 2 + 1] = hexArray[v & 0x0F];
		}
		return new String(hexChars);
	}

}
