import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_snappy_plugin/flutter_snappy_plugin.dart';
import 'package:flutter_snappy_plugin/flutter_snappy_plugin_platform_interface.dart';
import 'package:flutter_snappy_plugin/flutter_snappy_plugin_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockFlutterSnappyPluginPlatform
    with MockPlatformInterfaceMixin
    implements FlutterSnappyPluginPlatform {

  @override
  Future<String?> getPlatformVersion() => Future.value('42');
}

void main() {
  final FlutterSnappyPluginPlatform initialPlatform = FlutterSnappyPluginPlatform.instance;

  test('$MethodChannelFlutterSnappyPlugin is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelFlutterSnappyPlugin>());
  });

  test('getPlatformVersion', () async {
    FlutterSnappyPlugin flutterSnappyPlugin = FlutterSnappyPlugin();
    MockFlutterSnappyPluginPlatform fakePlatform = MockFlutterSnappyPluginPlatform();
    FlutterSnappyPluginPlatform.instance = fakePlatform;

    expect(await flutterSnappyPlugin.getPlatformVersion(), '42');
  });
}
