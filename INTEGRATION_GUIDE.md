# Flutter SNAPPY Plugin - Integration Guide

Complete guide for integrating the Flutter SNAPPY Plugin into your Flutter applications.

## Prerequisites

Before starting integration, ensure you have completed the [SETUP.md](SETUP.md) requirements:
- ✅ snappy_web_agent daemon installed and running
- ✅ SNAPPY device connected and detected
- ✅ Flutter SDK 3.0+ installed
- ✅ Network ports 8436-8535 available

## Installation

### 1. Add Dependency

Add the plugin to your `pubspec.yaml`:

```yaml
dependencies:
  flutter:
    sdk: flutter
  flutter_snappy_plugin: ^1.0.0-beta.1
```

Then run:
```bash
flutter pub get
```

### 2. Import the Plugin

```dart
import 'package:flutter_snappy_plugin/flutter_snappy_plugin.dart';
```

## Basic Integration

### Step 1: Initialize the Plugin

```dart
class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final FlutterSnappyPlugin _plugin = FlutterSnappyPlugin.instance;
  
  @override
  void initState() {
    super.initState();
    _checkPlatformSupport();
  }
  
  void _checkPlatformSupport() {
    if (!_plugin.isPlatformSupported) {
      print('Platform ${_plugin.currentPlatform} not supported');
      // Show error to user
      return;
    }
    print('Running on supported platform: ${_plugin.currentPlatform}');
  }
}
```

### Step 2: Connect to Service

```dart
Future<void> _connectToService() async {
  try {
    final response = await _plugin.connect();
    
    if (response.success) {
      print('✅ Connected: ${response.message}');
      // Update UI to show connected state
    } else {
      print('❌ Connection failed: ${response.error}');
      // Handle connection failure
      _handleConnectionError(response.error);
    }
  } catch (e) {
    print('❌ Connection exception: $e');
    // Handle unexpected errors
  }
}

void _handleConnectionError(String? error) {
  switch (error) {
    case 'DAEMON_NOT_FOUND':
      _showError('Snappy Web Agent daemon not found. Please ensure it is running.');
      break;
    case 'CONNECTION_FAILED':
      _showError('Failed to connect to daemon. Check firewall settings.');
      break;
    case 'PLATFORM_UNSUPPORTED':
      _showError('This platform is not supported.');
      break;
    default:
      _showError('Connection failed: $error');
  }
}
```

### Step 3: Set Up Stream Listeners

```dart
StreamSubscription<bool>? _connectionSub;
StreamSubscription<bool>? _deviceSub;
StreamSubscription<SnapData>? _dataSub;

void _setupStreamListeners() {
  // Listen to service connection status
  _connectionSub = _plugin.isConnected.listen(
    (connected) {
      print('Service connected: $connected');
      setState(() {
        _serviceConnected = connected;
      });
    },
    onError: (error) {
      print('Connection stream error: $error');
    },
  );

  // Listen to device connection status
  _deviceSub = _plugin.deviceConnected.listen(
    (connected) {
      print('Device connected: $connected');
      setState(() {
        _deviceConnected = connected;
      });
      
      // Show user notification
      _showSnackBar(
        connected ? 'SNAPPY device connected!' : 'SNAPPY device disconnected',
        connected ? Colors.green : Colors.orange,
      );
    },
    onError: (error) {
      print('Device stream error: $error');
    },
  );

  // Listen to real-time data
  _dataSub = _plugin.dataStream.listen(
    (data) {
      print('📡 Data: ${data.value} from ${data.mac}');
      setState(() {
        _latestData = data;
        _dataHistory.insert(0, data);
        
        // Keep only last 100 entries
        if (_dataHistory.length > 100) {
          _dataHistory.removeLast();
        }
      });
    },
    onError: (error) {
      print('Data stream error: $error');
    },
  );
}
```

### Step 4: Data Collection Control

