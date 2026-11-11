import 'package:dio/dio.dart';

import '../config.dart';
import 'storage.dart';

/// An error from the SkirlField API ({success:false, error:{code,message,details}}) or the network.
class ApiException implements Exception {
  ApiException(this.status, this.code, this.message, [this.details = const {}]);

  final int status;
  final String code;
  final String message;
  final Map<String, dynamic> details;

  bool get isNetwork => code == 'NETWORK';

  /// Field → message for VALIDATION_FAILED.
  Map<String, String> get fields {
    final f = details['fields'];
    if (f is Map) return f.map((k, v) => MapEntry(k.toString(), v.toString()));
    return const {};
  }

  /// Message plus the first field error, for a snackbar.
  String get friendly {
    if (code == 'VALIDATION_FAILED' && fields.isNotEmpty) return fields.values.first;
    return message;
  }

  @override
  String toString() => 'ApiException($status $code: $message)';
}

class ApiPage<T> {
  ApiPage(this.items, this.total);
  final List<T> items;
  final int total;
}

/// HTTP client with automatic access-token refresh (the API rotates refresh tokens).
class Api {
  Api._() {
    final opts = BaseOptions(
      baseUrl: Config.apiBase,
      connectTimeout: const Duration(seconds: 20),
      sendTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 40),
      contentType: Headers.jsonContentType,
      responseType: ResponseType.json,
      headers: {'Accept': 'application/json'},
    );
    _dio = Dio(opts);
    _plain = Dio(opts); // no interceptors: used for refresh and for the retry after refresh
    _dio.interceptors.add(QueuedInterceptorsWrapper(onRequest: _onRequest, onError: _onError));
  }

  static final Api instance = Api._();

  late final Dio _dio;
  late final Dio _plain;

  /// Set by AuthState: called when the session can no longer be recovered.
  void Function(String message)? onSessionEnded;

  static const _sessionCodes = {'TOKEN_REVOKED', 'DEVICE_REVOKED', 'TOKEN_INVALID', 'ACCOUNT_DISABLED', 'COMPANY_SUSPENDED'};

  void _onRequest(RequestOptions o, RequestInterceptorHandler h) {
    final t = TokenStore.access;
    if (t != null && o.extra['noAuth'] != true && !o.headers.containsKey('Authorization')) {
      o.headers['Authorization'] = 'Bearer $t';
    }
    h.next(o);
  }

  Future<void> _onError(DioException e, ErrorInterceptorHandler h) async {
    final status = e.response?.statusCode ?? 0;
    final code = _errorCode(e.response?.data);
    final o = e.requestOptions;

    if (status == 401 && code == 'TOKEN_EXPIRED' && o.extra['retried'] != true && TokenStore.refresh != null) {
      try {
        final sentWith = (o.headers['Authorization'] as String?)?.replaceFirst('Bearer ', '');
        // another request may have refreshed already while this one waited in the queue
        final token = (sentWith != null && sentWith != TokenStore.access && TokenStore.access != null) ? TokenStore.access! : await _refreshToken();
        o.extra['retried'] = true;
        o.headers['Authorization'] = 'Bearer $token';
        final r = await _plain.fetch<dynamic>(o);
        h.resolve(r);
        return;
      } on DioException catch (re) {
        final rcode = _errorCode(re.response?.data);
        if (re.response?.statusCode == 401 || rcode != null) {
          await TokenStore.clear();
          onSessionEnded?.call('Your session has expired. Sign in again.');
        }
        h.next(re);
        return;
      } catch (_) {
        h.next(e);
        return;
      }
    }
    if ((status == 401 && _sessionCodes.contains(code)) || (status == 403 && code == 'COMPANY_SUSPENDED')) {
      await TokenStore.clear();
      onSessionEnded?.call(_errorMessage(e.response?.data) ?? 'Sign in again.');
    }
    h.next(e);
  }

  Future<String> _refreshToken() async {
    final r = await _plain.post<dynamic>('/auth/refresh', data: {'refresh_token': TokenStore.refresh});
    final d = (r.data as Map)['data'] as Map;
    await TokenStore.save(d['access_token'] as String, d['refresh_token'] as String);
    return d['access_token'] as String;
  }

  static String? _errorCode(dynamic data) {
    if (data is Map && data['error'] is Map) return (data['error'] as Map)['code']?.toString();
    return null;
  }

  static String? _errorMessage(dynamic data) {
    if (data is Map && data['error'] is Map) return (data['error'] as Map)['message']?.toString();
    return null;
  }

  static ApiException _convert(DioException e) {
    final data = e.response?.data;
    if (data is Map && data['error'] is Map) {
      final err = data['error'] as Map;
      final details = err['details'] is Map ? Map<String, dynamic>.from(err['details'] as Map) : <String, dynamic>{};
      return ApiException(e.response!.statusCode ?? 0, err['code']?.toString() ?? 'ERROR', err['message']?.toString() ?? 'Something went wrong.', details);
    }
    if (e.response == null) {
      return ApiException(0, 'NETWORK', 'Cannot reach the server. Check your internet connection.');
    }
    return ApiException(e.response!.statusCode ?? 0, 'HTTP_${e.response!.statusCode}', 'The server answered with an unexpected error (${e.response!.statusCode}).');
  }

  Future<dynamic> _send(Future<Response<dynamic>> Function() call) async {
    try {
      final r = await call();
      final body = r.data;
      if (body is Map && body.containsKey('data')) return body['data'];
      return body;
    } on DioException catch (e) {
      throw _convert(e);
    }
  }

  Future<dynamic> get(String path, {Map<String, dynamic>? query}) =>
      _send(() => _dio.get<dynamic>(path, queryParameters: _clean(query)));

  Future<ApiPage<Map<String, dynamic>>> getPage(String path, {Map<String, dynamic>? query}) async {
    try {
      final r = await _dio.get<dynamic>(path, queryParameters: _clean(query));
      final body = r.data as Map;
      final items = (body['data'] as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
      final pg = (body['meta'] is Map) ? (body['meta'] as Map)['pagination'] : null;
      return ApiPage(items, pg is Map ? (pg['total'] as num).toInt() : items.length);
    } on DioException catch (e) {
      throw _convert(e);
    }
  }

  Future<dynamic> post(String path, [Object? body, Map<String, String>? headers, bool auth = true]) => _send(() => _dio.post<dynamic>(
        path,
        data: body ?? <String, dynamic>{},
        options: Options(headers: headers, extra: auth ? null : {'noAuth': true}),
      ));

  Future<dynamic> put(String path, Object body) => _send(() => _dio.put<dynamic>(path, data: body));

  static Map<String, dynamic>? _clean(Map<String, dynamic>? q) {
    if (q == null) return null;
    return Map.fromEntries(q.entries.where((e) => e.value != null && e.value != ''));
  }
}
