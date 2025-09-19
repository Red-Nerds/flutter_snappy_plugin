/// Flutter Plugin for SNAPPY remote device communication
///
/// Supports:
/// - Windows/Linux: Via Socket.IO communication with snappy_web_agent daemon
/// - Android: Via BLE communication with remotesdk.aar (coming soon)
///
/// Usage:
/// ```dart
/// final plugin = FlutterSnappyPlugin.instance;
/// await plugin.connect();
/// await plugin.startDataCollection();
///
/// plugin.dataStream.listen((data) {
///   print('Received: ${data.value} from ${data.mac}');
/// });
/// ```
library flutter_snappy_plugin;

import 'dart:async';
import 'dart:io';

// Export all models and enums for easy access
export 'src/models/models.dart';

// Export service interfaces for advanced usage
export 'src/services/snappy_service.dart';

// Internal imports
import 'src/services/snappy_service.dart';
import 'src/services/desktop_service.dart';
import 'src/models/models.dart';

/// Main Flutter SNAPPY Plugin class
///
/// Provides a unified interface for SNAPPY device communication across platforms.
/// Uses appropriate service implementation based on the current platform.
class FlutterSnappyPlugin {
  static FlutterSnappyPlugin? _instance;

  /// Singleton instance of the plugin
  static FlutterSnappyPlugin get instance {
    return _instance ??= FlutterSnappyPlugin._();
  }

  // Private constructor
  FlutterSnappyPlugin._() {
    _initialize();
  }

  SnappyService? _service;
  bool _isInitialized = false;

  /// Initialize the plugin with appropriate service
  void _initialize() {
    if (_isInitialized) return;

    try {
      _service = SnappyServiceFactory.create();
      _isInitialized = true;
    } catch (e) {
      throw SnappyPluginException(
        'Failed to initialize SNAPPY plugin: ${e.toString()}',
        code: 'INITIALIZATION_FAILED',
        originalError: e,
      );
    }
  }

  /// Ensure plugin is initialized
  void _ensureInitialized() {
    if (!_isInitialized || _service == null) {
      throw const SnappyPluginException(
        'Plugin not initialized. This should not happen.',
        code: 'NOT_INITIALIZED',
      );
    }
  }

  // Core connection and data methods

  /// Stream of connection status to the SNAPPY service
  ///
  /// For Desktop: Connection to snappy_web_agent daemon
  /// For Android: Connection to remotesdk.aar
  Stream<bool> get isConnected {
    _ensureInitialized();
    return _service!.isConnected;
  }

  /// Stream of device connection status
  ///
  /// Indicates if a physical SNAPPY device is connected and detected
  Stream<bool> get deviceConnected {
    _ensureInitialized();
    return _service!.deviceConnected;
  }

  /// Stream of real-time data from SNAPPY devices
  ///
  /// Emits [SnapData] objects containing:
  /// - mac: Device MAC address
  /// - value: Measured value
  /// - timestamp: UTC timestamp
  /// - pid: Product ID (Desktop only)
  /// - remoteId: Remote ID (Android only)
  Stream<SnapData> get dataStream {
    _ensureInitialized();
    return _service!.dataStream;
  }

  /// Connect to the SNAPPY service
  ///
  /// For Desktop: Detects and connects to snappy_web_agent daemon
  /// For Android: Initializes remotesdk.aar
  ///
  /// Returns [PluginResponse] with connection result
  Future<PluginResponse> connect() async {
    _ensureInitialized();
    return await _service!.connect();
  }

  /// Start data collection from SNAPPY devices
  ///
  /// Must be connected first.
  /// Returns [PluginResponse] with operation result
  Future<PluginResponse> startDataCollection() async {
    _ensureInitialized();
    return await _service!.startDataCollection();
  }

  /// Stop data collection from SNAPPY devices
  ///
  /// Returns [PluginResponse] with operation result
  Future<PluginResponse> stopDataCollection() async {
    _ensureInitialized();
    return await _service!.stopDataCollection();
  }

  /// Get version of the underlying service
  ///
  /// For Desktop: snappy_web_agent version
  /// For Android: remotesdk.aar version
  ///
  /// Returns [PluginResponse] with version in message field
  Future<PluginResponse> getVersion() async {
    _ensureInitialized();
    return await _service!.getVersion();
  }

  /// Disconnect from the service and cleanup resources
  Future<void> disconnect() async {
    _ensureInitialized();
    await _service!.disconnect();
  }

  /// Check if service is available
  ///
  /// For Desktop: Check if snappy_web_agent daemon is running
  /// For Android: Check if BLE is available
  Future<bool> isServiceAvailable() async {
    _ensureInitialized();
    return await _service!.isServiceAvailable();
  }