```dart
bool _isCollecting = false;

Future<void> _startDataCollection() async {
  if (!_plugin.isCurrentlyConnected) {
    _showError('Not connected to service');
    return;
  }

  try {
    final response = await _plugin.startDataCollection();
    
    if (response.success) {
      print('✅ Data collection started');
      setState(() {
        _isCollecting = true;
      });
    } else {
      print('❌ Failed to start collection: ${response.error}');
      _showError('Failed to start data collection: ${response.error}');
    }
  } catch (e) {
    print('❌ Start collection exception: $e');
    _showError('Error starting data collection: $e');
  }
}

Future<void> _stopDataCollection() async {
  try {
    final response = await _plugin.stopDataCollection();
    
    if (response.success) {
      print('✅ Data collection stopped');
      setState(() {
        _isCollecting = false;
      });
    } else {
      print('❌ Failed to stop collection: ${response.error}');
      _showError('Failed to stop data collection: ${response.error}');
    }
  } catch (e) {
    print('❌ Stop collection exception: $e');
    _showError('Error stopping data collection: $e');
  }
}
```

### Step 5: Cleanup

```dart
@override
void dispose() {
  // Cancel stream subscriptions
  _connectionSub?.cancel();
  _deviceSub?.cancel();
  _dataSub?.cancel();
  
  // Disconnect from service
  _plugin.disconnect();
  
  super.dispose();
}
```

## Complete Example Application

```dart
import 'package:flutter/material.dart';
import 'package:flutter_snappy_plugin/flutter_snappy_plugin.dart';
import 'dart:async';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SNAPPY Plugin Integration',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: SnappyIntegrationPage(),
    );
  }
}

class SnappyIntegrationPage extends StatefulWidget {
  @override
  _SnappyIntegrationPageState createState() => _SnappyIntegrationPageState();
}

class _SnappyIntegrationPageState extends State<SnappyIntegrationPage> {
  final FlutterSnappyPlugin _plugin = FlutterSnappyPlugin.instance;
  
  // State variables
  bool _serviceConnected = false;
  bool _deviceConnected = false;
  bool _isCollecting = false;
  String _status = 'Initializing...';
  SnapData? _latestData;
  List<SnapData> _dataHistory = [];
  
  // Stream subscriptions
  StreamSubscription<bool>? _connectionSub;
  StreamSubscription<bool>? _deviceSub;
  StreamSubscription<SnapData>? _dataSub;

  @override
  void initState() {
    super.initState();
    _initializePlugin();
  }

  Future<void> _initializePlugin() async {
    // Check platform support
    if (!_plugin.isPlatformSupported) {
      setState(() {
        _status = 'Platform ${_plugin.currentPlatform} not supported';
      });
      return;
    }

    // Setup stream listeners
    _setupStreamListeners();
    
    // Initial connection attempt
    await _connectToService();
  }

  void _setupStreamListeners() {
    _connectionSub = _plugin.isConnected.listen((connected) {
      setState(() {
        _serviceConnected = connected;
        _status = connected ? 'Service Connected' : 'Service Disconnected';
      });
    });

    _deviceSub = _plugin.deviceConnected.listen((connected) {
      setState(() {
        _deviceConnected = connected;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(connected ? 'SNAPPY device connected!' : 'SNAPPY device disconnected'),
          backgroundColor: connected ? Colors.green : Colors.orange,
          duration: Duration(seconds: 2),
        ),
      );
    });

    _dataSub = _plugin.dataStream.listen((data) {
      setState(() {
        _latestData = data;
        _dataHistory.insert(0, data);
        if (_dataHistory.length > 50) _dataHistory.removeLast();
      });
    });
  }

  Future<void> _connectToService() async {
    setState(() => _status = 'Connecting...');
    
    final response = await _plugin.connect();
    
    if (response.success) {
      setState(() => _status = 'Connected: ${response.message}');
    } else {
      setState(() => _status = 'Connection failed: ${response.error}');
    }
  }

  Future<void> _startCollection() async {
    final response = await _plugin.startDataCollection();
    if (response.success) {
      setState(() => _isCollecting = true);
    } else {
      _showError('Failed to start collection: ${response.error}');
    }
  }

  Future<void> _stopCollection() async {
    final response = await _plugin.stopDataCollection();
    if (response.success) {
      setState(() => _isCollecting = false);
    } else {
      _showError('Failed to stop collection: ${response.error}');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: Duration(seconds: 4),
      ),
    );
  }

  @override
  void dispose() {
    _connectionSub?.cancel();
    _deviceSub?.cancel();
    _dataSub?.cancel();
    _plugin.disconnect();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('SNAPPY Plugin Integration'),
        backgroundColor: _serviceConnected ? Colors.green : Colors.red,
      ),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Status Card
            Card(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          _serviceConnected ? Icons.cloud_done : Icons.cloud_off,
                          color: _serviceConnected ? Colors.green : Colors.red,
                        ),
                        SizedBox(width: 8),
                        Text('Service Status', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    SizedBox(height: 8),
                    Text('Platform: ${_plugin.currentPlatform.name}'),
                    Text('Status: $_status'),
                    SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          _deviceConnected ? Icons.usb : Icons.usb_off,
                          color: _deviceConnected ? Colors.green : Colors.grey,
                        ),
                        SizedBox(width: 8),
                        Text(_deviceConnected ? 'Device Connected' : 'No Device'),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            
            SizedBox(height: 16),
            
            // Control Buttons
            Wrap(
              spacing: 8,
              children: [
                ElevatedButton.icon(
                  onPressed: _serviceConnected ? null : _connectToService,
                  icon: Icon(Icons.connect_without_contact),
                  label: Text('Connect'),
                ),
                ElevatedButton.icon(
                  onPressed: !_serviceConnected ? null : (_isCollecting ? _stopCollection : _startCollection),
                  icon: Icon(_isCollecting ? Icons.stop : Icons.play_arrow),
                  label: Text(_isCollecting ? 'Stop Collection' : 'Start Collection'),
                ),
              ],
            ),
            
            SizedBox(height: 16),
            
            // Latest Data
            if (_latestData != null)
              Card(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Latest Data', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      SizedBox(height: 8),
                      Text('Value: ${_latestData!.value}'),
                      Text('MAC: ${_latestData!.mac}'),
                      Text('Time: ${_latestData!.timestamp.split('T')[1].split('.')[0]}'),
                      if (_latestData!.pid != null) Text('PID: 0x${_latestData!.pid!.toRadixString(16)}'),
                    ],
                  ),
                ),
              ),
            
            SizedBox(height: 16),
            
            // Data History
            Expanded(
              child: Card(
                child: Column(
                  children: [
                    Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Data History (${_dataHistory.length})', 
                               style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          if (_dataHistory.isNotEmpty)
                            TextButton.icon(
                              onPressed: () => setState(() => _dataHistory.clear()),
                              icon: Icon(Icons.clear_all),
                              label: Text('Clear'),
                            ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: _dataHistory.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.data_usage_outlined, size: 64, color: Colors.grey),
                                  SizedBox(height: 16),
                                  Text('No data received yet', style: TextStyle(fontSize: 16, color: Colors.grey)),
                                  SizedBox(height: 8),
                                  Text('Connect service and start data collection', 
                                       style: TextStyle(color: Colors.grey)),
                                ],
                              ),
                            )
                          : ListView.builder(
                              itemCount: _dataHistory.length,
                              itemBuilder: (context, index) {
                                final data = _dataHistory[index];
                                final isLatest = index == 0;
                                return Container(
                                  color: isLatest ? Colors.green.withOpacity(0.1) : null,
                                  child: ListTile(
                                    leading: CircleAvatar(
                                      backgroundColor: isLatest ? Colors.green : Colors.grey,
                                      child: Text('${data.value}', 
                                                 style: TextStyle(color: Colors.white, fontSize: 12)),
                                    ),
                                    title: Text('MAC: ${data.mac}'),
                                    subtitle: Text('Time: ${data.timestamp.split('T')[1].split('.')[0]}'),
                                    trailing: data.pid != null 
                                        ? Chip(label: Text('PID: 0x${data.pid!.toRadixString(16)}'))
                                        : null,
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

## Advanced Integration Patterns

### 1. State Management Integration

#### Provider Pattern
```dart
import 'package:provider/provider.dart';

