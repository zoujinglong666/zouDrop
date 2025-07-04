// interceptors/log_interceptor.dart
import 'package:dio/dio.dart';

class LogInterceptorHandler extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    print("➡️ 请求: ${options.uri}");
    super.onRequest(options, handler);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    print("✅ 响应: ${response.data}");
    super.onResponse(response, handler);
  }

  @override
  void onError(DioError err, ErrorInterceptorHandler handler) {
    print("❌ 错误: ${err.message}");
    super.onError(err, handler);
  }
}
