import 'dart:async';
import 'dart:io';
import 'package:socket_io_client/socket_io_client.dart' as io;
import '../models/models.dart';

/// Daemon detection and connection management for snappy_web_agent
class DaemonDetector {
  static const int _startPort = 8436;
  static const int _endPort = 8535;
  static const Duration _connectionTimeout = Duration(seconds: 5);

  /// Detect snappy_web_agent daemon and return connection info
  static Future<DaemonInfo?> detectDaemon() async {
    for (int port = _startPort; port <= _endPort; port++) {
      final daemonInfo = await _testPort(port);
      if (daemonInfo != null) {
        return daemonInfo;
      }
    }

    return null;
  }

  /// Test if daemon is running on specific port
  static Future<DaemonInfo?> _testPort(int port) async {
    io.Socket? socket;
    try {
      final url = 'http://localhost:$port';
      final completer = Completer<DaemonInfo?>();

      // Create socket connection with timeout
      socket = io.io(
          url,
          io.OptionBuilder()
              .setTransports(['websocket', 'polling'])
              .enableForceNew()
              .setTimeout(_connectionTimeout.inMilliseconds)
              .disableAutoConnect()
              .build());

      // Set up handlers
      socket.onConnect((_) {
        // Test if this is actually snappy_web_agent by getting version
        socket!.emitWithAck('version', null, ack: (response) {
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

              if (pluginResponse.success &&
                  pluginResponse.command == 'version') {
                final daemonInfo = DaemonInfo(
                  port: port,
                  version: pluginResponse.message,
                  url: url,
                );
                if (!completer.isCompleted) {
                  completer.complete(daemonInfo);
                }
              } else {
                if (!completer.isCompleted) {
                  completer.complete(null);
                }
              }
            } else {
              if (!completer.isCompleted) {
                completer.complete(null);
              }
            }
          } catch (e) {
            if (!completer.isCompleted) {
              completer.complete(null);
            }
          }
        });
      });

      socket.onConnectError((error) {
        if (!completer.isCompleted) {
          completer.complete(null);
        }
      });

      socket.onError((error) {
        if (!completer.isCompleted) {
          completer.complete(null);
        }
      });

      // Set a timeout for the entire operation
      Timer(_connectionTimeout, () {
        if (!completer.isCompleted) {
          completer.complete(null);
        }
      });

      // Start the connection
      socket.connect();

      // Wait for result
      final result = await completer.future;

      return result;
    } catch (e) {
      return null;
    } finally {
      // Clean up socket
      try {
        socket?.disconnect();
        socket?.dispose();
      } catch (e) {
        // Ignore cleanup errors
      }
    }
  }

  /// Quick port availability check (TCP connection test)
  static Future<bool> isPortOpen(String host, int port) async {
    try {
      final socket =
          await Socket.connect(host, port, timeout: const Duration(seconds: 2));
      socket.destroy();
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Get all potentially available ports
  static Future<List<int>> getAvailablePorts() async {
    final availablePorts = <int>[];

    for (int port = _startPort; port <= _endPort; port++) {
      if (await isPortOpen('localhost', port)) {
        availablePorts.add(port);
      }
    }

    return availablePorts;
  }
}

/// Information about detected daemon
class DaemonInfo {
  final int port;
  final String version;
  final String url;

  const DaemonInfo({
    required this.port,
    required this.version,
    required this.url,
  });

  @override
  String toString() => 'DaemonInfo(port: $port, version: $version, url: $url)';
}
