import 'package:json_annotation/json_annotation.dart';
import 'package:meta/meta.dart';

class UserCodeState {
  bool isLoading = false;
  List<UserCodeData> data = [];
}

@Immutable()
@JsonSerializable()
class UserCodeData {
  final String accountId;
  final String code;
  final int expireTime;

  const UserCodeData({
    required this.accountId,
    required this.code,
    required this.expireTime,
  });

}

@JsonSerializable()
class UserCodeResponse {
  final bool success;
  final String msg;
  final List<UserCodeData> data;

  UserCodeResponse({required this.success, required this.msg, required this.data});

  factory UserCodeResponse.fromJson(Map<String, dynamic> json) {
    if (json['success'] == false) {
      return UserCodeResponse(
        success: json['success'],
        msg: json['msg'],
        data: [],
      );
    }
    return UserCodeResponse(
      success: json['success'],
      msg: json['msg'],
      data: (json['data'] as List)
          .map((e) => UserCodeData(
                accountId: e['accountId'],
                code: e['code'],
                expireTime: e['expireTime'],
              ))
          .toList(),
    );
  }
}