  /// Get current connection status synchronously
  bool get isCurrentlyConnected {
    _ensureInitialized();
    return _service!.isCurrentlyConnected;
  }

  /// Get current device connection status synchronously
  bool get isDeviceCurrentlyConnected {
    _ensureInitialized();
    return _service!.isDeviceCurrentlyConnected;
  }

  // Platform detection and utility methods

  /// Get current platform
  SnappyPlatform get currentPlatform =>
      SnappyServiceFactory.getCurrentPlatform();

  /// Check if current platform is supported
  bool get isPlatformSupported => SnappyServiceFactory.isPlatformSupported();

  /// Check if running on Android
  bool get isAndroid => SnappyServiceFactory.isAndroid();

  /// Check if running on Desktop (Windows/Linux)
  bool get isDesktop => SnappyServiceFactory.isDesktop();

  // Android-specific methods (will throw UnimplementedError on other platforms)

  /// Scan for available BLE devices
  ///
  /// **Android only** - Scans for SNAPPY devices via Bluetooth LE
  /// Throws [UnimplementedError] on other platforms
  Stream<DeviceInfo> scanForDevices() {
    _ensureInitialized();
    return _service!.scanForDevices();
  }

  /// Pair with a BLE device
  ///
  /// **Android only** - Pairs with discovered SNAPPY device
  /// Throws [UnimplementedError] on other platforms
  Future<PairingResult> pairRemote(
      String setName, String mac, int manufacturerId) {
    _ensureInitialized();
    return _service!.pairRemote(setName, mac, manufacturerId);
  }

  /// Unpair a BLE device
  ///
  /// **Android only** - Unpairs previously paired device
  /// Throws [UnimplementedError] on other platforms
  Future<bool> unpairRemote(String setName, int remoteId,
      {bool shiftSequence = false}) {
    _ensureInitialized();
    return _service!
        .unpairRemote(setName, remoteId, shiftSequence: shiftSequence);
  }

  /// Scan for button presses from paired remotes
  ///
  /// **Android only** - Listens for button press data from paired devices
  /// Throws [UnimplementedError] on other platforms
  Stream<AnswerData> scanAnswers(String setName, {int? remoteId}) {
    _ensureInitialized();
    return _service!.scanAnswers(setName, remoteId: remoteId);
  }

  /// Upload encrypted device set
  ///
  /// **Android only** - Uploads and decrypts device set data
  /// Throws [UnimplementedError] on other platforms
  Future<UploadStatus> uploadSet(File file, {String? setName}) {
    _ensureInitialized();
    return _service!.uploadSet(file, setName: setName);
  }

  /// Save device list
  ///
  /// **Android only** - Saves discovered device list
  /// Throws [UnimplementedError] on other platforms
  Future<bool> saveDeviceList(String listName, List<DeviceInfo> devices) {
    _ensureInitialized();
    return _service!.saveDeviceList(listName, devices);
  }

  /// Load saved device list
  ///
  /// **Android only** - Loads previously saved device list
  /// Throws [UnimplementedError] on other platforms
  Future<List<DeviceInfo>?> loadDeviceList(String listName) {
    _ensureInitialized();
    return _service!.loadDeviceList(listName);
  }

  /// Get saved device list names
  ///
  /// **Android only** - Gets all saved device list names
  /// Throws [UnimplementedError] on other platforms
  Future<List<String>> getSavedDeviceListNames() {
    _ensureInitialized();
    return _service!.getSavedDeviceListNames();
  }

  // Advanced methods for testing and diagnostics

  /// Test connection without full connect (for diagnostics)
  ///
  /// **Desktop only** - Provides detailed connection testing results
  /// Returns diagnostic information about daemon detection and connectivity
  Future<Map<String, dynamic>> testConnection() async {
    _ensureInitialized();

    if (_service is DesktopSnappyService) {
      return await (_service as DesktopSnappyService).testConnection();
    } else {
      throw UnimplementedError(
          'testConnection is only available on Desktop platforms');
    }
  }

  // Utility methods

  /// Dispose all resources
  ///
  /// Call this when the plugin is no longer needed
  Future<void> dispose() async {
    if (_service != null) {
      await disconnect();
      await _service!.dispose();
    }
    _service = null;
    _isInitialized = false;
    _instance = null;
  }

  /// Reset plugin to initial state
  ///
  /// Useful for testing or re-initialization
  static Future<void> reset() async {
    if (_instance != null) {
      await _instance!.dispose();
    }
    _instance = null;
  }
}
