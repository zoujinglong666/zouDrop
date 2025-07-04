import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:http_cache_hive_store/http_cache_hive_store.dart';
import 'dart:io';

import 'interceptors/log_interceptor.dart';
import 'interceptors/loading_interceptor.dart';
import 'interceptors/token_interceptor.dart';
import 'interceptors/adapter_interceptor.dart';
import 'package:dio_cache_interceptor/dio_cache_interceptor.dart';
import 'package:path_provider/path_provider.dart';
class DioClient {
  static final DioClient _instance = DioClient._internal();

  factory DioClient() => _instance;

  late final Dio dio;

  DioClient._internal() {
    BaseOptions options = BaseOptions(
      baseUrl: 'http://10.9.17.94:3000/api/v1',
      connectTimeout: const Duration(seconds: 60),
      receiveTimeout: const Duration(seconds: 60),
      headers: {'Accept': 'application/json'},
    );

    dio = Dio(options);

    // 配置缓存拦截器
    _setupCacheInterceptor();

    dio.interceptors.addAll([
      LogInterceptorHandler(),
      LoadingInterceptorHandler(),
      TokenInterceptorHandler(),
      AdapterInterceptorHandler(),
    ]);

    dio.httpClientAdapter = DefaultHttpClientAdapter()
      ..onHttpClientCreate = (client) {
        client.findProxy = (uri) => "DIRECT";
        client.badCertificateCallback =
            (X509Certificate cert, String host, int port) => true;
        return client;
      };
  }

  void _setupCacheInterceptor() async {
    final dir = await getTemporaryDirectory();
    final cacheOptions = CacheOptions(
      store: HiveCacheStore(dir.path),
      policy: CachePolicy.request, // 可设为 CachePolicy.forceCache 等
      priority: CachePriority.normal,
      maxStale: const Duration(days: 7),
    );

    dio.interceptors.add(DioCacheInterceptor(options: cacheOptions));
  }
}