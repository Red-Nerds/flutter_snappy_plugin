# Flutter SNAPPY Plugin Setup Guide

This guide walks you through setting up the Flutter SNAPPY Plugin on Windows and Linux systems.

## Prerequisites

- Flutter SDK 3.0+
- Windows 11 or Linux system
- SNAPPY device with USB connection
- snappy_web_agent daemon installed and running

## Step 1: Install snappy_web_agent Daemon

The Flutter plugin communicates with SNAPPY devices through the `snappy_web_agent` daemon.

### Windows Installation

1. **Download snappy_web_agent**:
    - Get the Windows MSI installer: `snappy-web-agent-*-setup.msi`
    - Run as Administrator to install

2. **Verify Installation**:
   ```cmd
   # Check if service is running
   sc query "Snappy Web Agent"
   
   # Check listening ports
   netstat -an | findstr 843
   ```

3. **Manual Start** (if needed):
   ```cmd
   # Start service
   sc start "Snappy Web Agent"
   ```

### Linux Installation

1. **Download snappy_web_agent**:
    - Get the Debian package: `snappy-web-agent_*.deb`
    - Install: `sudo dpkg -i snappy-web-agent_*.deb`

2. **Setup udev rules** (for device access):
   ```bash
   # The package should install udev rules automatically
   # If not, manually copy rules:
   sudo cp /opt/snappy-web-agent/99-snappy-web-agent.rules /etc/udev/rules.d/
   sudo udevadm control --reload-rules
   sudo udevadm trigger
   
   # Add user to dialout group
   sudo usermod -a -G dialout $USER
   # Log out and back in for group changes
   ```

3. **Verify Installation**:
   ```bash
   # Check if service is running
   systemctl status snappy-web-agent
   
   # Check listening ports
   netstat -ln | grep 843
   
   # Check device access
   lsusb | grep "b1b0:5508"
   ```

## Step 2: Setup Flutter Project

### 1. Extract Plugin

Extract the `flutter_snappy_plugin.zip` to your project directory:

```
your_project/
├── lib/
├── flutter_snappy_plugin/    # <- Extracted plugin
│   ├── lib/
│   ├── pubspec.yaml
│   └── README.md
└── pubspec.yaml
```

### 2. Update pubspec.yaml

Add the plugin to your `pubspec.yaml`:

```yaml
dependencies:
  flutter:
    sdk: flutter
  flutter_snappy_plugin:
    path: ./flutter_snappy_plugin
```

### 3. Install Dependencies

```bash
flutter packages get
```

## Step 3: Basic Implementation

### 1. Import Plugin

```dart
import 'package:flutter_snappy_plugin/flutter_snappy_plugin.dart';
```

### 2. Initialize Plugin

```dart
class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final FlutterSnappyPlugin _plugin = FlutterSnappyPlugin.instance;
  String _status = 'Disconnected';
  
  @override
  void initState() {
    super.initState();
    _initializePlugin();
  }
  
  Future<void> _initializePlugin() async {
    // Check platform support
    if (!_plugin.isPlatformSupported) {
      setState(() => _status = 'Platform not supported');
      return;
    }
    
    // Connect to daemon
    final connectResult = await _plugin.connect();
    if (connectResult.success) {
      setState(() => _status = 'Connected: ${connectResult.message}');
      
      // Setup data stream
      _plugin.dataStream.listen((data) {
        print('Received data: ${data.value} from ${data.mac}');
      });
      
      // Start data collection
      final startResult = await _plugin.startDataCollection();
      if (startResult.success) {
        print('Data collection started');
      }
    } else {
      setState(() => _status = 'Connection failed: ${connectResult.error}');
    }
  }
}
```

## Step 4: Testing Setup

### 1. Run Example App

Use the included example app to test your setup:

```bash
cd flutter_snappy_plugin/example
flutter run -d windows  # or -d linux
```

### 2. Test Connection

The example app should show:
- ✅ Platform detected (Windows/Linux)
- ✅ Service Connected (if daemon is running)
- ✅ Device Connected (if SNAPPY device is plugged in)

### 3. Test Data Collection

1. Click "Start Collection" in the example app
2. Interact with your SNAPPY device
3. Data should appear in the "Data History" section

## Troubleshooting

### Common Issues

#### 1. "DAEMON_NOT_FOUND" Error

**Problem**: Plugin can't find snappy_web_agent daemon

**Solutions**:
- Verify daemon is installed and running
- Check if daemon is listening on ports 8436-8535:
  ```bash
  # Windows
  netstat -an | findstr 843
  
  # Linux  
  netstat -ln | grep 843
  ```
- Restart the daemon service

#### 2. "CONNECTION_FAILED" Error

**Problem**: Plugin found daemon but can't connect

**Solutions**:
- Check firewall settings (allow ports 8436-8535)
- Verify daemon is not blocked by antivirus
- Try connecting manually to test port:
  ```bash
  telnet localhost 8436
  ```

#### 3. Device Not Detected

**Problem**: No device connection events received

**Solutions**:
- Verify SNAPPY device is connected via USB
- Check device VID/PID (should be 0xb1b0:0x5508)
- On Linux, ensure udev rules are installed and user is in dialout group

#### 4. No Data Received

**Problem**: Device connected but no data in stream

**Solutions**:
- Ensure data collection is started
- Check if device is sending data (interact with device)
- Verify daemon logs for errors

### Debug Commands

#### Windows Debug
```cmd
# Check service status
sc query "Snappy Web Agent"

# View service logs (Event Viewer)
eventvwr.msc

# Test port connectivity
telnet localhost 8436
```

#### Linux Debug
```bash
# Check service status
systemctl status snappy-web-agent

# View service logs
journalctl -u snappy-web-agent -f

# Check device permissions
ls -la /dev/tty* | grep dialout

# Test port connectivity  
nc -zv localhost 8436
```

## Advanced Configuration

### Custom Port Detection

If you need to specify a custom port range:

```dart
// This requires modifying daemon_detector.dart
// Or contact support for custom port configuration
```

### Multiple Device Support

The plugin automatically handles multiple devices connected to the same daemon:

```dart
_plugin.dataStream.listen((data) {
  print('Device ${data.mac}: value=${data.value}, pid=${data.pid}');
  
  // Handle different devices based on MAC or PID
  switch(data.mac) {
    case '0c:ca:d2:88:19:70':
      handleDevice1(data);
      break;
    case '0c:ca:d2:88:19:71':  
      handleDevice2(data);
      break;
  }
});
```

### Error Monitoring

Set up comprehensive error handling:

```dart
// Monitor connection status
_plugin.isConnected.listen((connected) {
  if (!connected) {
    // Handle disconnection
    _showReconnectDialog();
  }
});

// Monitor for plugin exceptions
try {
  await _plugin.connect();
} catch (e) {
  if (e is SnappyPluginException) {
    _handlePluginError(e);
  }
}
```

## Next Steps

1. **Test thoroughly** with your specific SNAPPY devices
2. **Implement error handling** appropriate for your use case
3. **Monitor performance** with multiple devices
4. **Prepare for Android support** when available

## Support

If you encounter issues not covered in this guide:

1. Check the main README.md for additional troubleshooting
2. Review the example app implementation
3. Ensure snappy_web_agent daemon is properly installed
4. Contact support with specific error messages and system info