class SnappyProvider extends ChangeNotifier {
  final FlutterSnappyPlugin _plugin = FlutterSnappyPlugin.instance;
  
  bool _connected = false;
  bool _deviceConnected = false;
  List<SnapData> _dataHistory = [];
  
  bool get connected => _connected;
  bool get deviceConnected => _deviceConnected;
  List<SnapData> get dataHistory => List.unmodifiable(_dataHistory);
  
  StreamSubscription? _connectionSub;
  StreamSubscription? _deviceSub;
  StreamSubscription? _dataSub;
  
  SnappyProvider() {
    _setupListeners();
  }
  
  void _setupListeners() {
    _connectionSub = _plugin.isConnected.listen((connected) {
      _connected = connected;
      notifyListeners();
    });
    
    _deviceSub = _plugin.deviceConnected.listen((connected) {
      _deviceConnected = connected;
      notifyListeners();
    });
    
    _dataSub = _plugin.dataStream.listen((data) {
      _dataHistory.insert(0, data);
      if (_dataHistory.length > 1000) _dataHistory.removeLast();
      notifyListeners();
    });
  }
  
  Future<void> connect() async {
    await _plugin.connect();
  }
  
  Future<void> startCollection() async {
    await _plugin.startDataCollection();
  }
  
  @override
  void dispose() {
    _connectionSub?.cancel();
    _deviceSub?.cancel();
    _dataSub?.cancel();
    _plugin.disconnect();
    super.dispose();
  }
}
```

#### BLoC Pattern
```dart
import 'package:bloc/bloc.dart';

