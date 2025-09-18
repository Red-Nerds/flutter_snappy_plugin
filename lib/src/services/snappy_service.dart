import 'dart:async';
import 'dart:io';
import '../models/models.dart';

// Import desktop service implementation
import 'desktop_service.dart';

/// Abstract interface for SNAPPY device communication
/// This interface will be implemented by both Desktop (Socket.IO) and Android (AAR) services
abstract class SnappyService {
  /// Stream of connection status to the SNAPPY service (daemon/AAR)
  Stream<bool> get isConnected;

  /// Stream of device connection status (physical device connected)
  Stream<bool> get deviceConnected;

  /// Stream of real-time data from SNAPPY devices
  Stream<SnapData> get dataStream;

  /// Initialize and connect to the SNAPPY service
  /// For Desktop: Connect to snappy_web_agent daemon
  /// For Android: Initialize remotesdk.aar
  Future<PluginResponse> connect();

  /// Start data collection from devices
  Future<PluginResponse> startDataCollection();

  /// Stop data collection from devices
  Future<PluginResponse> stopDataCollection();

  /// Get service version
  /// For Desktop: snappy_web_agent version
  /// For Android: remotesdk.aar version
  Future<PluginResponse> getVersion();

  /// Disconnect from the service and cleanup resources
  Future<void> disconnect();

  /// Check if service is available
  /// For Desktop: Check if daemon is running
  /// For Android: Check if BLE is available
  Future<bool> isServiceAvailable();

  /// Get current connection status synchronously
  bool get isCurrentlyConnected;

  /// Get current device connection status synchronously
  bool get isDeviceCurrentlyConnected;

  // Future Android-specific methods (will be no-op for Desktop)

  /// Scan for available devices (Android BLE scanning)
  Stream<DeviceInfo> scanForDevices() {
    throw UnimplementedError('scanForDevices is only available on Android platform');
  }

  /// Pair with a BLE device (Android only)
  Future<PairingResult> pairRemote(String setName, String mac, int manufacturerId) {
    throw UnimplementedError('pairRemote is only available on Android platform');
  }

  /// Unpair a BLE device (Android only)
  Future<bool> unpairRemote(String setName, int remoteId, {bool shiftSequence = false}) {
    throw UnimplementedError('unpairRemote is only available on Android platform');
  }

  /// Scan for button presses from paired remotes (Android only)
  Stream<AnswerData> scanAnswers(String setName, {int? remoteId}) {
    throw UnimplementedError('scanAnswers is only available on Android platform');
  }

  /// Upload encrypted device set (Android only)
  Future<UploadStatus> uploadSet(File file, {String? setName}) {
    throw UnimplementedError('uploadSet is only available on Android platform');
  }

  /// Save device list (Android only)
  Future<bool> saveDeviceList(String listName, List<DeviceInfo> devices) {
    throw UnimplementedError('saveDeviceList is only available on Android platform');
  }

  /// Load saved device list (Android only)
  Future<List<DeviceInfo>?> loadDeviceList(String listName) {
    throw UnimplementedError('loadDeviceList is only available on Android platform');
  }

  /// Get saved device list names (Android only)
  Future<List<String>> getSavedDeviceListNames() {
    throw UnimplementedError('getSavedDeviceListNames is only available on Android platform');
  }

  /// Dispose all resources
  Future<void> dispose();
}

/// Factory for creating platform-specific SnappyService implementations
class SnappyServiceFactory {
  /// Create appropriate service based on current platform
  static SnappyService create() {
    final platform = _detectPlatform();

    switch (platform) {
      case SnappyPlatform.windows:
      case SnappyPlatform.linux:
      // Import is handled dynamically to avoid issues on other platforms
        return _createDesktopService();
      case SnappyPlatform.android:
      // Will be implemented later
        throw UnimplementedError('Android support coming soon. Use the Android AAR wrapper when available.');
      case SnappyPlatform.unsupported:
        throw SnappyPluginException(
            'Unsupported platform. SNAPPY plugin supports Windows, Linux, and Android only.',
            code: 'UNSUPPORTED_PLATFORM'
        );
    }
  }

  /// Create desktop service (Windows/Linux)
  static SnappyService _createDesktopService() {
    return DesktopSnappyService();
  }

  /// Detect current platform
  static SnappyPlatform _detectPlatform() {
    if (Platform.isWindows) return SnappyPlatform.windows;
    if (Platform.isLinux) return SnappyPlatform.linux;
    if (Platform.isAndroid) return SnappyPlatform.android;
    return SnappyPlatform.unsupported;
  }

  /// Get current platform
  static SnappyPlatform getCurrentPlatform() => _detectPlatform();

  /// Check if current platform is supported
  static bool isPlatformSupported() => getCurrentPlatform() != SnappyPlatform.unsupported;

  /// Check if running on Android
  static bool isAndroid() => getCurrentPlatform() == SnappyPlatform.android;

  /// Check if running on Desktop (Windows/Linux)
  static bool isDesktop() {
    final platform = getCurrentPlatform();
    return platform == SnappyPlatform.windows || platform == SnappyPlatform.linux;
  }

  /// Get platform display name
  static String getPlatformName() {
    switch (getCurrentPlatform()) {
      case SnappyPlatform.windows:
        return 'Windows';
      case SnappyPlatform.linux:
        return 'Linux';
      case SnappyPlatform.android:
        return 'Android';
      case SnappyPlatform.unsupported:
        return 'Unsupported';
    }
  }
}

// Forward declaration - implemented in desktop_service.dart
class DesktopSnappyService extends SnappyService {
  @override
  Stream<bool> get isConnected => throw UnimplementedError('Will be implemented in desktop_service.dart');

  @override
  Stream<bool> get deviceConnected => throw UnimplementedError('Will be implemented in desktop_service.dart');

  @override
  Stream<SnapData> get dataStream => throw UnimplementedError('Will be implemented in desktop_service.dart');

  @override
  bool get isCurrentlyConnected => throw UnimplementedError('Will be implemented in desktop_service.dart');

  @override
  bool get isDeviceCurrentlyConnected => throw UnimplementedError('Will be implemented in desktop_service.dart');

  @override
  Future<PluginResponse> connect() => throw UnimplementedError('Will be implemented in desktop_service.dart');

  @override
  Future<PluginResponse> startDataCollection() => throw UnimplementedError('Will be implemented in desktop_service.dart');

  @override
  Future<PluginResponse> stopDataCollection() => throw UnimplementedError('Will be implemented in desktop_service.dart');

  @override
  Future<PluginResponse> getVersion() => throw UnimplementedError('Will be implemented in desktop_service.dart');

  @override
  Future<void> disconnect() => throw UnimplementedError('Will be implemented in desktop_service.dart');

  @override
  Future<bool> isServiceAvailable() => throw UnimplementedError('Will be implemented in desktop_service.dart');

  @override
  Future<void> dispose() => throw UnimplementedError('Will be implemented in desktop_service.dart');
}