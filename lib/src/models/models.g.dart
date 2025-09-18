// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PluginResponse _$PluginResponseFromJson(Map<String, dynamic> json) =>
    PluginResponse(
      success: json['success'] as bool,
      message: json['message'] as String,
      command: json['command'] as String,
      error: json['error'] as String?,
    );

Map<String, dynamic> _$PluginResponseToJson(PluginResponse instance) =>
    <String, dynamic>{
      'success': instance.success,
      'message': instance.message,
      'command': instance.command,
      'error': instance.error,
    };

DeviceInfo _$DeviceInfoFromJson(Map<String, dynamic> json) => DeviceInfo(
      name: json['name'] as String,
      mac: json['mac'] as String,
      manufacturerId: (json['manufacturerId'] as num?)?.toInt(),
    );

Map<String, dynamic> _$DeviceInfoToJson(DeviceInfo instance) =>
    <String, dynamic>{
      'name': instance.name,
      'mac': instance.mac,
      'manufacturerId': instance.manufacturerId,
    };

SnapData _$SnapDataFromJson(Map<String, dynamic> json) => SnapData(
      mac: json['mac'] as String,
      value: (json['value'] as num).toInt(),
      timestamp: json['timestamp'] as String,
      pid: (json['pid'] as num?)?.toInt(),
      remoteId: (json['remoteId'] as num?)?.toInt(),
    );

Map<String, dynamic> _$SnapDataToJson(SnapData instance) => <String, dynamic>{
      'mac': instance.mac,
      'value': instance.value,
      'timestamp': instance.timestamp,
      'pid': instance.pid,
      'remoteId': instance.remoteId,
    };

DeviceConnectionEvent _$DeviceConnectionEventFromJson(
        Map<String, dynamic> json) =>
    DeviceConnectionEvent(
      event: json['event'] as String,
      status: json['status'] as String,
    );

Map<String, dynamic> _$DeviceConnectionEventToJson(
        DeviceConnectionEvent instance) =>
    <String, dynamic>{
      'event': instance.event,
      'status': instance.status,
    };

PairingResult _$PairingResultFromJson(Map<String, dynamic> json) =>
    PairingResult(
      success: json['success'] as bool,
      remoteId: (json['remoteId'] as num).toInt(),
      mac: json['mac'] as String,
    );

Map<String, dynamic> _$PairingResultToJson(PairingResult instance) =>
    <String, dynamic>{
      'success': instance.success,
      'remoteId': instance.remoteId,
      'mac': instance.mac,
    };

AnswerData _$AnswerDataFromJson(Map<String, dynamic> json) => AnswerData(
      remoteId: (json['remoteId'] as num).toInt(),
      buttonPressed: json['buttonPressed'] as String,
      mac: json['mac'] as String,
    );

Map<String, dynamic> _$AnswerDataToJson(AnswerData instance) =>
    <String, dynamic>{
      'remoteId': instance.remoteId,
      'buttonPressed': instance.buttonPressed,
      'mac': instance.mac,
    };

UploadStatus _$UploadStatusFromJson(Map<String, dynamic> json) => UploadStatus(
      success: json['success'] as bool,
      message: json['message'] as String,
    );

Map<String, dynamic> _$UploadStatusToJson(UploadStatus instance) =>
    <String, dynamic>{
      'success': instance.success,
      'message': instance.message,
    };
