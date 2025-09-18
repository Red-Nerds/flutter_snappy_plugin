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
      print('DesktopService: Starting connection process');

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

      print('DesktopService: Found daemon at ${daemon.url}');
      _currentDaemon = daemon;

      // Create socket client and connect
      _socketClient = SnappySocketClient(daemon.url);
      final connected = await _socketClient!.connect();

      if (!connected) {
        _emitConnectionStatus(false, 'Failed to connect to daemon');
        return PluginResponse(
          success: false,
          message: 'Failed to connect to SNAPPY Web Agent daemon at ${daemon.url}',
          command: 'connect',
          error: 'CONNECTION_FAILED',
        );
      }

      // Setup stream forwarding
      _setupStreamForwarding();

      // Start monitoring
      _startDaemonMonitoring();

      _isConnected = true;
      _emitConnectionStatus(true, 'Connected to SNAPPY Web Agent v${daemon.version}');

      return PluginResponse(
        success: true,
        message: 'Connected to SNAPPY Web Agent v${daemon.version} at ${daemon.url}',
        command: 'connect',
      );

    } catch (e) {
      print('DesktopService: Connection error: $e');
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
        message: 'Not connected to daemon',
        command: 'start-snappy',
        error: 'NOT_CONNECTED',
      );
    }

    print('DesktopService: Starting data collection');
    return await _socketClient!.startDataCollection();
  }

  @override
  Future<PluginResponse> stopDataCollection() async {
    if (!isCurrentlyConnected) {
      return PluginResponse(
        success: false,
        message: 'Not connected to daemon',
        command: 'stop-snappy',
        error: 'NOT_CONNECTED',
      );
    }

    print('DesktopService: Stopping data collection');
    return await _socketClient!.stopDataCollection();
  }

  @override
  Future<PluginResponse> getVersion() async {
    if (!isCurrentlyConnected) {
      return PluginResponse(
        success: false,
        message: 'Not connected to daemon',
        command: 'version',
        error: 'NOT_CONNECTED',
      );
    }

    print('DesktopService: Getting version');
    return await _socketClient!.getVersion();
  }

  @override
  Future<void> disconnect() async {
    print('DesktopService: Disconnecting');
    await _cleanupConnection();
    _isConnected = false;
    _emitConnectionStatus(false, 'Disconnected');
  }

  @override
  Future<bool> isServiceAvailable() async {
    try {
      final daemon = await DaemonDetector.detectDaemon();
      return daemon != null;
    } catch (e) {
      print('DesktopService: Error checking service availability: $e');
      return false;
    }
  }

  @override
  Future<void> dispose() async {
    if (_isDisposed) return;

    print('DesktopService: Disposing');
    _isDisposed = true;

    _monitorTimer?.cancel();
    await _connectionSub?.cancel();
    await _deviceSub?.cancel();
    await _dataSub?.cancel();

    await _cleanupConnection();

    await _connectionController.close();
    await _deviceConnectionController.close();
    await _dataController.close();
  }

  /// Emit connection status to stream
  void _emitConnectionStatus(bool connected, String message) {
    print('DesktopService: Status update - Connected: $connected, Message: $message');
    _isConnected = connected;
    _connectionController.add(connected);
  }

  /// Clean up current connection
  Future<void> _cleanupConnection() async {
    _monitorTimer?.cancel();
    _monitorTimer = null;

    await _connectionSub?.cancel();
    await _deviceSub?.cancel();
    await _dataSub?.cancel();

    _connectionSub = null;
    _deviceSub = null;
    _dataSub = null;

    if (_socketClient != null) {
      await _socketClient!.dispose();
      _socketClient = null;
    }

    _currentDaemon = null;
  }

  /// Setup stream forwarding from socket client to service streams
  void _setupStreamForwarding() {
    if (_socketClient == null) return;

    print('DesktopService: Setting up stream forwarding');

    // Forward connection status
    _connectionSub = _socketClient!.connectionStream.listen(
          (connected) {
        _isConnected = connected;
        _connectionController.add(connected);
      },
      onError: (error) {
        print('DesktopService: Connection stream error: $error');
        _connectionController.addError(SnappyPluginException(
          'Connection stream error: ${error.toString()}',
          code: 'CONNECTION_STREAM_ERROR',
          originalError: error,
        ));
      },
    );

    // Forward device connection events
    _deviceSub = _socketClient!.deviceConnectionStream.listen(
          (event) {
        print('DesktopService: Device event received: ${event.toString()}');
        _deviceConnected = event.isConnected;
        _deviceConnectionController.add(event.isConnected);
      },
      onError: (error) {
        print('DesktopService: Device stream error: $error');
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
        print('DesktopService: Data received: ${data.toString()}');
        _dataController.add(data);
      },
      onError: (error) {
        print('DesktopService: Data stream error: $error');
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
    _monitorTimer = Timer.periodic(const Duration(seconds: 30), (timer) async {
      if (_isDisposed) {
        timer.cancel();
        return;
      }

      // Check if current daemon is still available
      if (_currentDaemon != null && !isCurrentlyConnected) {
        print('DesktopService: Connection lost, attempting to reconnect');

        // Try to reconnect
        final stillAvailable = await _testDaemonAvailability(_currentDaemon!);
        if (stillAvailable && _socketClient != null) {
          final reconnected = await _socketClient!.connect();
          if (reconnected) {
            print('DesktopService: Reconnected successfully');
            _isConnected = true;
            _connectionController.add(true);
          }
        }
      }
    });
  }

  /// Test if daemon is still available
  Future<bool> _testDaemonAvailability(DaemonInfo daemon) async {
    try {
      return await DaemonDetector.isPortOpen('localhost', daemon.port);
    } catch (e) {
      return false;
    }
  }

  /// Test connection without full connect (for diagnostics)
  Future<Map<String, dynamic>> testConnection() async {
    final results = <String, dynamic>{};

    try {
      print('DesktopService: Running connection diagnostics');

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

      // Test port availability
      final availablePorts = await DaemonDetector.getAvailablePorts();
      results['availablePorts'] = availablePorts;

    } catch (e) {
      results['error'] = e.toString();
    }

    return results;
  }
}