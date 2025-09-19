import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_snappy_plugin/flutter_snappy_plugin.dart';
import 'dart:async';

void main() {
  group('FlutterSnappyPlugin Integration Tests', () {
    late FlutterSnappyPlugin plugin;

    setUp(() {
      plugin = FlutterSnappyPlugin.instance;
    });

    tearDown(() async {
      // Clean up after each test
      try {
        await plugin.disconnect();
      } catch (e) {
        // Ignore cleanup errors
      }
    });

    test('should detect platform correctly', () {
      expect(plugin.isPlatformSupported, isTrue);
      expect(plugin.currentPlatform,
          isIn([SnappyPlatform.windows, SnappyPlatform.linux]));
      expect(plugin.isDesktop, isTrue);
      expect(plugin.isAndroid, isFalse);
    });

    test('should throw UnimplementedError for Android-only methods', () {
      expect(
        () => plugin.scanForDevices(),
        throwsA(isA<UnimplementedError>()),
      );

      expect(
        () => plugin.pairRemote('test', 'AA:BB:CC:DD:EE:FF', 123),
        throwsA(isA<UnimplementedError>()),
      );

      expect(
        () => plugin.unpairRemote('test', 1),
        throwsA(isA<UnimplementedError>()),
      );
    });

    group('With snappy_web_agent daemon running', () {
      test('should detect daemon availability', () async {
        final isAvailable = await plugin.isServiceAvailable();
        print('Daemon available: $isAvailable');
        // This test passes regardless of daemon state, just for info
        expect(isAvailable, isA<bool>());
      });

      test('should connect to daemon if available', () async {
        final isAvailable = await plugin.isServiceAvailable();

        if (!isAvailable) {
          print('Skipping connection test - daemon not available');
          return;
        }

        final response = await plugin.connect();
        print('Connection response: ${response.toString()}');

        expect(response.success, isTrue);
        expect(response.command, equals('connect'));

        // Test current connection status
        await Future.delayed(
            const Duration(seconds: 1)); // Allow connection to establish
        expect(plugin.isCurrentlyConnected, isTrue);
      });

      test('should get version information', () async {
        final isAvailable = await plugin.isServiceAvailable();
        if (!isAvailable) {
          print('Skipping version test - daemon not available');
          return;
        }

        await plugin.connect();

        final response = await plugin.getVersion();
        print('Version response: ${response.toString()}');

        expect(response.success, isTrue);
        expect(response.command, equals('version'));
        expect(response.message, isNotEmpty);
      });

      test('should start and stop data collection', () async {
        final isAvailable = await plugin.isServiceAvailable();
        if (!isAvailable) {
          print('Skipping data collection test - daemon not available');
          return;
        }

        await plugin.connect();

        // Start data collection
        final startResponse = await plugin.startDataCollection();
        print('Start collection response: ${startResponse.toString()}');

        expect(startResponse.success, isTrue);
        expect(startResponse.command, equals('start-snappy'));

        // Wait a moment
        await Future.delayed(const Duration(seconds: 2));

        // Stop data collection
        final stopResponse = await plugin.stopDataCollection();
        print('Stop collection response: ${stopResponse.toString()}');

        expect(stopResponse.success, isTrue);
        expect(stopResponse.command, equals('stop-snappy'));
      });

      test('should stream connection status', () async {
        final isAvailable = await plugin.isServiceAvailable();
        if (!isAvailable) {
          print('Skipping stream test - daemon not available');
          return;
        }

        final connectionStatusReceived = <bool>[];
        late StreamSubscription<bool> subscription;

        subscription = plugin.isConnected.listen((connected) {
          connectionStatusReceived.add(connected);
          print('Connection status: $connected');
        });

        // Connect
        await plugin.connect();
        await Future.delayed(const Duration(seconds: 1));

        // Disconnect
        await plugin.disconnect();
        await Future.delayed(const Duration(seconds: 1));

        await subscription.cancel();

        // Should have received at least one true and one false
        expect(connectionStatusReceived, contains(true));
        expect(connectionStatusReceived, contains(false));
      });

      test('should handle device connection stream', () async {
        final isAvailable = await plugin.isServiceAvailable();
        if (!isAvailable) {
          print('Skipping device stream test - daemon not available');
          return;
        }

        final deviceStatusReceived = <bool>[];
        late StreamSubscription<bool> subscription;

        subscription = plugin.deviceConnected.listen((connected) {
          deviceStatusReceived.add(connected);
          print('Device status: $connected');
        });

        await plugin.connect();
        await Future.delayed(
            const Duration(seconds: 3)); // Wait for device status

        await subscription.cancel();

        // Should have received at least one device status update
        expect(deviceStatusReceived, isNotEmpty);
        print('Device connection statuses received: $deviceStatusReceived');
      });

      test('should handle data stream when collecting', () async {
        final isAvailable = await plugin.isServiceAvailable();
        if (!isAvailable) {
          print('Skipping data stream test - daemon not available');
          return;
        }

        final dataReceived = <SnapData>[];
        late StreamSubscription<SnapData> subscription;

        subscription = plugin.dataStream.listen((data) {
          dataReceived.add(data);
          print('Data received: ${data.toString()}');
        });

        await plugin.connect();
        await plugin.startDataCollection();

        // Wait for potential data (device needs to be connected and active)
        await Future.delayed(const Duration(seconds: 5));

        await plugin.stopDataCollection();
        await subscription.cancel();

        print('Total data packets received: ${dataReceived.length}');

        // Test passes regardless of data received (depends on physical device)
        // but validates that stream doesn't error
        for (final data in dataReceived) {
          expect(data.mac, isNotEmpty);
          expect(data.value, isA<int>());
          expect(data.timestamp, isNotEmpty);
        }
      });

      test('should run connection diagnostics', () async {
        final testResults = await plugin.testConnection();
        print('Connection test results: $testResults');

        expect(testResults, isA<Map<String, dynamic>>());
        expect(testResults['daemonDetection'], isNotNull);

        final daemonDetection =
            testResults['daemonDetection'] as Map<String, dynamic>;
        expect(daemonDetection['success'], isA<bool>());
        expect(daemonDetection['duration'], isA<int>());

        if (daemonDetection['success'] == true) {
          expect(daemonDetection['daemon'], isNotNull);
          final daemon = daemonDetection['daemon'] as Map<String, dynamic>;
          expect(daemon['port'], isA<int>());
          expect(daemon['version'], isA<String>());
          expect(daemon['url'], isA<String>());
        }
      });
    });

    group('Error handling', () {
      test('should handle connection failure gracefully', () async {
        // This test assumes daemon is NOT running
        final response = await plugin.connect();

        if (!response.success) {
          expect(response.error, isNotNull);
          expect(response.message, contains('daemon'));
          print('Expected connection failure: ${response.toString()}');
        } else {
          print('Daemon was available when expecting failure');
        }
      });

      test('should handle operations without connection', () async {
        // Ensure we're disconnected
        await plugin.disconnect();

        final response = await plugin.startDataCollection();

        // Should fail because not connected
        expect(response.success, isFalse);
        print('Expected operation failure: ${response.toString()}');
      });
    });
  });
}
