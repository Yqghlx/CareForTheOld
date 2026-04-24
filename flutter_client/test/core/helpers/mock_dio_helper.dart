import 'package:dio/dio.dart';
import 'package:mocktail/mocktail.dart';

/// Mock Dio 实例，用于单元测试中模拟网络请求
class MockDio extends Mock implements Dio {}

/// 创建模拟的 Dio Response 对象
///
/// [data] 响应体数据
/// [statusCode] HTTP 状态码，默认 200
Response<T> mockResponse<T>(T data, {int statusCode = 200}) {
  return Response<T>(
    data: data,
    statusCode: statusCode,
    requestOptions: RequestOptions(path: ''),
  );
}

/// 注册 mocktail 所需的回退值（fallback values）
///
/// 必须在 setUpAll 中调用，用于支持 any() 匹配器。
void registerFallbackValues() {
  registerFallbackValue(RequestOptions(path: ''));
  registerFallbackValue(Options());
  registerFallbackValue(<String, dynamic>{});
  registerFallbackValue(<String, String>{});
  registerFallbackValue(<String, Object?>{});
  registerFallbackValue(cancelToken);
  registerFallbackValue(ResponseType.json);
  registerFallbackValue('');
}

/// 共享的 CancelToken 实例，用于注册回退值
final cancelToken = CancelToken();
