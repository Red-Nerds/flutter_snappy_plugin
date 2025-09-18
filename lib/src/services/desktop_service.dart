import 'dart:async';
import 'dart:io';

import 'snappy_service.dart';
import 'daemon_detector.dart';
import '../utils/socket_io_client.dart';
import '../models/models.dart';

/// Desktop implementation of SnappyService using Socket.IO communication with snappy_web_agent
class DesktopSnappyService extends SnappyService {
  SnappySocketClient? _socketClient;
  DaemonInfo? _currentDaemon;

  final StreamController<bool> _connectionController = StreamController<bool>.broadcast();
  final StreamController<bool> _deviceConnectionController = StreamController<bool>.broadcast();
  final StreamController<SnapData> _dataController = StreamController<SnapData>.broadcast();

  bool _isDisposed = false;
  bool _isConnected = false;
  bool _deviceConnected = false;
  Timer? _monitorTimer;
  StreamSubscription<bool>? _connectionSub;
  StreamSubscription<DeviceConnectionEvent>? _deviceSub;
  StreamSubscription<SnapData>? _dataSub;

  @override
  Stream<bool> get isConnected => _connectionController.stream;

  @override
  Stream<bool> get deviceConnected => _deviceConnectionController.stream;

  @override
  Stream<SnapData> get dataStream => _dataController.stream;

  @override
  bool get isCurrentlyConnected => _isConnected && (_socketClient?.isConnected ?? false);

  @override
  bool get isDeviceCurrentlyConnected => _deviceConnected;

  @override
  Future<PluginResponse> connect() async {
    if (_isDisposed) {
      return PluginResponse(
        success: false,
        message: 'Service has been disposed',
        command: 'connect',
        error: 'SERVICE_DISPOSED',
      );
    }

    try {
      // Clean up any existing connections
      await _cleanupConnection();

      // Detect the daemon
      _emitConnectionStatus(false, 'Searching for SNAPPY Web Agent daemon...');
      final daemon = await DaemonDetector.detectDaemon();
      if (daemon == null) {
        _emitConnectionStatus(false, 'Daemon not found');
        return PluginResponse(
          success: false,
          message: 'SNAPPY Web Agent daemon not found. Please ensure the daemon is running on ports 8436-8535.',
          command: 'connect',
          error: 'DAEMON_NOT_FOUND',
        );
      }

      _currentDaemon = daemon;
      _emitConnectionStatus(false, 'Daemon found on port ${daemon.port}, connecting...');

      // Create socket client
      _socketClient = SnappySocketClient(daemon.url);

      // Set up stream forwarding before connecting
      _setupStreamForwarding();

      // Connect to daemon
      final connected = await _socketClient!.connect();
      if (!connected) {
        _emitConnectionStatus(false, 'Connection failed');
        return PluginResponse(
          success: false,
          message: 'Failed to connect to SNAPPY Web Agent daemon at ${daemon.url}',
          command: 'connect',
          error: 'CONNECTION_FAILED',
        );
      }

      // Connection successful
      _isConnected = true;
      _emitConnectionStatus(true, 'Connected to daemon v${daemon.version}');

      // Start daemon monitoring
      _startDaemonMonitoring();

      return PluginResponse(
        success: true,
        message: 'Connected to SNAPPY Web Agent v${daemon.version} on port ${daemon.port}',
        command: 'connect',
      );

    } catch (e) {
      _emitConnectionStatus(false, 'Connection error: ${e.toString()}');
      return PluginResponse(
        success: false,
        message: 'Connection error: ${e.toString()}',
        command: 'connect',
        error: 'CONNECTION_ERROR',
      );
    }
  }

  @override
  Future<PluginResponse> startDataCollection() async {
    if (!isCurrentlyConnected) {
      return PluginResponse(
        success: false,
        message: 'Not connected to daemon. Call connect() first.',
        command: 'start-snappy',
        error: 'NOT_CONNECTED',
      );
    }

    try {
      final response = await _socketClient!.startDataCollection();
      return response;
    } catch (e) {
      return PluginResponse(
        success: false,
        message: 'Start data collection failed: ${e.toString()}',
        command: 'start-snappy',
        error: 'START_FAILED',
      );
    }
  }

