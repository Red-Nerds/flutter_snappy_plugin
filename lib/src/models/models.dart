import 'package:json_annotation/json_annotation.dart';

part 'models.g.dart';

/// Response format for plugin operations
@JsonSerializable()
class PluginResponse {
  final bool success;
  final String message;
  final String command;
  final String? error;

  const PluginResponse({
    required this.success,
    required this.message,
    required this.command,
    this.error,
  });

  factory PluginResponse.fromJson(Map<String, dynamic> json) =>
      _$PluginResponseFromJson(json);
  Map<String, dynamic> toJson() => _$PluginResponseToJson(this);

  @override
  String toString() =>
      'PluginResponse(success: $success, message: $message, command: $command, error: $error)';
}

/// Device information - Compatible with both Android AAR and Desktop Socket.IO
@JsonSerializable()
class DeviceInfo {
  final String name;
  final String mac;
  final int? manufacturerId;

  const DeviceInfo({
    required this.name,
    required this.mac,
    this.manufacturerId,
  });

  factory DeviceInfo.fromJson(Map<String, dynamic> json) =>
      _$DeviceInfoFromJson(json);
  Map<String, dynamic> toJson() => _$DeviceInfoToJson(this);

  @override
  String toString() =>
      'DeviceInfo(name: $name, mac: $mac, manufacturerId: $manufacturerId)';
}

/// Real-time data from SNAPPY devices via Socket.IO (Desktop) or BLE (Android)
@JsonSerializable()
class SnapData {
  final String mac;
  final int value;
  final String timestamp;
  final int? pid; // Product ID for desktop devices
  final int? remoteId; // Remote ID for Android devices

  const SnapData({
    required this.mac,
    required this.value,
    required this.timestamp,
    this.pid,
    this.remoteId,
  });

  factory SnapData.fromJson(Map<String, dynamic> json) =>
      _$SnapDataFromJson(json);
  Map<String, dynamic> toJson() => _$SnapDataToJson(this);

  @override
  String toString() =>
      'SnapData(mac: $mac, value: $value, timestamp: $timestamp, pid: $pid, remoteId: $remoteId)';
}

/// Connection status event
@JsonSerializable()
class DeviceConnectionEvent {
  final String event;
  final String status; // "true" or "false"

  const DeviceConnectionEvent({
    required this.event,
    required this.status,
  });

  bool get isConnected => status.toLowerCase() == 'true';

  factory DeviceConnectionEvent.fromJson(Map<String, dynamic> json) =>
      _$DeviceConnectionEventFromJson(json);
  Map<String, dynamic> toJson() => _$DeviceConnectionEventToJson(this);

  @override
  String toString() => 'DeviceConnectionEvent(event: $event, status: $status)';
}

// Future Android-specific models (compatible with existing AAR)

/// Pairing result for Android BLE devices
@JsonSerializable()
class PairingResult {
  final bool success;
  final int remoteId;
  final String mac;

  const PairingResult({
    required this.success,
    required this.remoteId,
    required this.mac,
  });

  factory PairingResult.fromJson(Map<String, dynamic> json) =>
      _$PairingResultFromJson(json);
  Map<String, dynamic> toJson() => _$PairingResultToJson(this);

  @override
  String toString() =>
      'PairingResult(success: $success, remoteId: $remoteId, mac: $mac)';
}

/// Button press data from Android BLE devices
@JsonSerializable()
class AnswerData {
  final int remoteId;
  final String buttonPressed;
  final String mac;

  const AnswerData({
    required this.remoteId,
    required this.buttonPressed,
    required this.mac,
  });

  factory AnswerData.fromJson(Map<String, dynamic> json) =>
      _$AnswerDataFromJson(json);
  Map<String, dynamic> toJson() => _$AnswerDataToJson(this);

  @override
  String toString() =>
      'AnswerData(remoteId: $remoteId, buttonPressed: $buttonPressed, mac: $mac)';
}

/// Upload status for Android set management
@JsonSerializable()
class UploadStatus {
  final bool success;
  final String message;

  const UploadStatus({
    required this.success,
    required this.message,
  });

  factory UploadStatus.fromJson(Map<String, dynamic> json) =>
      _$UploadStatusFromJson(json);
  Map<String, dynamic> toJson() => _$UploadStatusToJson(this);

  @override
  String toString() => 'UploadStatus(success: $success, message: $message)';
}

/// Platform type enum
enum SnappyPlatform {
  android,
  windows,
  linux,
  macos,
  web,
  unsupported,
}

/// Plugin exception for error handling
class SnappyPluginException implements Exception {
  final String message;
  final String? code;
  final dynamic originalError;

  const SnappyPluginException(
    this.message, {
    this.code,
    this.originalError,
  });

  @override
  String toString() =>
      'SnappyPluginException: $message${code != null ? ' (Code: $code)' : ''}';
}
