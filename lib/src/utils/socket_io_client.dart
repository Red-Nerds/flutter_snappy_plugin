import 'dart:async';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import '../models/models.dart';

/// Wrapper around Socket.IO client for SNAPPY daemon communication
class SnappySocketClient {
  IO.Socket? _socket;
  final String _url;

  final StreamController<bool> _connectionController =
      StreamController<bool>.broadcast();
  final StreamController<DeviceConnectionEvent> _deviceController =
      StreamController<DeviceConnectionEvent>.broadcast();
  final StreamController<SnapData> _dataController =
      StreamController<SnapData>.broadcast();

  bool _isConnected = false;
  bool _isDisposed = false;

  SnappySocketClient(this._url);

  /// Stream of connection status
  Stream<bool> get connectionStream => _connectionController.stream;

  /// Stream of device connection events
  Stream<DeviceConnectionEvent> get deviceConnectionStream =>
      _deviceController.stream;

  /// Stream of real-time snap data
  Stream<SnapData> get dataStream => _dataController.stream;

  /// Check if socket is connected
  bool get isConnected => _isConnected && _socket?.connected == true;

  /// Connect to the snappy_web_agent daemon
  Future<bool> connect() async {
    if (_isDisposed) throw StateError('Client has been disposed');

    try {
      await disconnect(); // Ensure clean state

      print('SocketIO: Attempting to connect to $_url');

      _socket = IO.io(
          _url,
          IO.OptionBuilder()
              .setTransports(['websocket', 'polling']) // Allow both transports
              .enableForceNew() // Force new connection
              .enableAutoConnect() // Auto connect
              .setTimeout(10000) // 10 second timeout
              .enableReconnection() // Enable reconnection
              .setReconnectionAttempts(3)
              .setReconnectionDelay(1000)
              .build());

      _setupSocketHandlers();

      final completer = Completer<bool>();

      // Set up one-time connection handlers
      late void Function(dynamic) onConnectHandler;
      late void Function(dynamic) onConnectErrorHandler;

      onConnectHandler = (_) {
        print('SocketIO: Connected successfully to $_url');
        _isConnected = true;
        _connectionController.add(true);
        if (!completer.isCompleted) completer.complete(true);

        // Remove one-time handlers
        _socket?.off('connect', onConnectHandler);
        _socket?.off('connect_error', onConnectErrorHandler);
      };

      onConnectErrorHandler = (error) {
        print('SocketIO: Connection error: $error');
        _isConnected = false;
        _connectionController.add(false);
        if (!completer.isCompleted) completer.complete(false);

        // Remove one-time handlers
        _socket?.off('connect', onConnectHandler);
        _socket?.off('connect_error', onConnectErrorHandler);
      };

      _socket!.on('connect', onConnectHandler);
      _socket!.on('connect_error', onConnectErrorHandler);

      // Manually connect if needed (some versions require this)
      if (!_socket!.connected) {
        _socket!.connect();
      }

      // Wait for connection or timeout
      final result = await completer.future.timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          print('SocketIO: Connection timeout');
          _isConnected = false;
          _connectionController.add(false);
          return false;
        },
      );