// Events
abstract class SnappyEvent {}
class ConnectRequested extends SnappyEvent {}
class StartCollectionRequested extends SnappyEvent {}
class StopCollectionRequested extends SnappyEvent {}
class DataReceived extends SnappyEvent {
  final SnapData data;
  DataReceived(this.data);
}

// States
abstract class SnappyState {}
class SnappyInitial extends SnappyState {}
class SnappyConnecting extends SnappyState {}
class SnappyConnected extends SnappyState {
  final String message;
  SnappyConnected(this.message);
}
class SnappyCollecting extends SnappyState {
  final List<SnapData> dataHistory;
  SnappyCollecting(this.dataHistory);
}
class SnappyError extends SnappyState {
  final String error;
  SnappyError(this.error);
}

// BLoC
class SnappyBloc extends Bloc<SnappyEvent, SnappyState> {
  final FlutterSnappyPlugin _plugin = FlutterSnappyPlugin.instance;
  final List<SnapData> _dataHistory = [];
  
  StreamSubscription? _dataSub;

  SnappyBloc() : super(SnappyInitial()) {
    on<ConnectRequested>(_onConnect);
    on<StartCollectionRequested>(_onStartCollection);
    on<StopCollectionRequested>(_onStopCollection);
    on<DataReceived>(_onDataReceived);
    
    _setupDataListener();
  }

  void _setupDataListener() {
    _dataSub = _plugin.dataStream.listen((data) {
      add(DataReceived(data));
    });
  }

  Future<void> _onConnect(ConnectRequested event, Emitter<SnappyState> emit) async {
    emit(SnappyConnecting());
    
    final response = await _plugin.connect();
    if (response.success) {
      emit(SnappyConnected(response.message));
    } else {
      emit(SnappyError(response.error ?? 'Connection failed'));
    }
  }

  Future<void> _onStartCollection(StartCollectionRequested event, Emitter<SnappyState> emit) async {
    final response = await _plugin.startDataCollection();
    if (response.success) {
      emit(SnappyCollecting(List.from(_dataHistory)));
    } else {
      emit(SnappyError(response.error ?? 'Failed to start collection'));
    }
  }

  void _onDataReceived(DataReceived event, Emitter<SnappyState> emit) {
    _dataHistory.insert(0, event.data);
    if (_dataHistory.length > 1000) _dataHistory.removeLast();
    emit(SnappyCollecting(List.from(_dataHistory)));
  }

  @override
  Future<void> close() {
    _dataSub?.cancel();
    _plugin.disconnect();
    return super.close();
  }
}
```

### 2. Error Handling Strategies

#### Comprehensive Error Handler
```dart
class SnappyErrorHandler {
  static void handlePluginError(BuildContext context, String? errorCode, String? message) {
    String title = 'Error';
    String description = message ?? 'Unknown error occurred';
    List<Widget> actions = [];

    switch (errorCode) {
      case 'DAEMON_NOT_FOUND':
        title = 'Daemon Not Found';
        description = 'The snappy_web_agent daemon is not running. Please start the daemon and try again.';
        actions = [
          TextButton(
            onPressed: () => _openDaemonHelp(context),
            child: Text('Help'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('OK'),
          ),
        ];
        break;
        
      case 'CONNECTION_FAILED':
        title = 'Connection Failed';
        description = 'Could not connect to the daemon. Check firewall settings and ensure ports 8436-8535 are available.';
        actions = [
          TextButton(
            onPressed: () => _runConnectionTest(context),
            child: Text('Test Connection'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('OK'),
          ),
        ];
        break;
        
      case 'PLATFORM_UNSUPPORTED':
        title = 'Platform Not Supported';
        description = 'This platform is not supported. Currently supports Windows and Linux only.';
        break;
        
      default:
        title = 'Plugin Error';
        description = '$errorCode: $message';
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(description),
        actions: actions.isNotEmpty ? actions : [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('OK'),
          ),
        ],
      ),
    );
  }

