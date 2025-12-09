import 'dart:io';
import 'package:dio/dio.dart';
import 'api_service.dart';

class FileTransferService {
  final ApiService _apiService;

  FileTransferService(this._apiService);

  static const String _uploadUrl =
      'http://54.241.200.172:8800/setup-ws/api/v1/app/update-app/2';

  bool validateFile(File file, {int maxSizeBytes = 500 * 1024 * 1024}) {
    if (!file.existsSync()) {
      throw FileTransferException('File does not exist');
    }

    final fileSize = file.lengthSync();
    if (fileSize > maxSizeBytes) {
      throw FileTransferException(
        'File too large. Maximum size is ${maxSizeBytes / (1024 * 1024)} MB',
      );
    }

    if (fileSize == 0) {
      throw FileTransferException('File is empty');
    }

    return true;
  }

  Future<UploadResponse> uploadFile({
    required File file,
    required Function(int sent, int total) onProgress,
    required CancelToken cancelToken,
  }) async {
    validateFile(file);

    final token = await _apiService.getAccessToken();
    if (token == null) throw FileTransferException('No access token');

    String fileName = file.path.split('/').last.split('\\').last;

    FormData formData = FormData.fromMap({
      'jsonPatch': '[{"op":"replace","path":"/updateBy","value":123}]',
      'file': await MultipartFile.fromFile(file.path, filename: fileName),
    });

    try {
      final response = await _apiService.retryRequest(
        () => _apiService.dio.patch(
          _uploadUrl,
          data: formData,
          cancelToken: cancelToken,
          options: Options(headers: {'Authorization': 'Bearer $token'}),
          onSendProgress: onProgress,
        ),
        maxRetries: 2,
      );

      String? fileUrl;
      if (response.data != null && response.data is Map) {
        fileUrl =
            response.data['fileUrl'] ??
            response.data['url'] ??
            response.data['data']?['fileUrl'];
      }

      return UploadResponse(
        success: true,
        fileUrl: fileUrl,
        message: 'Upload successful',
      );
    } on DioException catch (e) {
      if (CancelToken.isCancel(e)) {
        throw FileTransferException('Upload cancelled');
      }
      throw _handleDioError(e);
    } catch (e) {
      throw FileTransferException('Upload failed: $e');
    }
  }

  Future<void> downloadFile({
    required String url,
    required String savePath,
    required Function(int received, int total) onProgress,
    required CancelToken cancelToken,
  }) async {
    if (!_isValidUrl(url)) {
      throw FileTransferException('Invalid download URL');
    }

    String? token;
    try {
      token = await _apiService.getAccessToken();
    } catch (e) {
      print('Auth failed for download, trying without token: $e');
    }

    try {
      await _apiService.retryRequest(
        () => _apiService.dio.download(
          url,
          savePath,
          cancelToken: cancelToken,
          onReceiveProgress: onProgress,
          options: token != null
              ? Options(headers: {'Authorization': 'Bearer $token'})
              : null,
        ),
        maxRetries: 3,
      );
    } on DioException catch (e) {
      if (CancelToken.isCancel(e)) {
        throw FileTransferException('Download cancelled');
      }
      throw _handleDioError(e);
    } catch (e) {
      throw FileTransferException('Download failed: $e');
    }
  }

  bool _isValidUrl(String url) {
    try {
      final uri = Uri.parse(url);
      return uri.hasScheme && (uri.scheme == 'http' || uri.scheme == 'https');
    } catch (e) {
      return false;
    }
  }

  Exception _handleDioError(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return FileTransferException(
          'Connection timeout. Please check your internet connection.',
        );

      case DioExceptionType.badResponse:
        final statusCode = e.response?.statusCode;
        if (statusCode == 401) {
          return FileTransferException(
            'Authentication failed. Please try again.',
          );
        } else if (statusCode == 403) {
          return FileTransferException('Access denied.');
        } else if (statusCode == 404) {
          return FileTransferException('File not found.');
        } else if (statusCode != null && statusCode >= 500) {
          return FileTransferException('Server error. Please try again later.');
        }
        return FileTransferException(
          'Upload/Download failed: ${e.response?.statusMessage}',
        );

      case DioExceptionType.cancel:
        return FileTransferException('Transfer cancelled');

      case DioExceptionType.connectionError:
        return FileTransferException(
          'No internet connection. Please check your network.',
        );

      default:
        return FileTransferException('Network error: ${e.message}');
    }
  }
}

class UploadResponse {
  final bool success;
  final String? fileUrl;
  final String message;

  UploadResponse({required this.success, this.fileUrl, required this.message});
}

class FileTransferException implements Exception {
  final String message;

  FileTransferException(this.message);

  @override
  String toString() => message;
}
