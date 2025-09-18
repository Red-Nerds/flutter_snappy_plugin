import 'dart:async';
import 'dart:io';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import '../models/models.dart';

/// Daemon detection and connection management for snappy_web_agent
class DaemonDetector {
  static const int _startPort = 8436;
  static const int _endPort = 8535;
  static const Duration _connectionTimeout = Duration(seconds: 3);

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
    IO.Socket? socket;
    try {
      final completer = Completer<DaemonInfo?>();

      // Create socket connection with timeout
      socket = IO.io('http://localhost:$port',
          IO.OptionBuilder()
              .setTransports(['websocket'])
              .disableAutoConnect()
              .setTimeout(_connectionTimeout.inMilliseconds)
              .build()
      );

      // Set up connection handlers
      socket.onConnect((_) {
        // Test if this is actually snappy_web_agent by getting version
        socket!.emitWithAck('version', [], ack: (data) {
          try {
            if (data is List && data.isNotEmpty) {
              final response = data.first as Map<String, dynamic>;
              final pluginResponse = PluginResponse.fromJson(response);

              if (pluginResponse.success && pluginResponse.command == 'version') {
                completer.complete(DaemonInfo(
                    port: port,
                    version: pluginResponse.message,
                    url: 'http://localhost:$port'
                ));
              } else {
                completer.complete(null);
              }
            } else {
              completer.complete(null);
            }
          } catch (e) {
            completer.complete(null);
          }
        });
      });

      socket.onConnectError((error) {
        if (!completer.isCompleted) completer.complete(null);
      });

      socket.onError((error) {
        if (!completer.isCompleted) completer.complete(null);
      });

      socket.onDisconnect((_) {
        if (!completer.isCompleted) completer.complete(null);
      });

      // Wait for result or timeout
      final result = await completer.future.timeout(
        _connectionTimeout,
        onTimeout: () => null,
      );

      socket.dispose();
      return result;

    } catch (e) {
      socket?.dispose();
      return null;
    }
  }

  /// Continuously monitor daemon availability
  static Stream<DaemonInfo?> monitorDaemon({
    Duration interval = const Duration(seconds: 10),
  }) async* {
    while (true) {
      final daemon = await detectDaemon();
      yield daemon;
      await Future.delayed(interval);
    }
  }

  /// Check if a specific port is available for daemon
  static Future<bool> isPortAvailable(int port) async {
    try {
      final serverSocket = await ServerSocket.bind('localhost', port);
      await serverSocket.close();
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Get next available port in daemon range
  static Future<int?> getAvailablePort() async {
    for (int port = _startPort; port <= _endPort; port++) {
      if (await isPortAvailable(port)) {
        return port;
      }
    }
    return null;
  }

  /// Test daemon connectivity with detailed results
  static Future<Map<String, dynamic>> testDaemonConnectivity() async {
    final results = <String, dynamic>{
      'ports_tested': <Map<String, dynamic>>[],
      'daemon_found': false,
      'total_duration_ms': 0,
    };

    final startTime = DateTime.now();

    for (int port = _startPort; port <= _endPort; port++) {
      final portStartTime = DateTime.now();
      final daemonInfo = await _testPort(port);
      final portDuration = DateTime.now().difference(portStartTime);

      final portResult = {
        'port': port,
        'duration_ms': portDuration.inMilliseconds,
        'success': daemonInfo != null,
      };

      if (daemonInfo != null) {
        portResult['daemon'] = {
          'version': daemonInfo.version,
          'url': daemonInfo.url,
        };
        results['daemon_found'] = true;
        results['daemon_info'] = daemonInfo.toJson();
      }

      results['ports_tested'].add(portResult);

      // Stop on first success
      if (daemonInfo != null) {
        break;
      }
    }

    results['total_duration_ms'] = DateTime.now().difference(startTime).inMilliseconds;
    return results;
  }

  /// Test specific daemon URL
  static Future<DaemonInfo?> testDaemonUrl(String url) async {
    IO.Socket? socket;
    try {
      final completer = Completer<DaemonInfo?>();

      socket = IO.io(url,
          IO.OptionBuilder()
              .setTransports(['websocket'])
              .disableAutoConnect()
              .setTimeout(_connectionTimeout.inMilliseconds)
              .build()
      );

      socket.onConnect((_) {
        socket!.emitWithAck('version', [], ack: (data) {
          try {
            if (data is List && data.isNotEmpty) {
              final response = data.first as Map<String, dynamic>;
              final pluginResponse = PluginResponse.fromJson(response);

              if (pluginResponse.success) {
                // Extract port from URL
                final uri = Uri.parse(url);
                completer.complete(DaemonInfo(
                    port: uri.port,
                    version: pluginResponse.message,
                    url: url
                ));
              } else {
                completer.complete(null);
              }
            } else {
              completer.complete(null);
            }
          } catch (e) {
            completer.complete(null);
          }
        });
      });

      socket.onConnectError((error) {
        if (!completer.isCompleted) completer.complete(null);
      });

      socket.onError((error) {
        if (!completer.isCompleted) completer.complete(null);
      });

      final result = await completer.future.timeout(
        _connectionTimeout,
        onTimeout: () => null,
      );

      socket.dispose();
      return result;

    } catch (e) {
      socket?.dispose();
      return null;
    }
  }

  /// Get all available daemon instances (if multiple are running)
  static Future<List<DaemonInfo>> getAllDaemons() async {
    final daemons = <DaemonInfo>[];

    for (int port = _startPort; port <= _endPort; port++) {
      final daemon = await _testPort(port);
      if (daemon != null) {
        daemons.add(daemon);
      }
    }

    return daemons;
  }

  /// Check daemon health by testing multiple commands
  static Future<Map<String, dynamic>> checkDaemonHealth(DaemonInfo daemon) async {
    IO.Socket? socket;
    final healthResults = <String, dynamic>{
      'daemon': daemon.toJson(),
      'connection_test': false,
      'version_command': false,
      'device_info_command': false,
      'response_times': <String, int>{},
      'errors': <String>[],
    };

    try {
      socket = IO.io(daemon.url,
          IO.OptionBuilder()
              .setTransports(['websocket'])
              .disableAutoConnect()
              .setTimeout(_connectionTimeout.inMilliseconds)
              .build()
      );

      final connectionCompleter = Completer<bool>();

      socket.onConnect((_) {
        healthResults['connection_test'] = true;
        connectionCompleter.complete(true);
      });

      socket.onConnectError((error) {
        healthResults['errors'].add('Connection error: $error');
        if (!connectionCompleter.isCompleted) connectionCompleter.complete(false);
      });

      // Test connection
      final connected = await connectionCompleter.future.timeout(
        _connectionTimeout,
        onTimeout: () {
          healthResults['errors'].add('Connection timeout');
          return false;
        },
      );

      if (connected) {
        // Test version command
        try {
          final versionStart = DateTime.now();
          final versionCompleter = Completer<bool>();

          socket.emitWithAck('version', [], ack: (data) {
            final duration = DateTime.now().difference(versionStart).inMilliseconds;
            healthResults['response_times']['version'] = duration;

            try {
              if (data is List && data.isNotEmpty) {
                final response = data.first as Map<String, dynamic>;
                final pluginResponse = PluginResponse.fromJson(response);
                healthResults['version_command'] = pluginResponse.success;
              }
            } catch (e) {
              healthResults['errors'].add('Version parse error: $e');
            }
            versionCompleter.complete(true);
          });

          await versionCompleter.future.timeout(_connectionTimeout);
        } catch (e) {
          healthResults['errors'].add('Version command error: $e');
        }

        // Test device-info command
        try {
          final deviceInfoStart = DateTime.now();
          final deviceInfoCompleter = Completer<bool>();

          socket.emitWithAck('device-info', [], ack: (data) {
            final duration = DateTime.now().difference(deviceInfoStart).inMilliseconds;
            healthResults['response_times']['device-info'] = duration;

            try {
              if (data is List && data.isNotEmpty) {
                final response = data.first as Map<String, dynamic>;
                final pluginResponse = PluginResponse.fromJson(response);
                healthResults['device_info_command'] = pluginResponse.success;
              }
            } catch (e) {
              healthResults['errors'].add('Device info parse error: $e');
            }
            deviceInfoCompleter.complete(true);
          });

          await deviceInfoCompleter.future.timeout(_connectionTimeout);
        } catch (e) {
          healthResults['errors'].add('Device info command error: $e');
        }
      }

      socket.dispose();

    } catch (e) {
      healthResults['errors'].add('General error: $e');
      socket?.dispose();
    }

    // Calculate overall health score
    int healthScore = 0;
    if (healthResults['connection_test']) healthScore += 40;
    if (healthResults['version_command']) healthScore += 30;
    if (healthResults['device_info_command']) healthScore += 30;

    healthResults['health_score'] = healthScore;
    healthResults['is_healthy'] = healthScore >= 70;

    return healthResults;
  }

  /// Validate daemon response format
  static bool isValidDaemonResponse(dynamic data) {
    try {
      if (data is! List || data.isEmpty) return false;

      final response = data.first;
      if (response is! Map<String, dynamic>) return false;

      return response.containsKey('success') &&
          response.containsKey('message') &&
          response.containsKey('command');
    } catch (e) {
      return false;
    }
  }

  /// Get port range for daemon detection
  static Map<String, int> getPortRange() => {
    'start': _startPort,
    'end': _endPort,
    'range': _endPort - _startPort + 1,
  };

  /// Get connection timeout settings
  static Duration get connectionTimeout => _connectionTimeout;
}

/// Information about detected snappy_web_agent daemon
class DaemonInfo {
  final int port;
  final String version;
  final String url;
  final DateTime detectedAt;

  DaemonInfo({
    required this.port,
    required this.version,
    required this.url,
  }) : detectedAt = DateTime.now();

  /// Convert to JSON
  Map<String, dynamic> toJson() => {
    'port': port,
    'version': version,
    'url': url,
    'detectedAt': detectedAt.toIso8601String(),
  };

  /// Create from JSON
  factory DaemonInfo.fromJson(Map<String, dynamic> json) => DaemonInfo(
    port: json['port'] as int,
    version: json['version'] as String,
    url: json['url'] as String,
  );

  /// Get daemon display name
  String get displayName => 'SNAPPY Web Agent v$version (Port $port)';

  /// Check if daemon info is recent (within last 30 seconds)
  bool get isRecent => DateTime.now().difference(detectedAt).inSeconds < 30;

  /// Get age of detection in human readable format
  String get ageDescription {
    final age = DateTime.now().difference(detectedAt);
    if (age.inMinutes < 1) return '${age.inSeconds}s ago';
    if (age.inHours < 1) return '${age.inMinutes}m ago';
    if (age.inDays < 1) return '${age.inHours}h ago';
    return '${age.inDays}d ago';
  }

  @override
  String toString() => 'DaemonInfo(port: $port, version: $version, url: $url, detectedAt: $detectedAt)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          other is DaemonInfo &&
              runtimeType == other.runtimeType &&
              port == other.port &&
              version == other.version &&
              url == other.url;

  @override
  int get hashCode => port.hashCode ^ version.hashCode ^ url.hashCode;
}