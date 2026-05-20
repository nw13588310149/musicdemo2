class ApiResponse {
  const ApiResponse({required this.code, required this.msg, this.data});

  final int code;
  final String msg;
  final dynamic data;

  bool get isSuccess => code == 0 || code == 200;

  factory ApiResponse.fromJson(Map<String, dynamic> json) {
    final codeValue = json['code'];
    final parsedCode = codeValue is int
        ? codeValue
        : int.tryParse(codeValue?.toString() ?? '') ?? -1;

    return ApiResponse(
      code: parsedCode,
      msg: json['msg']?.toString() ?? '',
      data: json['data'],
    );
  }

  factory ApiResponse.failure(String message, {int code = -1}) {
    return ApiResponse(code: code, msg: message, data: null);
  }
}
