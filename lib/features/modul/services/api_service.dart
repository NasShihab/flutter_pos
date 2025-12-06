import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_downloader/flutter_downloader.dart';
import 'package:flutter_pos/features/modul/services/notification_service.dart';
import 'package:path_provider/path_provider.dart';

class ApiService {
  final Dio _dio = Dio();
  String? _token;
  final NotificationService _notificationService = NotificationService();

  Future<void> authenticate() async {
    try {
      final response = await _dio.post(
        'http://54.241.200.172:8801/auth-ws/oauth2/token',
        data: {
          'grant_type': 'password',
          'scope': 'profile',
          'username': 'abir',
          'password': 'ati123',
        },
        options: Options(
          headers: {
            'Authorization': 'Basic Y2xpZW50OnNlY3JldA==',
          },
        ),
      );
      _token = response.data['access_token'];
    } catch (e) {
      print('Authentication failed: $e');
    }
  }

  Future<List<dynamic>> getPermittedApps() async {
    if (_token == null) {
      await authenticate();
    }

    try {
      final response = await _dio.get(
        'http://54.241.200.172:8800/setup-ws/api/v1/app/get-permitted-apps?companyId=2',
        options: Options(
          headers: {
            'Authorization': 'Bearer $_token',
          },
        ),
      );
      return response.data;
    } catch (e) {
      print('Failed to get permitted apps: $e');
      return [];
    }
  }

  Future<void> uploadFile(String filePath, {Function(int, int)? onSendProgress}) async {
    if (_token == null) {
      await authenticate();
    }

    try {
      final fileName = filePath.split('/').last;
      final formData = FormData.fromMap({
        'jsonPatch': '[{"op":"replace","path":"/updateBy","value":123}]',
        'file': await MultipartFile.fromFile(filePath, filename: fileName),
      });

      await _dio.patch(
        'http://54.241.200.172:8800/setup-ws/api/v1/app/update-app/2',
        data: formData,
        options: Options(
          headers: {
            'Authorization': 'Bearer $_token',
          },
        ),
        onSendProgress: onSendProgress,
      );
      _notificationService.showNotification('Upload Complete', '$fileName has been uploaded.');
    } catch (e) {
      print('File upload failed: $e');
      _notificationService.showNotification('Upload Failed', 'Could not upload $fileName.');
    }
  }

  Future<void> downloadFile(String url, String fileName) async {
    try {
      final Directory? dir = await getExternalStorageDirectory();
      final String savePath = dir!.path;

      await FlutterDownloader.enqueue(
        url: url,
        savedDir: savePath,
        fileName: fileName,
        showNotification: true,
        openFileFromNotification: true,
      );
    } catch (e) {
      print('File download failed: $e');
       _notificationService.showNotification('Download Failed', 'Could not download $fileName.');
    }
  }
}
