/// API 统一响应模型
class ApiResponse<T> {
  final bool success;
  final T? data;
  final String message;
  final List<String>? errors;

  const ApiResponse({
    required this.success,
    this.data,
    required this.message,
    this.errors,
  });

  factory ApiResponse.fromJson(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic>)? fromJsonT,
  ) {
    return ApiResponse(
      success: json['success'] as bool,
      data: json['data'] != null && fromJsonT != null
          ? fromJsonT(json['data'] as Map<String, dynamic>)
          : json['data'] as T?,
      message: json['message'] as String,
      errors: (json['errors'] as List<dynamic>?)?.cast<String>(),
    );
  }
}