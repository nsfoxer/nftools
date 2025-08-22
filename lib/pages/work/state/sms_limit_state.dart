import 'package:json_annotation/json_annotation.dart';
import 'package:meta/meta.dart';

class SmsLimitState {
  bool isLoading = false;
  List<SmsLimitData> data = [];
}

@Immutable()
@JsonSerializable()
class SmsLimitData {
  final String phone;
  final int count ;

  SmsLimitData({required this.phone, required this.count});
}

@JsonSerializable()
class SmsLimitResponse {
  final bool success;
  final String msg;
  final List<SmsLimitData> data;

  SmsLimitResponse({required this.success, required this.msg, required this.data});

  factory SmsLimitResponse.fromJson(Map<String, dynamic> json) {
    if (json['success'] == false) {
      return SmsLimitResponse(
        success: json['success'],
        msg: json['msg'],
        data: [],
      );
    }

    return SmsLimitResponse(
      success: json['success'],
      msg: json['msg'],
      data: (json['data'] as List)
          .map((e) => SmsLimitData(
            phone: e['phone'],
            count: e['count'],
          ))
          .toList(),
    );
  }
}

@JsonSerializable()
class BoolResponse {
  final bool success;
  final String msg;
  final bool data;

  BoolResponse(this.success, this.msg, this.data);

  factory BoolResponse.fromJson(Map<String, dynamic> json) {
    return BoolResponse(
      json['success'],
      json['msg'],
      json['data'] ?? false,
    );
  }
}
