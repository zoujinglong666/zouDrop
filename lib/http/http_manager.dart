// http_manager.dart
import 'package:dio/dio.dart';
import 'dio_client.dart';
import 'model/base_response.dart';

class HttpManager {
  static final Dio _dio = DioClient().dio;

  static Future<BaseResponse<T>> get<T>(
      String path, {
        Map<String, dynamic>? queryParameters,
        Options? options,
        Function(dynamic)? fromJson,
      }) async {
    final res = await _dio.get(path, queryParameters: queryParameters, options: options);
    return BaseResponse<T>.fromJson(res.data, fromJson);
  }

  static Future<BaseResponse<T>> post<T>(
      String path, {
        dynamic data,
        Options? options,
        Function(dynamic)? fromJson,
      }) async {
    final res = await _dio.post(path, data: data, options: options);
    return BaseResponse<T>.fromJson(res.data, fromJson);
  }

  static Future<BaseResponse<T>> postForm<T>(
      String path, {
        Map<String, dynamic>? data,
        Options? options,
        Function(dynamic)? fromJson,
      }) async {
    final res = await _dio.post(
      path,
      data: FormData.fromMap(data ?? {}),
      options: options ?? Options(contentType: Headers.formUrlEncodedContentType),
    );
    return BaseResponse<T>.fromJson(res.data, fromJson);
  }

  static Future<BaseResponse<T>> delete<T>(
      String path, {
        Map<String, dynamic>? data,
        Options? options,
        Function(dynamic)? fromJson,
      }) async {
    final res = await _dio.delete(
      path,
      data: data,
      options: options,
    );
    return BaseResponse<T>.fromJson(res.data, fromJson);
  }

  static Future<BaseResponse<T>> put<T>(
      String path, {
        dynamic data,
        Options? options,
        Function(dynamic)? fromJson,
      }) async {
    final res = await _dio.put(
      path,
      data: data,
      options: options,
    );
    return BaseResponse<T>.fromJson(res.data, fromJson);
  }

  static Future<BaseResponse<T>> patch<T>(
      String path, {
        dynamic data,
        Options? options,
        Function(dynamic)? fromJson,
      }) async {
    final res = await _dio.patch(
      path,
      data: data,
      options: options,
    );
    return BaseResponse<T>.fromJson(res.data, fromJson);
  }

  static Future<Response> customGet(
      String url, {
        Map<String, dynamic>? queryParameters,
        Map<String, String>? headers,
        Duration timeout = const Duration(seconds: 30),
      }) async {
    final dio = Dio(BaseOptions(
      connectTimeout: timeout,
      receiveTimeout: timeout,
      sendTimeout: timeout,
      headers: headers,
    ));
    return dio.get(url, queryParameters: queryParameters);
  }


}
