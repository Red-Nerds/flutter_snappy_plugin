import 'dart:async';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import '../models/models.dart';

/// Wrapper around Socket.IO client for SNAPPY daemon communication
class SnappySocketClient {
  IO.Socket? _socket;
  final String _url;

  final StreamController<bool> _connectionController = StreamController<bool>.broadcast();
  final StreamController<DeviceConnectionEvent> _deviceController = StreamController<DeviceConnectionEvent>.broadcast();
  final StreamController<SnapData> _dataController = StreamController<SnapData>.broadcast();

  bool _isConnected = false;
  bool _isDisposed = false;

  SnappySocketClient(this._url);

  /// Stream of connection status
  Stream<bool> get connectionStream => _connectionController.stream;

  /// Stream of device connection events
  Stream<DeviceConnectionEvent> get deviceConnectionStream => _deviceController.stream;

  /// Stream of real-time snap data
  Stream<SnapData> get dataStream => _dataController.stream;

  /// Check if socket is connected
  bool get isConnected => _isConnected && _socket?.connected == true;

  /// Connect to the snappy_web_agent daemon
  Future<bool> connect() async {
    if (_isDisposed) throw StateError('Client has been disposed');

    try {
      await disconnect(); // Ensure clean state

      _socket = IO.io(_url,
          IO.OptionBuilder()
              .setTransports(['websocket'])
              .disableAutoConnect()
              .setTimeout(5000)
              .enableReconnection()
              .setReconnectionAttempts(5)
              .setReconnectionDelay(2000)
              .build()
      );

      _setupSocketHandlers();

      final completer = Completer<bool>();

      _socket!.onConnect((_) {
        _isConnected = true;
        _connectionController.add(true);
        if (!completer.isCompleted) completer.complete(true);
      });

      _socket!.onConnectError((error) {
        _isConnected = false;
        _connectionController.add(false);
        if (!completer.isCompleted) completer.complete(false);
      });

      // Wait for connection or timeout
      return await completer.future.timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          _isConnected = false;
          _connectionController.add(false);
          return false;
        },
      );

    } catch (e) {
      _isConnected = false;
      _connectionController.add(false);
      return false;
    }
  }

  /// Setup Socket.IO event handlers
  void _setupSocketHandlers() {
    if (_socket == null) return;

    // Connection status handlers
    _socket!.onConnect((_) {
      _isConnected = true;
      _connectionController.add(true);
    });

    _socket!.onDisconnect((_) {
      _isConnected = false;
      _connectionController.add(false);
    });

    _socket!.onConnectError((error) {
      _isConnected = false;
      _connectionController.add(false);
    });

    _socket!.onError((error) {
      // Log error but don't disconnect unless it's a connection error
    });

    // Device connection events
    _socket!.on('device-connected', (data) {
      try {
        final event = DeviceConnectionEvent.fromJson(data as Map<String, dynamic>);
        _deviceController.add(event);
      } catch (e) {
        // Invalid data format, ignore
      }
    });

    // Real-time data events
    _socket!.on('snappy-data', (data) {
      try {
        final snapData = SnapData.fromJson(data as Map<String, dynamic>);
        _dataController.add(snapData);
      } catch (e) {
        // Invalid data format, ignore
      }
    });

    // Auto-reconnection handling
    _socket!.onReconnect((attempt) {
      _isConnected = true;
      _connectionController.add(true);
    });
  }

  /// Send command to daemon and wait for response
  Future<PluginResponse> sendCommand(String event, {Map<String, dynamic>? data}) async {
    if (!isConnected) {
      return PluginResponse(
        success: false,
        message: 'Not connected to daemon',
        command: event,
        error: 'CONNECTION_ERROR',
      );
    }

    try {
      final completer = Completer<PluginResponse>();

      _socket!.emitWithAck(event, data != null ? [data] : [], ack: (response) {
        try {
          if (response is List && response.isNotEmpty) {
            final responseData = response.first as Map<String, dynamic>;
            final pluginResponse = PluginResponse.fromJson(responseData);
            completer.complete(pluginResponse);
          } else {
            completer.complete(PluginResponse(
              success: false,
              message: 'Invalid response format',
              command: event,
              error: 'INVALID_RESPONSE',
            ));
          }
        } catch (e) {
          completer.complete(PluginResponse(
            success: false,
            message: 'Failed to parse response: ${e.toString()}',
            command: event,
            error: 'PARSE_ERROR',
          ));
        }
      });

      return await completer.future.timeout(
        const Duration(seconds: 10),
        onTimeout: () => PluginResponse(
          success: false,
          message: 'Command timeout',
          command: event,
          error: 'TIMEOUT',
        ),
      );

    } catch (e) {
      return PluginResponse(
        success: false,
        message: 'Command failed: ${e.toString()}',
        command: event,
        error: 'COMMAND_ERROR',
      );
    }
  }

  /// Get daemon version
  Future<PluginResponse> getVersion() async {
    return await sendCommand('version');
  }

  /// Start data collection
  Future<PluginResponse> startDataCollection() async {
    return await sendCommand('start-snappy');
  }

  /// Stop data collection
  Future<PluginResponse> stopDataCollection() async {
    return await sendCommand('stop-snappy');
  }

  /// Get device information
  Future<PluginResponse> getDeviceInfo() async {
    return await sendCommand('device-info');
  }

  /// Disconnect from daemon
  Future<void> disconnect() async {
    if (_socket != null) {
      _socket!.dispose();
      _socket = null;
    }
    _isConnected = false;
    _connectionController.add(false);
  }

  /// Dispose resources and close streams
  Future<void> dispose() async {
    if (_isDisposed) return;

    _isDisposed = true;
    await disconnect();

    await _connectionController.close();
    await _deviceController.close();
    await _dataController.close();
  }
}