# Flutter SNAPPY Plugin

A Flutter plugin for SNAPPY remote device communication supporting Windows, Linux, and Android platforms.

## Features

- **Cross-Platform Support**: Windows, Linux, and Android (Android coming soon)
- **Real-Time Data**: Stream live data from SNAPPY devices
- **Automatic Detection**: Auto-detects and connects to snappy_web_agent daemon on desktop
- **Error Handling**: Comprehensive error handling with clear messages
- **Easy Integration**: Simple API that works consistently across platforms

## Platform Support

| Platform | Status | Communication Method | Requirements |
|----------|--------|---------------------|-------------|
| Windows  | ✅ Ready | Socket.IO → snappy_web_agent | snappy_web_agent daemon |
| Linux    | ✅ Ready | Socket.IO → snappy_web_agent | snappy_web_agent daemon |
| Android  | 🚧 Coming Soon | BLE → remotesdk.aar | BLE-enabled device |

## Installation

### 1. Add to pubspec.yaml

Since this plugin is distributed as a zip file, extract it to your project and add:

```yaml
dependencies:
  flutter_snappy_plugin:
    path: ./flutter_snappy_plugin  # Path to extracted plugin
```

### 2. Platform-Specific Setup

#### Windows/Linux Requirements

1. **Install snappy_web_agent daemon**:
    - Download and install the snappy_web_agent service
    - Ensure it's running and accessible on ports 8436-8535
    - The daemon handles all USB/serial device communication

2. **Device Setup**:
    - Connect SNAPPY device via USB
    - Ensure device has VID: `0xb1b0` and PID: `0x5508`

#### Android Requirements (Coming Soon)

1. **Add permissions** to `android/app/src/main/AndroidManifest.xml`:
```xml
<uses-permission android:name="android.permission.BLUETOOTH" />
<uses-permission android:name="android.permission.BLUETOOTH_ADMIN" />
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
```

2. **Enable BLE** on target device

## Quick Start

### Basic Usage

```dart
import 'package:flutter_snappy_plugin/flutter_snappy_plugin.dart';

class SnappyExample extends StatefulWidget {
  @override
  _SnappyExampleState createState() => _SnappyExampleState();
}

class _SnappyExampleState extends State<SnappyExample> {
  final FlutterSnappyPlugin _plugin = FlutterSnappyPlugin.instance;
  
  @override
  void initState() {
    super.initState();
    _initializeSnappy();
  }
  
  Future<void> _initializeSnappy() async {
    // Connect to service
    final connectResult = await _plugin.connect();
    if (!connectResult.success) {
      print('Connection failed: ${connectResult.error}');
      return;
    }
    
    // Start data collection
    final startResult = await _plugin.startDataCollection();
    if (startResult.success) {
      print('Data collection started');
    }
    
    // Listen to data stream
    _plugin.dataStream.listen((data) {
      print('Received: ${data.value} from ${data.mac} at ${data.timestamp}');
    });
    
    // Monitor connection status
    _plugin.isConnected.listen((connected) {
      print('Connection status: ${connected ? 'Connected' : 'Disconnected'}');
    });
    
    // Monitor device status  
    _plugin.deviceConnected.listen((connected) {
      print('Device status: ${connected ? 'Connected' : 'Disconnected'}');
    });
  }
  
  @override
  void dispose() {
    _plugin.disconnect();
    super.dispose();
  }
}
```

### Complete Example

```dart
import 'package:flutter/material.dart';
import 'package:flutter_snappy_plugin/flutter_snappy_plugin.dart';

class SnappyDashboard extends StatefulWidget {
  @override
  _SnappyDashboardState createState() => _SnappyDashboardState();
}

class _SnappyDashboardState extends State<SnappyDashboard> {
  final FlutterSnappyPlugin _plugin = FlutterSnappyPlugin.instance;
  
  String _status = 'Disconnected';
  bool _isCollecting = false;
  List<SnapData> _recentData = [];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('SNAPPY Dashboard')),
      body: Column(
        children: [
          // Status Card
          Card(
            child: ListTile(
              title: Text('Status: $_status'),
              subtitle: Text('Platform: ${_plugin.currentPlatform.name}'),
              trailing: Icon(
                _plugin.isConnected != null ? Icons.check_circle : Icons.error,
                color: Colors.green,
              ),
            ),
          ),
          
          // Control Buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ElevatedButton(
                onPressed: _connect,
                child: Text('Connect'),
              ),
              ElevatedButton(
                onPressed: _isCollecting ? _stopCollection : _startCollection,
                child: Text(_isCollecting ? 'Stop' : 'Start'),
              ),
            ],
          ),
          
          // Data List
          Expanded(
            child: ListView.builder(
              itemCount: _recentData.length,
              itemBuilder: (context, index) {
                final data = _recentData[index];
                return ListTile(
                  title: Text('Value: ${data.value}'),
                  subtitle: Text('MAC: ${data.mac}'),
                  trailing: Text(data.timestamp),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _connect() async {
    final result = await _plugin.connect();
    setState(() {
      _status = result.success ? 'Connected' : 'Failed: ${result.error}';
    });
  }

  Future<void> _startCollection() async {
    final result = await _plugin.startDataCollection();
    setState(() {
      _isCollecting = result.success;
    });
    
    if (result.success) {
      _plugin.dataStream.listen((data) {
        setState(() {
          _recentData.insert(0, data);
          if (_recentData.length > 20) _recentData.removeLast();
        });
      });
    }
  }

  Future<void> _stopCollection() async {
    final result = await _plugin.stopDataCollection();
    setState(() {
      _isCollecting = !result.success;
    });
  }
}
```

