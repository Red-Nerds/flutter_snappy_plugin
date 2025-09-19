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
  String _status = 'Initializing...';
  String _version = 'Unknown';
  bool _isConnected = false;
  bool _deviceConnected = false;
  bool _isCollecting = false;
  List<SnapData> _dataHistory = [];
  Map<String, dynamic>? _connectionTest;

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
    try {
      // Check platform support first
      if (!_plugin.isPlatformSupported) {
        setState(() {
          _status = 'Platform not supported: ${_plugin.currentPlatform.name}';
        });
        return;
      }

      setState(() {
        _status =
            'Platform: ${_plugin.currentPlatform.name} - Setting up streams...';
      });

      // Setup connection stream
      _connectionSub = _plugin.isConnected.listen((connected) {
        setState(() {
          _isConnected = connected;
          if (connected) {
            _status = 'Connected to SNAPPY service';
          } else {
            _status = 'Disconnected from SNAPPY service';
          }
        });
      });

      // Setup device connection stream
      _deviceSub = _plugin.deviceConnected.listen((connected) {
        setState(() {
          _deviceConnected = connected;
        });

        // Show snackbar for device connection changes
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                connected
                    ? 'SNAPPY device connected!'
                    : 'SNAPPY device disconnected',
              ),
              backgroundColor: connected ? Colors.green : Colors.orange,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      });

      // Setup data stream
      _dataSub = _plugin.dataStream.listen((data) {
        setState(() {
          _dataHistory.insert(0, data);
          // Keep only last 100 entries
          if (_dataHistory.length > 100) {
            _dataHistory.removeLast();
          }
        });
      });

      setState(() {
        _status =
            'Platform: ${_plugin.currentPlatform.name} - Ready to connect';
      });
    } catch (e) {
      setState(() {
        _status = 'Initialization failed: ${e.toString()}';
      });
    }
  }

  /// Connect to SNAPPY service
  Future<void> _connect() async {
    setState(() => _status = 'Connecting to daemon...');

    try {
      final response = await _plugin.connect();
      setState(() {
        _status = response.success
            ? 'Connected: ${response.message}'
            : 'Connection failed: ${response.error ?? response.message}';
      });

      if (response.success) {
        // Get version information
        await _getVersion();
      }
    } catch (e) {
      setState(() {
        _status = 'Connection error: ${e.toString()}';
      });
    }
  }

  /// Get version information
  Future<void> _getVersion() async {
    try {
      final response = await _plugin.getVersion();
      setState(() {
        _version = response.success ? response.message : 'Unknown';
      });
    } catch (e) {
      setState(() {
        _version = 'Error: ${e.toString()}';
      });
    }
  }

  /// Start data collection
  Future<void> _startCollection() async {
    if (!_isConnected) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please connect to the service first'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      final response = await _plugin.startDataCollection();
      setState(() {
        _isCollecting = response.success;
      });

      if (response.success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Data collection started'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Failed to start collection: ${response.error ?? response.message}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error starting collection: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  /// Stop data collection
  Future<void> _stopCollection() async {
    try {
      final response = await _plugin.stopDataCollection();
      setState(() {
        _isCollecting = !response.success;
      });

      if (response.success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Data collection stopped'),
            backgroundColor: Colors.orange,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Failed to stop collection: ${response.error ?? response.message}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error stopping collection: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  /// Disconnect from service
  Future<void> _disconnect() async {
    try {
      await _plugin.disconnect();
      setState(() {
        _isConnected = false;
        _isCollecting = false;
        _status = 'Disconnected';
        _version = 'Unknown';
        _dataHistory.clear();
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error disconnecting: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  /// Test connection (diagnostic)
  Future<void> _testConnection() async {
    if (!_plugin.isDesktop) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text('Connection test is only available on desktop platforms'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _status = 'Running connection test...');

    try {
      final result = await _plugin.testConnection();
      setState(() {
        _connectionTest = result;
        _status = 'Connection test completed';
      });

      // Show test results dialog
      if (mounted) {
        _showTestResultsDialog(result);
      }
    } catch (e) {
      setState(() {
        _status = 'Connection test failed: ${e.toString()}';
      });
    }
  }

  /// Show test results in a dialog
  void _showTestResultsDialog(Map<String, dynamic> results) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Connection Test Results'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildTestResult('Daemon Detection', results['daemonDetection']),
              const SizedBox(height: 16),
              _buildTestResult(
                  'Socket Connection', results['socketConnection']),
              const SizedBox(height: 16),
              _buildTestResult('Version Command', results['versionCommand']),
              if (results['error'] != null) ...[
                const SizedBox(height: 16),
                Text(
                  'Error: ${results['error']}',
                  style: const TextStyle(color: Colors.red),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  /// Build test result widget
  Widget _buildTestResult(String title, dynamic result) {
    if (result == null) {
      return Text('$title: Not tested');
    }

    final success = result['success'] as bool? ?? false;
    final duration = result['duration'] as int? ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              success ? Icons.check_circle : Icons.error,
              color: success ? Colors.green : Colors.red,
              size: 16,
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text('Duration: ${duration}ms'),
        if (result['daemon'] != null) ...[
          const SizedBox(height: 4),
          Text('Port: ${result['daemon']['port']}'),
          Text('Version: ${result['daemon']['version']}'),
        ],
      ],
    );
  }

  /// Clear data history
  void _clearHistory() {
    setState(() {
      _dataHistory.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () => _showInfoDialog(),
          ),
        ],
      ),
      body: Padding(
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
                    Row(
                      children: [
                        Icon(
                          _isConnected ? Icons.cloud_done : Icons.cloud_off,
                          color: _isConnected ? Colors.green : Colors.grey,
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Service Status',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text('Status: $_status'),
                    Text('Version: $_version'),
                    Text('Platform: ${_plugin.currentPlatform.name}'),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          _deviceConnected ? Icons.usb : Icons.usb_off,
                          color: _deviceConnected ? Colors.green : Colors.grey,
                          size: 16,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _deviceConnected ? 'Device Connected' : 'No Device',
                          style: TextStyle(
                            color:
                                _deviceConnected ? Colors.green : Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Control Buttons
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ElevatedButton.icon(
                  onPressed: _isConnected ? null : _connect,
                  icon: const Icon(Icons.connect_without_contact),
                  label: const Text('Connect'),
                ),
                ElevatedButton.icon(
                  onPressed: _isConnected ? _disconnect : null,
                  icon: const Icon(Icons.link_off),
                  label: const Text('Disconnect'),
                ),
                ElevatedButton.icon(
                  onPressed: _isCollecting ? _stopCollection : _startCollection,
                  icon: Icon(_isCollecting ? Icons.stop : Icons.play_arrow),
                  label: Text(
                      _isCollecting ? 'Stop Collection' : 'Start Collection'),
                ),
                ElevatedButton.icon(
                  onPressed: _plugin.isDesktop ? _testConnection : null,
                  icon: const Icon(Icons.network_check),
                  label: const Text('Test Connection'),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Data Collection Status
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Data Collection',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          _isCollecting ? 'Active' : 'Stopped',
                          style: TextStyle(
                            color: _isCollecting ? Colors.green : Colors.grey,
                          ),
                        ),
                        Text('Records: ${_dataHistory.length}'),
                      ],
                    ),
                    if (_dataHistory.isNotEmpty)
                      ElevatedButton.icon(
                        onPressed: _clearHistory,
                        icon: const Icon(Icons.clear_all),
                        label: const Text('Clear'),
                      ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Data History
            Expanded(
              child: Card(
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16.0),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceVariant,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(12),
                          topRight: Radius.circular(12),
                        ),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.timeline),
                          SizedBox(width: 8),
                          Text(
                            'Real-time Data',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: _dataHistory.isEmpty
                          ? const Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.data_usage_outlined,
                                    size: 64,
                                    color: Colors.grey,
                                  ),
                                  SizedBox(height: 16),
                                  Text(
                                    'No data received yet',
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: Colors.grey,
                                    ),
                                  ),
                                  SizedBox(height: 8),
                                  Text(
                                    'Connect to service and start data collection',
                                    style: TextStyle(color: Colors.grey),
                                  ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              itemCount: _dataHistory.length,
                              itemBuilder: (context, index) {
                                final data = _dataHistory[index];
                                final isLatest = index == 0;
                                return Container(
                                  margin: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isLatest
                                        ? Colors.green.withOpacity(0.1)
                                        : null,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: ListTile(
                                    dense: true,
                                    leading: CircleAvatar(
                                      backgroundColor:
                                          isLatest ? Colors.green : Colors.grey,
                                      radius: 16,
                                      child: Text(
                                        '${data.value}',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    title: Text(
                                      'MAC: ${data.mac}',
                                      style: const TextStyle(fontSize: 14),
                                    ),
                                    subtitle: Text(
                                      'Time: ${_formatTimestamp(data.timestamp)}',
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                    trailing: data.pid != null
                                        ? Chip(
                                            label: Text(
                                              'PID: ${data.pid}',
                                              style:
                                                  const TextStyle(fontSize: 10),
                                            ),
                                            materialTapTargetSize:
                                                MaterialTapTargetSize
                                                    .shrinkWrap,
                                          )
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

  /// Format timestamp for display
  String _formatTimestamp(String timestamp) {
    try {
      final dateTime = DateTime.parse(timestamp);
      final now = DateTime.now();
      final difference = now.difference(dateTime);

      if (difference.inSeconds < 60) {
        return '${difference.inSeconds}s ago';
      } else if (difference.inMinutes < 60) {
        return '${difference.inMinutes}m ago';
      } else {
        return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}:${dateTime.second.toString().padLeft(2, '0')}';
      }
    } catch (e) {
      return timestamp;
    }
  }

  /// Show info dialog
  void _showInfoDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('SNAPPY Plugin Info'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Platform Support:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              _buildPlatformInfo(
                  'Windows', _plugin.currentPlatform == SnappyPlatform.windows),
              _buildPlatformInfo(
                  'Linux', _plugin.currentPlatform == SnappyPlatform.linux),
              _buildPlatformInfo(
                  'macOS', _plugin.currentPlatform == SnappyPlatform.macos),
              _buildPlatformInfo(
                  'Android', _plugin.currentPlatform == SnappyPlatform.android,
                  note: 'Coming Soon'),
              const SizedBox(height: 16),
              const Text(
                'Features:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text('• Real-time data streaming'),
              const Text('• Automatic daemon detection'),
              const Text('• Connection monitoring'),
              const Text('• Device status tracking'),
              const Text('• Socket.IO communication'),
              const SizedBox(height: 16),
              const Text(
                'Requirements:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text('• snappy_web_agent daemon running'),
              const Text('• SNAPPY device connected via USB'),
              const Text('• Ports 8436-8535 available'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  /// Build platform info widget
  Widget _buildPlatformInfo(String platform, bool isActive, {String? note}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(
            isActive ? Icons.check_circle : Icons.radio_button_unchecked,
            color: isActive ? Colors.green : Colors.grey,
            size: 16,
          ),
          const SizedBox(width: 8),
          Text(platform),
          if (note != null) ...[
            const SizedBox(width: 8),
            Chip(
              label: Text(
                note,
                style: const TextStyle(fontSize: 10),
              ),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ],
        ],
      ),
    );
  }
}