      return result;
    } catch (e) {
      print('SocketIO: Connection exception: $e');
      _isConnected = false;
      _connectionController.add(false);
      return false;
    }
  }

  /// Setup Socket.IO event handlers
  void _setupSocketHandlers() {
    if (_socket == null) return;

    print('SocketIO: Setting up event handlers');

    // Connection status handlers
    _socket!.on('connect', (_) {
      print('SocketIO: Connected');
      _isConnected = true;
      _connectionController.add(true);
    });

    _socket!.on('disconnect', (reason) {
      print('SocketIO: Disconnected - reason: $reason');
      _isConnected = false;
      _connectionController.add(false);
    });

    _socket!.on('connect_error', (error) {
      print('SocketIO: Connect error: $error');
      _isConnected = false;
      _connectionController.add(false);
    });

    _socket!.on('error', (error) {
      print('SocketIO: General error: $error');
    });

    // 1. Device connection events - Listen for "device-connected"
    _socket!.on('device-connected', (data) {
      print('SocketIO: Received device-connected event: $data');
      try {
        if (data is Map<String, dynamic>) {
          final event = DeviceConnectionEvent.fromJson(data);
          _deviceController.add(event);
        } else {
          print('SocketIO: Invalid device-connected data format: $data');
        }
      } catch (e) {
        print('SocketIO: Error parsing device-connected event: $e');
      }
    });

    // 2. Real-time data events - Listen for "snappy-data"
    _socket!.on('snappy-data', (data) {
      print('SocketIO: Received snappy-data event: $data');
      try {
        if (data is Map<String, dynamic>) {
          final snapData = SnapData.fromJson(data);
          _dataController.add(snapData);
        } else {
          print('SocketIO: Invalid snappy-data format: $data');
        }
      } catch (e) {
        print('SocketIO: Error parsing snappy-data: $e');
      }
    });

    // Auto-reconnection handling
    _socket!.onReconnect((attempt) {
      print('SocketIO: Reconnected after $attempt attempts');
      _isConnected = true;
      _connectionController.add(true);
    });

    _socket!.onReconnectError((error) {
      print('SocketIO: Reconnection error: $error');
    });

    _socket!.onReconnectAttempt((attempt) {
      print('SocketIO: Reconnection attempt $attempt');
    });
  }

  /// 3. Send "start-snappy" command to start data collection
  Future<PluginResponse> startDataCollection() async {
    return await sendCommand('start-snappy');
  }

  /// 4. Send "stop-snappy" command to stop data collection
  Future<PluginResponse> stopDataCollection() async {
    return await sendCommand('stop-snappy');
  }

  /// 5. Send "version" command to get daemon version
  Future<PluginResponse> getVersion() async {
    return await sendCommand('version');
  }

  /// Send command to daemon and wait for response
  Future<PluginResponse> sendCommand(String event,
      {Map<String, dynamic>? data}) async {
    if (!isConnected) {
      return PluginResponse(
        success: false,
        message: 'Not connected to daemon',
        command: event,
        error: 'CONNECTION_ERROR',
      );
    }

    try {
      print('SocketIO: Sending command "$event" with data: $data');

      final completer = Completer<PluginResponse>();

      // Use emitWithAck to get response from daemon
      _socket!.emitWithAck(event, data, ack: (response) {
        print('SocketIO: Received response for "$event": $response');

        try {
          Map<String, dynamic>? responseData;

          // Handle both List and direct Map response formats
          if (response is List && response.isNotEmpty) {
            responseData = response.first as Map<String, dynamic>;
          } else if (response is Map<String, dynamic>) {
            responseData = response;
          }

          if (responseData != null) {
            final pluginResponse = PluginResponse.fromJson(responseData);
            completer.complete(pluginResponse);
          } else {
            completer.complete(PluginResponse(
              success: false,
              message: 'Invalid response format: $response',
              command: event,
              error: 'INVALID_RESPONSE',
            ));
          }
        } catch (e) {
          completer.complete(PluginResponse(
            success: false,
            message: 'Error parsing response: ${e.toString()}',
            command: event,
            error: 'PARSE_ERROR',
          ));
        }
      });

      // Wait for response with timeout
      return await completer.future.timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          return PluginResponse(
            success: false,
            message: 'Command timeout',
            command: event,
            error: 'TIMEOUT',
          );
        },
      );
    } catch (e) {
      print('SocketIO: Error sending command "$event": $e');
      return PluginResponse(
        success: false,
        message: 'Error sending command: ${e.toString()}',
        command: event,
        error: 'SEND_ERROR',
      );
    }
  }

  /// Disconnect from the daemon
  Future<void> disconnect() async {
    if (_socket != null) {
      print('SocketIO: Disconnecting from $_url');

      _socket!.disconnect();
      _socket!.dispose();
      _socket = null;
    }

    _isConnected = false;
    _connectionController.add(false);
  }

  /// Dispose all resources
  Future<void> dispose() async {
    if (_isDisposed) return;

    print('SocketIO: Disposing client');
    _isDisposed = true;

    await disconnect();

    await _connectionController.close();
    await _deviceController.close();
    await _dataController.close();
  }
}
