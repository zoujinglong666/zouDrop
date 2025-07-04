import 'package:dio/dio.dart';

class LoadingInterceptorHandler extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    // 可添加 Loading 显示逻辑
    print("🔄 显示 Loading");
    super.onRequest(options, handler);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    // 关闭 Loading
    print("✅ 隐藏 Loading");
    super.onResponse(response, handler);
  }

  @override
  void onError(DioError err, ErrorInterceptorHandler handler) {
    print("❌ 隐藏 Loading");
    super.onError(err, handler);
  }
}