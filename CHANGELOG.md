## 1.0.3

* macOS Build Fix 🔧
* Fixed macOS platform registration errors (FlutterSnappyPlugin.registerWith not found)
* Improved Flutter platform file generation for macOS compatibility
* Enhanced macOS platform detection and validation
* Added comprehensive macOS support documentation
* Updated error messages to properly include macOS as supported platform
* Added platform-specific utility methods (isMacOS, isWindows, isLinux)
* Improved debugging and troubleshooting for macOS builds
* Fixed dart_plugin_registrant.dart generation issues on macOS

## 1.0.2

* macOS Platform Support Added 🍎
* Added macOS to supported platforms in pubspec.yaml
* Extended desktop service to include macOS alongside Windows and Linux
* Updated platform detection to recognize macOS as supported platform
* macOS now uses same Socket.IO communication as other desktop platforms
* Ready for snappy_web_agent daemon integration on macOS
* Cross-platform compatibility for Windows, Linux, and macOS desktop environments

## 1.0.1

* Added web platform support via Socket.IO communication
* Fixed Platform detection error on web browsers
* Fixed switch case handling for web platform
* Web browsers can now connect directly to snappy_web_agent daemon
* Same real-time data streaming available in web applications
* CORS support for cross-origin web app access
* Updated platform detection to include web support
* No breaking changes - patch release for additional platform

## 1.0.0

* **First stable release** 🎉
* Added macOS support via snappy-web-agent daemon
* Cross-platform support for Windows, Linux, and macOS
* Real-time data streaming from SNAPPY devices
* Socket.IO communication with snappy_web_agent daemon
* Automatic daemon detection on ports 8436-8535
* Device connection monitoring and status tracking
* Comprehensive error handling and recovery
* Complete documentation with platform setup guides
* Universal macOS support (ARM64 + Intel)

## 1.0.0-beta.1

* Initial release with Windows and Linux support
* Socket.IO communication with snappy_web_agent daemon
* Real-time data streaming from SNAPPY devices
* Device connection monitoring
* Automatic daemon detection

## Upcoming
* Android support via BLE communication