  static void _openDaemonHelp(BuildContext context) {
    // Open setup documentation or help page
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => DaemonHelpPage()),
    );
  }

  static Future<void> _runConnectionTest(BuildContext context) async {
    final plugin = FlutterSnappyPlugin.instance;
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text('Testing Connection'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Running connection diagnostics...'),
          ],
        ),
      ),
    );

    try {
      if (plugin.isDesktop) {
        final results = await plugin.testConnection();
        Navigator.of(context).pop(); // Close loading dialog
        
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('Connection Test Results'),
            content: SingleChildScrollView(
              child: Text(results.toString()),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text('Close'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      Navigator.of(context).pop(); // Close loading dialog
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Connection test failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
```

### 3. Data Processing and Analytics

#### Data Aggregation Service
```dart
class SnappyDataAnalytics {
  final List<SnapData> _rawData = [];
  final StreamController<DataSummary> _summaryController = StreamController<DataSummary>.broadcast();

  Stream<DataSummary> get summaryStream => _summaryController.stream;

  void addData(SnapData data) {
    _rawData.add(data);
    
    // Keep only last hour of data
    final cutoff = DateTime.now().subtract(Duration(hours: 1));
    _rawData.removeWhere((d) => DateTime.parse(d.timestamp).isBefore(cutoff));
    
    // Emit updated summary
    _summaryController.add(_calculateSummary());
  }

  DataSummary _calculateSummary() {
    if (_rawData.isEmpty) {
      return DataSummary(
        totalCount: 0,
        averageValue: 0.0,
        minValue: 0,
        maxValue: 0,
        uniqueDevices: 0,
        dataRate: 0.0,
      );
    }

    final values = _rawData.map((d) => d.value).toList();
    final uniqueMACs = _rawData.map((d) => d.mac).toSet();
    
    // Calculate data rate (data points per minute)
    final timeSpan = DateTime.parse(_rawData.first.timestamp)
        .difference(DateTime.parse(_rawData.last.timestamp))
        .inMinutes;
    final dataRate = timeSpan > 0 ? _rawData.length / timeSpan : 0.0;

    return DataSummary(
      totalCount: _rawData.length,
      averageValue: values.reduce((a, b) => a + b) / values.length,
      minValue: values.reduce((a, b) => a < b ? a : b),
      maxValue: values.reduce((a, b) => a > b ? a : b),
      uniqueDevices: uniqueMACs.length,
      dataRate: dataRate,
    );
  }

  void dispose() {
    _summaryController.close();
  }
}

class DataSummary {
  final int totalCount;
  final double averageValue;
  final int minValue;
  final int maxValue;
  final int uniqueDevices;
  final double dataRate;

  DataSummary({
    required this.totalCount,
    required this.averageValue,
    required this.minValue,
    required this.maxValue,
    required this.uniqueDevices,
    required this.dataRate,
  });
}
```

### 4. Custom Widgets

#### Connection Status Widget
```dart
class ConnectionStatusWidget extends StatelessWidget {
  final FlutterSnappyPlugin plugin;

  const ConnectionStatusWidget({Key? key, required this.plugin}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<bool>(
      stream: plugin.isConnected,
      builder: (context, snapshot) {
        final connected = snapshot.data ?? false;
        
        return Container(
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: connected ? Colors.green : Colors.red,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                connected ? Icons.cloud_done : Icons.cloud_off,
                color: Colors.white,
                size: 16,
              ),
              SizedBox(width: 4),
              Text(
                connected ? 'Connected' : 'Disconnected',
                style: TextStyle(color: Colors.white, fontSize: 12),
              ),
            ],
          ),
        );
      },
    );
  }
}
```

#### Real-time Chart Widget
```dart
import 'package:fl_chart/fl_chart.dart';

class SnappyDataChart extends StatefulWidget {
  final Stream<SnapData> dataStream;
  final int maxDataPoints;

  const SnappyDataChart({
    Key? key,
    required this.dataStream,
    this.maxDataPoints = 50,
  }) : super(key: key);

  @override
  _SnappyDataChartState createState() => _SnappyDataChartState();
}

class _SnappyDataChartState extends State<SnappyDataChart> {
  final List<FlSpot> _dataPoints = [];
  late StreamSubscription<SnapData> _subscription;
  int _xIndex = 0;

  @override
  void initState() {
    super.initState();
    _subscription = widget.dataStream.listen(_addDataPoint);
  }

  void _addDataPoint(SnapData data) {
    setState(() {
      _dataPoints.add(FlSpot(_xIndex.toDouble(), data.value.toDouble()));
      _xIndex++;
      
      // Keep only recent data points
      if (_dataPoints.length > widget.maxDataPoints) {
        _dataPoints.removeAt(0);
      }
    });
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 200,
      padding: EdgeInsets.all(16),
      child: LineChart(
        LineChartData(
          gridData: FlGridData(show: true),
          titlesData: FlTitlesData(show: true),
          borderData: FlBorderData(show: true),
          lineBarsData: [
            LineChartBarData(
              spots: _dataPoints,
              isCurved: true,
              color: Colors.blue,
              barWidth: 2,
              dotData: FlDotData(show: false),
            ),
          ],
        ),
      ),
    );
  }
}
```

## Testing Your Integration

### 1. Unit Tests

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_snappy_plugin/flutter_snappy_plugin.dart';

void main() {
  group('SnappyPlugin Integration Tests', () {
    late FlutterSnappyPlugin plugin;

    setUp(() {
      plugin = FlutterSnappyPlugin.instance;
    });

    test('should detect platform correctly', () {
      expect(plugin.currentPlatform, isNotNull);
      expect(plugin.isPlatformSupported, isA<bool>());
    });

    test('should handle connection gracefully', () async {
      // This test requires a running daemon
      final response = await plugin.connect();
      expect(response, isA<PluginResponse>());
      expect(response.success, isA<bool>());
    });

    test('should provide data streams', () {
      expect(plugin.isConnected, isA<Stream<bool>>());
      expect(plugin.deviceConnected, isA<Stream<bool>>());
      expect(plugin.dataStream, isA<Stream<SnapData>>());
    });
  });
}
```