  @override
  Future<PluginResponse> stopDataCollection() async {
    if (!isCurrentlyConnected) {
      return PluginResponse(
        success: false,
        message: 'Not connected to daemon. Call connect() first.',
        command: 'stop-snappy',
        error: 'NOT_CONNECTED',
      );
    }

    try {
      final response = await _socketClient!.stopDataCollection();
      return response;
    } catch (e) {
      return PluginResponse(
        success: false,
        message: 'Stop data collection failed: ${e.toString()}',
        command: 'stop-snappy',
        error: 'STOP_FAILED',
      );
    }
  }

  @override
  Future<PluginResponse> getVersion() async {
    if (!isCurrentlyConnected) {
      return PluginResponse(
        success: false,
        message: 'Not connected to daemon. Call connect() first.',
        command: 'version',
        error: 'NOT_CONNECTED',
      );
    }

    try {
      final response = await _socketClient!.getVersion();
      return response;
    } catch (e) {
      return PluginResponse(
        success: false,
        message: 'Get version failed: ${e.toString()}',
        command: 'version',
        error: 'VERSION_FAILED',
      );
    }
  }

  @override
  Future<void> disconnect() async {
    await _cleanupConnection();
    _emitConnectionStatus(false, 'Disconnected');
  }

  @override
  Future<bool> isServiceAvailable() async {
    try {
      final daemon = await DaemonDetector.detectDaemon();
      return daemon != null;
    } catch (e) {
      return false;
    }
  }

  @override
  Future<void> dispose() async {
    if (_isDisposed) return;

    _isDisposed = true;
    await _cleanupConnection();

    // Close all stream controllers
    await _connectionController.close();
    await _deviceConnectionController.close();
    await _dataController.close();
  }

  /// Clean up connection and resources
  Future<void> _cleanupConnection() async {
    _stopDaemonMonitoring();

    // Cancel stream subscriptions
    await _connectionSub?.cancel();
    await _deviceSub?.cancel();
    await _dataSub?.cancel();
    _connectionSub = null;
    _deviceSub = null;
    _dataSub = null;

    // Dispose socket client
    if (_socketClient != null) {
      await _socketClient!.dispose();
      _socketClient = null;
    }

    _currentDaemon = null;
    _isConnected = false;
    _deviceConnected = false;
  }

  /// Setup stream forwarding from socket client to service streams
  void _setupStreamForwarding() {
    if (_socketClient == null) return;

    // Forward connection status
    _connectionSub = _socketClient!.connectionStream.listen(
          (connected) {
        _isConnected = connected;
        _connectionController.add(connected);
      },
      onError: (error) {
        _isConnected = false;
        _connectionController.add(false);
        _connectionController.addError(SnappyPluginException(
          'Connection error: ${error.toString()}',
          code: 'CONNECTION_ERROR',
          originalError: error,
        ));
      },
    );

    // Forward device connection events
    _deviceSub = _socketClient!.deviceConnectionStream.listen(
          (event) {
        _deviceConnected = event.isConnected;
        _deviceConnectionController.add(event.isConnected);
      },
      onError: (error) {
        _deviceConnectionController.addError(SnappyPluginException(
          'Device connection error: ${error.toString()}',
          code: 'DEVICE_ERROR',
          originalError: error,
        ));
      },
    );

    // Forward snap data
    _dataSub = _socketClient!.dataStream.listen(
          (data) {
        _dataController.add(data);
      },
      onError: (error) {
        _dataController.addError(SnappyPluginException(
          'Data stream error: ${error.toString()}',
          code: 'DATA_ERROR',
          originalError: error,
        ));
      },
    );
  }

