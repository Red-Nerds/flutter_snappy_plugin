import 'package:flutter/material.dart';
import 'dart:async';
import 'package:flutter_snappy_plugin/flutter_snappy_plugin.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SNAPPY Plugin Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'Flutter SNAPPY Plugin Demo'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final FlutterSnappyPlugin _plugin = FlutterSnappyPlugin.instance;

  // State variables
  String _status = 'Disconnected';
  String _version = 'Unknown';
  bool _isConnected = false;
  bool _deviceConnected = false;
  bool _isCollecting = false;
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

  @override
  void dispose() {
    _connectionSub?.cancel();
    _deviceSub?.cancel();
    _dataSub?.cancel();
    super.dispose();
  }

  /// Initialize plugin and setup streams
  Future<void> _initializePlugin() async {
    // Setup connection stream
    _connectionSub = _plugin.isConnected.listen((connected) {
      setState(() {
        _isConnected = connected;
        _status = connected ? 'Connected' : 'Disconnected';
      });
    });

    // Setup device connection stream
    _deviceSub = _plugin.deviceConnected.listen((connected) {
      setState(() {
        _deviceConnected = connected;
      });
    });

    // Setup data stream
    _dataSub = _plugin.dataStream.listen((data) {
      setState(() {
        _dataHistory.insert(0, data);
        // Keep only last 50 entries
        if (_dataHistory.length > 50) {
          _dataHistory.removeLast();
        }
      });
    });

    // Check platform support
    setState(() {
      _status = _plugin.isPlatformSupported
          ? 'Platform: ${_plugin.currentPlatform.name}'
          : 'Unsupported Platform';
    });
  }

  /// Connect to SNAPPY service
  Future<void> _connect() async {
    setState(() => _status = 'Connecting...');

    try {
      final response = await _plugin.connect();
      setState(() {
        _status = response.success ? response.message : 'Error: ${response.error}';
      });

      if (response.success) {
        _getVersion();
      }
    } catch (e) {
      setState(() => _status = 'Connection failed: $e');
    }
  }

  /// Disconnect from SNAPPY service
  Future<void> _disconnect() async {
    setState(() => _status = 'Disconnecting...');

    try {
      await _plugin.disconnect();
      setState(() {
        _status = 'Disconnected';
        _version = 'Unknown';
        _isCollecting = false;
        _dataHistory.clear();
      });
    } catch (e) {
      setState(() => _status = 'Disconnect failed: $e');
    }
  }

  /// Get service version
  Future<void> _getVersion() async {
    try {
      final response = await _plugin.getVersion();
      setState(() {
        _version = response.success ? response.message : 'Unknown';
      });
    } catch (e) {
      setState(() => _version = 'Error: $e');
    }
  }

  /// Start data collection
  Future<void> _startCollection() async {
    try {
      final response = await _plugin.startDataCollection();
      setState(() {
        _isCollecting = response.success;
        if (!response.success) {
          _status = 'Start failed: ${response.error}';
        }
      });
    } catch (e) {
      setState(() => _status = 'Start failed: $e');
    }
  }

  /// Stop data collection
  Future<void> _stopCollection() async {
    try {
      final response = await _plugin.stopDataCollection();
      setState(() {
        _isCollecting = !response.success ? _isCollecting : false;
        if (!response.success) {
          _status = 'Stop failed: ${response.error}';
        }
      });
    } catch (e) {
      setState(() => _status = 'Stop failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Status Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Status',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text('Connection: $_status'),
                    Text('Version: $_version'),
                    Text('Platform: ${_plugin.currentPlatform.name}'),
                    Row(
                      children: [
                        Icon(
                          _isConnected ? Icons.check_circle : Icons.cancel,
                          color: _isConnected ? Colors.green : Colors.red,
                          size: 16,
                        ),
                        const SizedBox(width: 4),
                        Text('Service Connected'),
                      ],
                    ),
                    Row(
                      children: [
                        Icon(
                          _deviceConnected ? Icons.check_circle : Icons.cancel,
                          color: _deviceConnected ? Colors.green : Colors.red,
                          size: 16,
                        ),
                        const SizedBox(width: 4),
                        Text('Device Connected'),
                      ],
                    ),
                    Row(
                      children: [
                        Icon(
                          _isCollecting ? Icons.play_circle : Icons.pause_circle,
                          color: _isCollecting ? Colors.blue : Colors.grey,
                          size: 16,
                        ),
                        const SizedBox(width: 4),
                        Text('Data Collection'),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Control Buttons
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Controls',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _isConnected ? _disconnect : _connect,
                            child: Text(_isConnected ? 'Disconnect' : 'Connect'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: !_isConnected ? null :
                            (_isCollecting ? _stopCollection : _startCollection),
                            child: Text(_isCollecting ? 'Stop Collection' : 'Start Collection'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Data History
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Data History (${_dataHistory.length})',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        if (_dataHistory.isNotEmpty)
                          TextButton(
                            onPressed: () => setState(() => _dataHistory.clear()),
                            child: const Text('Clear'),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (_dataHistory.isEmpty)
                      const Text('No data received yet')
                    else
                      SizedBox(
                        height: 200,
                        child: ListView.builder(
                          itemCount: _dataHistory.length,
                          itemBuilder: (context, index) {
                            final data = _dataHistory[index];
                            return ListTile(
                              dense: true,
                              leading: CircleAvatar(
                                radius: 12,
                                child: Text(
                                  data.value.toString(),
                                  style: const TextStyle(fontSize: 10),
                                ),
                              ),
                              title: Text(
                                'MAC: ${data.mac}',
                                style: const TextStyle(fontSize: 12),
                              ),
                              subtitle: Text(
                                'Value: ${data.value} | ${data.timestamp}',
                                style: const TextStyle(fontSize: 10),
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