### 2. Integration Test Checklist

- [ ] **Platform Detection**: Plugin correctly identifies Windows/Linux
- [ ] **Service Connection**: Successfully connects to running daemon
- [ ] **Error Handling**: Gracefully handles daemon not found
- [ ] **Stream Functionality**: All streams emit expected data
- [ ] **Data Collection**: Start/stop commands work correctly
- [ ] **Device Detection**: Recognizes SNAPPY device connection/disconnection
- [ ] **Memory Management**: No memory leaks after dispose
- [ ] **UI Responsiveness**: UI remains responsive during data streaming

## Deployment Considerations

### 1. Production Checklist

- [ ] **Error Logging**: Implement comprehensive error logging
- [ ] **User Feedback**: Provide clear feedback for all user actions
- [ ] **Offline Handling**: Handle daemon unavailability gracefully
- [ ] **Performance**: Monitor memory usage with continuous data streams
- [ ] **Security**: Validate data from daemon before processing

### 2. Distribution Requirements

#### End User Requirements
- snappy_web_agent daemon installed and running
- SNAPPY device with proper VID/PID
- Network ports 8436-8535 available
- Proper device permissions (Linux)

#### App Store/Distribution Notes
- Include setup documentation
- Clearly state system requirements
- Provide troubleshooting guide
- Consider daemon auto-detection and setup assistance

## Support and Troubleshooting

### Common Integration Issues

1. **Stream Not Receiving Data**
   ```dart
   // Check connection status first
   if (!plugin.isCurrentlyConnected) {
     await plugin.connect();
   }
   
   // Ensure data collection is started
   await plugin.startDataCollection();
   ```

2. **Memory Leaks**
   ```dart
   // Always cancel subscriptions
   @override
   void dispose() {
     _subscription?.cancel();
     plugin.disconnect();
     super.dispose();
   }
   ```

3. **Platform Detection Issues**
   ```dart
   // Always check platform support
   if (!plugin.isPlatformSupported) {
     // Show appropriate message
     return;
   }
   ```

### Debug Tips

1. **Enable Verbose Logging**: `flutter run --verbose`
2. **Check Console Output**: Look for daemon detection messages
3. **Test Daemon Manually**: Connect via browser to http://localhost:8436
4. **Validate Setup**: Run setup validation scripts from SETUP.md

For additional support, refer to the [example application](example/) which demonstrates all integration patterns and best practices.