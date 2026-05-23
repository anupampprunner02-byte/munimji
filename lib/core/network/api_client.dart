import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

final apiClientProvider = Provider<ApiClient>((ref) => ApiClient());

class ApiClient {
  static const _baseUrl = String.fromEnvironment('API_URL', defaultValue: 'http://10.0.2.2:3000/api');

  static final ApiClient _instance = ApiClient._internal();
  factory ApiClient() => _instance;

  late final Dio dio;
  final _storage = const FlutterSecureStorage();
  String? _businessId;

  ApiClient._internal() {
    dio = Dio(BaseOptions(
      baseUrl: _baseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 30),
      headers: {'Content-Type': 'application/json'},
    ));

    dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await _storage.read(key: 'access_token');
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        if (_businessId != null) {
          options.headers['x-business-id'] = _businessId;
        }
        return handler.next(options);
      },
      onError: (error, handler) async {
        if (error.response?.statusCode == 401) {
          final refreshed = await _refreshToken();
          if (refreshed) {
            return handler.resolve(await _retry(error.requestOptions));
          }
        }
        return handler.next(error);
      },
    ));
  }

  void setBusinessId(String? id) => _businessId = id;

  Future<bool> _refreshToken() async {
    try {
      final refreshToken = await _storage.read(key: 'refresh_token');
      if (refreshToken == null) return false;

      final response = await Dio().post('$_baseUrl/auth/refresh', data: {'refreshToken': refreshToken});
      await _storage.write(key: 'access_token', value: response.data['data']['accessToken']);
      return true;
    } catch (_) {
      await _storage.deleteAll();
      return false;
    }
  }

  Future<Response<dynamic>> _retry(RequestOptions requestOptions) async {
    final token = await _storage.read(key: 'access_token');
    return dio.request(
      requestOptions.path,
      data: requestOptions.data,
      queryParameters: requestOptions.queryParameters,
      options: Options(
        method: requestOptions.method,
        headers: {...requestOptions.headers, 'Authorization': 'Bearer $token'},
      ),
    );
  }

  Future<Map<String, dynamic>> get(String path, {Map<String, dynamic>? queryParameters}) async {
    final res = await dio.get(path, queryParameters: queryParameters);
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> post(String path, {dynamic data}) async {
    final res = await dio.post(path, data: data);
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> put(String path, {dynamic data}) async {
    final res = await dio.put(path, data: data);
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> patch(String path, {dynamic data}) async {
    final res = await dio.patch(path, data: data);
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> delete(String path) async {
    final res = await dio.delete(path);
    return res.data as Map<String, dynamic>;
  }
}
