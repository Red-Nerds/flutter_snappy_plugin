# flutter_snappy_plugin

A Flutter plugin for SNAPPY remote device communication supporting Windows, Linux, macOS, and web platforms.

[![pub package](https://img.shields.io/pub/v/flutter_snappy_plugin.svg)](https://pub.dartlang.org/packages/flutter_snappy_plugin)
[![Platform Support](https://img.shields.io/badge/platform-Windows%20%7C%20Linux%20%7C%20macOS%20%7C%20Web-blue.svg)](https://flutter.dev/multi-platform)
[![Flutter](https://img.shields.io/badge/Flutter-3.0+-blue.svg)](https://flutter.dev)

## Platform Support

| Platform | Status | Communication Method | Requirements |
|----------|--------|---------------------|-------------|
| Windows  | ✅ Ready | Socket.IO → snappy_web_agent | snappy_web_agent daemon |
| Linux    | ✅ Ready | Socket.IO → snappy_web_agent | snappy_web_agent daemon |
| macOS    | ✅ Ready | Socket.IO → snappy_web_agent | snappy_web_agent daemon |
| Web      | ✅ Ready | Socket.IO → snappy_web_agent | snappy_web_agent daemon + CORS |
| Android  | 🚧 Coming Soon | BLE → remotesdk.aar | BLE-enabled device |

## Features

- **Real-time Data Streaming** - Live data from SNAPPY devices
- **Automatic Daemon Detection** - Finds and connects to snappy_web_agent on ports 8436-8535
- **Device Connection Monitoring** - Automatic device status detection and reconnection
- **Cross-Platform API** - Unified interface across Windows, Linux, macOS, and web
- **Error Recovery** - Comprehensive error handling with automatic reconnection
- **Lightweight** - Minimal dependencies, efficient Socket.IO communication

## Quick Start

### 1. Add Dependency

```yaml
dependencies:
  flutter_snappy_plugin: ^1.0.2
```

### 2. Basic Usage

```dart
import 'package:flutter_snappy_plugin/flutter_snappy_plugin.dart';

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final plugin = FlutterSnappyPlugin.instance;

  @override
  void initState() {
    super.initState();
    _initializeSnappy();
  }

  Future<void> _initializeSnappy() async {
    // Connect to snappy_web_agent daemon
    final connectResult = await plugin.connect();
    if (!connectResult.success) {
      print('Connection failed: ${connectResult.error}');
      return;
    }

    // Listen to real-time data
    plugin.dataStream.listen((data) {
      print('📡 Value: ${data.value} from ${data.mac}');
    });

    // Monitor device connection
    plugin.deviceConnected.listen((connected) {
      print('🔌 Device: ${connected ? 'Connected' : 'Disconnected'}');
    });

    // Start data collection
    await plugin.startDataCollection();
  }

  @override
  void dispose() {
    plugin.disconnect();
    super.dispose();
  }
}
```

### 3. Connection Status Monitoring

```dart
StreamBuilder<bool>(
  stream: plugin.isConnected,
  builder: (context, snapshot) {
    final connected = snapshot.data ?? false;
    return ListTile(
      leading: Icon(
        connected ? Icons.cloud_done : Icons.cloud_off,
        color: connected ? Colors.green : Colors.red,
      ),
      title: Text(connected ? 'Connected' : 'Disconnected'),
      subtitle: Text('Service Status'),
    );
  },
)
```

### 4. Real-time Data Display

```dart
StreamBuilder<SnapData>(
  stream: plugin.dataStream,
  builder: (context, snapshot) {
    if (!snapshot.hasData) return Text('No data');
    
    final data = snapshot.data!;
    return Card(
      child: ListTile(
        title: Text('Value: ${data.value}'),
        subtitle: Text('MAC: ${data.mac}'),
        trailing: Text('PID: ${data.pid}'),
      ),
    );
  },
)
```

## API Reference

### Core Methods

```dart
// Connection Management
Future<PluginResponse> connect();
Future<void> disconnect();
Future<bool> isServiceAvailable();

// Data Collection
Future<PluginResponse> startDataCollection();
Future<PluginResponse> stopDataCollection();
Future<PluginResponse> getVersion();

// Platform Information
SnappyPlatform get currentPlatform;  // windows, linux, android, unsupported
bool get isPlatformSupported;
bool get isDesktop;  // Windows or Linux
bool get isAndroid;  // Android
```

### Streams

```dart
// Service connection status
Stream<bool> get isConnected;

// Physical device connection status
Stream<bool> get deviceConnected;

// Real-time data from SNAPPY devices
Stream<SnapData> get dataStream;
```

### Data Models

#### SnapData
```dart
class SnapData {
  final String mac;        // Device MAC address
  final int value;         // Measured value
  final String timestamp;  // UTC timestamp (ISO 8601)
  final int? pid;          // Product ID (desktop only)
  final int? remoteId;     // Remote ID (Android only - future)
}
```

#### PluginResponse
```dart
class PluginResponse {
  final bool success;      // Operation success status
  final String message;    // Success message or error description
  final String command;    // Command that was executed
  final String? error;     // Error code if failed
}
```

## Error Handling

The plugin provides comprehensive error handling:

```dart
final result = await plugin.connect();
if (!result.success) {
  switch (result.error) {
    case 'DAEMON_NOT_FOUND':
      print('snappy_web_agent daemon not running');
      break;
    case 'CONNECTION_FAILED':
      print('Failed to connect to daemon');
      break;
    default:
      print('Error: ${result.message}');
  }
}
```

## Examples

### Complete Working App
Check out the [example app](example/) for a complete implementation showing:
- Platform detection and validation
- Connection management with UI feedback
- Real-time data streaming with history
- Device status monitoring
- Error handling and recovery
- Professional UI integration

### Running the Example
```bash
cd example
flutter run -d windows  # or -d linux, -d macos, -d chrome
```

## Requirements

### System Requirements
- Flutter SDK 3.0+
- Windows 11, Linux, macOS, or modern web browser
- SNAPPY device with USB connection (VID: 0xb1b0, PID: 0x5508)

### Runtime Dependencies
- **snappy_web_agent daemon** - Must be installed and running
- **Available ports** - 8436-8535 range for daemon communication
- **USB permissions** - Device access permissions (Linux may require udev rules)

## Troubleshooting

### Common Issues

| Error | Description | Solution |
|-------|-------------|----------|
| `DAEMON_NOT_FOUND` | snappy_web_agent not running | Install and start daemon |
| `CONNECTION_FAILED` | Can't connect to daemon | Check firewall, ports 8436-8535 |
| `PLATFORM_UNSUPPORTED` | Unsupported platform | Use Windows, Linux, or macOS |
| No device detected | SNAPPY device not found | Check USB connection and permissions |

### Debug Information
Enable verbose logging:
```bash
flutter run --verbose
```

Look for debug output:
```
DaemonDetector: Found daemon at port 8436, version: 1.0.3-beta.1
SocketIO: Connected successfully to http://localhost:8436
```

## Roadmap

- ✅ **v1.0.0** - Stable release with Windows, Linux, and macOS support via Socket.IO
- 🚧 **v1.1.0** - Android BLE integration with remotesdk.aar
- 🚧 **v1.2.0** - iOS support with daemon communication
- 🚧 **v2.0.0** - Advanced analytics and data processing features

## Contributing

Issues and pull requests are welcome! Please check the [issue tracker](https://github.com/Red-Nerds/flutter_snappy_plugin/issues) before submitting.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

**Made for SNAPPY remote device communication** 📡