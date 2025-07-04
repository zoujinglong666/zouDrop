import 'package:dio/dio.dart';

class AdapterInterceptorHandler extends Interceptor {
  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    // 统一格式适配
    if (response.data is Map<String, dynamic> && response.data.containsKey('result')) {
      response.data = response.data['result'];
    }
    super.onResponse(response, handler);
  }
}