  /// Start periodic daemon monitoring
  void _startDaemonMonitoring() {
    _monitorTimer?.cancel();
    _monitorTimer = Timer.periodic(const Duration(seconds: 15), (timer) async {
      if (_isDisposed) {
        timer.cancel();
        return;
      }

      // Check if current daemon is still available
      if (_currentDaemon != null && isCurrentlyConnected) {
        final stillAvailable = await _testDaemonAvailability(_currentDaemon!);
        if (!stillAvailable) {
          // Daemon is no longer available, try to reconnect
          await _handleDaemonLost();
        }
      }
    });
  }

  /// Stop daemon monitoring
  void _stopDaemonMonitoring() {
    _monitorTimer?.cancel();
    _monitorTimer = null;
  }

  /// Test if daemon is still available
  Future<bool> _testDaemonAvailability(DaemonInfo daemon) async {
    try {
      // Simple connectivity test - try to create a quick connection
      final testClient = SnappySocketClient(daemon.url);
      final connected = await testClient.connect();
      if (connected) {
        await testClient.dispose();
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  /// Handle daemon loss and attempt reconnection
  Future<void> _handleDaemonLost() async {
    _emitConnectionStatus(false, 'Lost connection to daemon, attempting to reconnect...');

    // Try to find daemon on same or different port
    final newDaemon = await DaemonDetector.detectDaemon();
    if (newDaemon != null) {
      // Attempt reconnection
      final result = await connect();
      if (result.success) {
        _emitConnectionStatus(true, 'Reconnected successfully');
        return;
      }
    }

    // Could not reconnect
    _emitConnectionStatus(false, 'Could not reconnect to daemon');
    _connectionController.addError(
        SnappyPluginException(
            'Lost connection to SNAPPY Web Agent daemon and could not reconnect',
            code: 'DAEMON_LOST'
        )
    );
  }

  /// Emit connection status to stream with optional message
  void _emitConnectionStatus(bool connected, String message) {
    _isConnected = connected;
    _connectionController.add(connected);

    // You could also emit status messages if needed
    // This is useful for debugging or showing detailed status to users
  }

  /// Get daemon information
  DaemonInfo? get currentDaemon => _currentDaemon;

  /// Get detailed connection status
  Map<String, dynamic> getConnectionStatus() {
    return {
      'isConnected': isCurrentlyConnected,
      'isDeviceConnected': isDeviceCurrentlyConnected,
      'daemon': _currentDaemon != null ? {
        'url': _currentDaemon!.url,
        'port': _currentDaemon!.port,
        'version': _currentDaemon!.version,
        'detectedAt': _currentDaemon!.detectedAt.toIso8601String(),
      } : null,
      'socketConnected': _socketClient?.isConnected ?? false,
    };
  }

  /// Test connection without full connect (for diagnostics)
  Future<Map<String, dynamic>> testConnection() async {
    final results = <String, dynamic>{};

    try {
      // Test daemon detection
      final detectStart = DateTime.now();
      final daemon = await DaemonDetector.detectDaemon();
      final detectDuration = DateTime.now().difference(detectStart);

      results['daemonDetection'] = {
        'success': daemon != null,
        'duration': detectDuration.inMilliseconds,
        'daemon': daemon != null ? {
          'port': daemon.port,
          'version': daemon.version,
          'url': daemon.url,
        } : null,
      };

      if (daemon != null) {
        // Test socket connection
        final connectStart = DateTime.now();
        final testClient = SnappySocketClient(daemon.url);
        final connected = await testClient.connect();
        final connectDuration = DateTime.now().difference(connectStart);

        results['socketConnection'] = {
          'success': connected,
          'duration': connectDuration.inMilliseconds,
        };

        if (connected) {
          // Test version command
          final versionStart = DateTime.now();
          final versionResponse = await testClient.getVersion();
          final versionDuration = DateTime.now().difference(versionStart);

          results['versionCommand'] = {
            'success': versionResponse.success,
            'duration': versionDuration.inMilliseconds,
            'response': versionResponse.toJson(),
          };
        }

        await testClient.dispose();
      }

    } catch (e) {
      results['error'] = e.toString();
    }

    return results;
  }
}