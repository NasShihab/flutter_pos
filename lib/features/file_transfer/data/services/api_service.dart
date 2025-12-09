import 'package:dio/dio.dart';

class ApiService {
  final Dio _dio = Dio();
  String? _accessToken;
  DateTime? _tokenExpiry;

  static const String _authUrl =
      'http://54.241.200.172:8801/auth-ws/oauth2/token';
  static const String _basicAuth = 'Basic Y2xpZW50OnNlY3JldA==';

  ApiService() {
    _dio.options.connectTimeout = const Duration(seconds: 30);
    _dio.options.receiveTimeout = const Duration(seconds: 30);
    _dio.options.sendTimeout = const Duration(seconds: 30);
  }

  Future<String?> getAccessToken({bool forceRefresh = false}) async {
    if (!forceRefresh && _accessToken != null && _tokenExpiry != null) {
      if (DateTime.now().isBefore(_tokenExpiry!)) {
        return _accessToken;
      }
    }

    try {
      final response = await _dio.post(
        _authUrl,
        options: Options(
          headers: {
            'Authorization': _basicAuth,
            'Content-Type': 'application/x-www-form-urlencoded',
          },
        ),
        data: {
          'grant_type': 'password',
          'scope': 'profile',
          'username': 'abir',
          'password': 'ati123',
        },
      );

      if (response.statusCode == 200) {
        _accessToken = response.data['access_token'];

        final expiresIn = response.data['expires_in'] ?? 3600;
        _tokenExpiry = DateTime.now().add(Duration(seconds: expiresIn - 60));

        return _accessToken;
      } else {
        throw ApiException(
          'Failed to authenticate: ${response.statusCode}',
          response.statusCode,
        );
      }
    } on DioException catch (e) {
      throw _handleDioError(e);
    } catch (e) {
      throw ApiException('Authentication error: $e', null);
    }
  }

  Future<T> retryRequest<T>(
    Future<T> Function() request, {
    int maxRetries = 3,
    Duration initialDelay = const Duration(seconds: 1),
  }) async {
    int retryCount = 0;
    Duration delay = initialDelay;

    while (true) {
      try {
        return await request();
      } on DioException catch (e) {
        retryCount++;

        if (e.response != null) {
          final statusCode = e.response!.statusCode;
          if (statusCode != null && statusCode >= 400 && statusCode < 500) {
            if (statusCode != 408 && statusCode != 429) {
              rethrow;
            }
          }
        }

        if (retryCount >= maxRetries) {
          rethrow;
        }

        await Future.delayed(delay);
        delay *= 2;
      }
    }
  }

  Exception _handleDioError(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return ApiException(
          'Connection timeout. Please check your internet connection.',
          null,
        );

      case DioExceptionType.badResponse:
        final statusCode = e.response?.statusCode;
        final message =
            e.response?.data?['message'] ??
            e.response?.statusMessage ??
            'Server error';
        return ApiException(message, statusCode);

      case DioExceptionType.cancel:
        return ApiException('Request was cancelled', null);

      case DioExceptionType.connectionError:
        return ApiException(
          'No internet connection. Please check your network.',
          null,
        );

      default:
        return ApiException('Network error: ${e.message}', null);
    }
  }

  Dio get dio => _dio;
}

class ApiException implements Exception {
  final String message;
  final int? statusCode;

  ApiException(this.message, this.statusCode);

  @override
  String toString() => message;
}