## API Reference

### Core Methods

#### `connect()`
Connects to the SNAPPY service (daemon or AAR).

```dart
Future<PluginResponse> connect()
```

**Returns**: `PluginResponse` with connection result
- `success`: true if connected successfully
- `message`: Success message or error description
- `error`: Error code if failed

#### `startDataCollection()`
Starts collecting data from SNAPPY devices.

```dart
Future<PluginResponse> startDataCollection()
```

**Returns**: `PluginResponse` with operation result

#### `stopDataCollection()`
Stops collecting data from SNAPPY devices.

```dart
Future<PluginResponse> stopDataCollection()
```

**Returns**: `PluginResponse` with operation result

#### `getVersion()`
Gets the version of the underlying service.

```dart
Future<PluginResponse> getVersion()
```

**Returns**: `PluginResponse` with version in `message` field

#### `disconnect()`
Disconnects from the service and cleans up resources.

```dart
Future<void> disconnect()
```

### Streams

#### `isConnected`
Stream of connection status to the SNAPPY service.

```dart
Stream<bool> get isConnected
```

#### `deviceConnected`
Stream of physical device connection status.

```dart
Stream<bool> get deviceConnected
```

#### `dataStream`
Stream of real-time data from SNAPPY devices.

```dart
Stream<SnapData> get dataStream
```

### Data Models

#### `SnapData`
Real-time data from SNAPPY devices.

```dart
class SnapData {
  final String mac;        // Device MAC address
  final int value;         // Measured value
  final String timestamp;  // UTC timestamp (RFC 3339)
  final int? pid;          // Product ID (Desktop only)
  final int? remoteId;     // Remote ID (Android only)
}
```

#### `PluginResponse`
Response format for plugin operations.

```dart
class PluginResponse {
  final bool success;      // Operation success status
  final String message;    // Success message or error description
  final String command;    // Command that was executed
  final String? error;     // Error code if failed
}
```

#### `DeviceInfo`
Information about discovered devices.

```dart
class DeviceInfo {
  final String name;           // Device name
  final String mac;            // Device MAC address  
  final int? manufacturerId;   // Manufacturer ID
}
```

### Platform Information

#### `currentPlatform`
Get the current platform.

```dart
SnappyPlatform get currentPlatform
```

**Values**: `SnappyPlatform.windows`, `SnappyPlatform.linux`, `SnappyPlatform.android`, `SnappyPlatform.unsupported`

#### `isPlatformSupported`
Check if current platform is supported.

```dart
bool get isPlatformSupported
```

#### `isDesktop` / `isAndroid`
Platform-specific checks.

```dart
bool get isDesktop  // Windows or Linux
bool get isAndroid  // Android
```

## Error Handling

The plugin provides comprehensive error handling through `PluginResponse` objects and exceptions.

### Common Error Codes

| Error Code | Description | Solution |
|-----------|-------------|----------|
| `DAEMON_NOT_FOUND` | snappy_web_agent daemon not running | Install and start the daemon |
| `CONNECTION_FAILED` | Failed to connect to daemon | Check daemon status and ports |
| `NOT_CONNECTED` | Operation requires connection | Call `connect()` first |
| `UNSUPPORTED_PLATFORM` | Platform not supported | Use Windows, Linux, or Android |
| `SERVICE_DISPOSED` | Service has been disposed | Create new plugin instance |

### Error Handling Example

```dart
try {
  final result = await plugin.connect();
  if (!result.success) {
    switch (result.error) {
      case 'DAEMON_NOT_FOUND':
        showError('Please install and run snappy_web_agent daemon');
        break;
      case 'CONNECTION_FAILED':
        showError('Connection failed. Check daemon status.');
        break;
      default:
        showError('Connection error: ${result.message}');
    }
  }
} catch (e) {
  if (e is SnappyPluginException) {
    showError('Plugin error: ${e.message}');
  } else {
    showError('Unexpected error: $e');
  }
}
```

## Troubleshooting

### Desktop (Windows/Linux)

**Problem**: `DAEMON_NOT_FOUND` error
- **Solution**: Install snappy_web_agent daemon and ensure it's running
- **Check**: Run `netstat -an | grep 843` to see if daemon is listening on ports 8436-8535

**Problem**: Connection timeout
- **Solution**: Check firewall settings, ensure ports 8436-8535 are accessible
- **Check**: Verify daemon logs for errors

**Problem**: No device detected
- **Solution**: Ensure USB device is connected with correct VID/PID (0xb1b0:0x5508)
- **Check**: On Linux, verify udev rules are installed for device access

### Development

**Problem**: Import errors
- **Solution**: Run `flutter packages get` and ensure path is correct in `pubspec.yaml`

**Problem**: Build errors
- **Solution**: Run `flutter clean && flutter packages get`

## Future Android Support

When Android support is added, additional methods will become available:

```dart
// BLE Device scanning
Stream<DeviceInfo> scanForDevices()

// Device pairing
Future<PairingResult> pairRemote(String setName, String mac, int manufacturerId)

// Button press monitoring  
Stream<AnswerData> scanAnswers(String setName, {int? remoteId})

// Device management
Future<bool> saveDeviceList(String listName, List<DeviceInfo> devices)
Future<List<DeviceInfo>?> loadDeviceList(String listName)
```

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make changes
4. Add tests
5. Submit a pull request

## License

Copyright (c) Red Nerds. All rights reserved.

## Support

For support and questions:
- Check the troubleshooting section
- Review the example app
- Contact: [sahil@therednerds.com]