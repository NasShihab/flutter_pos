import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:uuid/uuid.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../domain/transfer_state.dart';
import '../data/services/file_transfer_service.dart';
import '../data/services/connectivity_service.dart';
import '../data/services/storage_service.dart';
import '../data/services/permission_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class UploadProvider extends ChangeNotifier {
  final FileTransferService _service;
  final ConnectivityService _connectivityService;
  final StorageService _storageService;
  final PermissionService _permissionService;

  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  final List<TransferItem> _uploads = [];
  List<TransferItem> get uploads => List.unmodifiable(_uploads);

  final Map<String, CancelToken> _cancelTokens = {};

  bool _isConnected = true;
  bool get isConnected => _isConnected;

  UploadProvider(
    this._service,
    this._connectivityService,
    this._storageService,
    this._permissionService,
  ) {
    _initNotifications();
    _initConnectivity();
    _loadPersistedUploads();
  }

  Future<void> _initNotifications() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const DarwinInitializationSettings initializationSettingsDarwin =
        DarwinInitializationSettings();
    const InitializationSettings initializationSettings =
        InitializationSettings(
          android: initializationSettingsAndroid,
          iOS: initializationSettingsDarwin,
        );

    await _notificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );
  }

  void _onNotificationTapped(NotificationResponse response) {
    print('Notification tapped: ${response.payload}');
  }

  void _initConnectivity() {
    _connectivityService.connectivityStream.listen((result) {
      final wasConnected = _isConnected;
      _isConnected = result != ConnectivityResult.none;

      if (!wasConnected && _isConnected) {
        _autoResumePausedUploads();
      }

      notifyListeners();
    });

    _isConnected = _connectivityService.isConnected;
  }

  Future<void> _loadPersistedUploads() async {
    try {
      final savedTransfers = await _storageService.loadTransfers();

      for (var transfer in savedTransfers) {
        if (transfer.type == TransferType.upload &&
            transfer.status != TransferStatus.completed) {
          if (transfer.status == TransferStatus.inProgress) {
            transfer.status = TransferStatus.paused;
          }
          _uploads.add(transfer);
        }
      }

      notifyListeners();
    } catch (e) {
      print('Error loading persisted uploads: $e');
    }
  }

  Future<void> _persistUploads() async {
    try {
      await _storageService.saveTransfers(_uploads);
    } catch (e) {
      print('Error persisting uploads: $e');
    }
  }

  void _autoResumePausedUploads() {
    for (var upload in _uploads) {
      if (upload.status == TransferStatus.paused && upload.error != null) {
        if (upload.error!.contains('network') ||
            upload.error!.contains('connection') ||
            upload.error!.contains('internet')) {
          resumeUpload(upload.id);
        }
      }
    }
  }

  Future<void> _showProgressNotification(
    String id,
    String title,
    int progress,
    int max,
  ) async {
    final androidPlatformChannelSpecifics = AndroidNotificationDetails(
      'upload_channel',
      'File Uploads',
      channelDescription: 'Notifications for file uploads',
      importance: Importance.low,
      priority: Priority.low,
      onlyAlertOnce: true,
      showProgress: true,
      maxProgress: max,
      progress: progress,
      ongoing: true,
    );
    final platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
    );

    await _notificationsPlugin.show(
      id.hashCode,
      title,
      '${(progress / max * 100).toInt()}%',
      platformChannelSpecifics,
      payload: id,
    );
  }

  Future<void> _showCompletionNotification(
    String id,
    String title,
    String body,
  ) async {
    final androidPlatformChannelSpecifics = const AndroidNotificationDetails(
      'upload_channel',
      'File Uploads',
      channelDescription: 'Notifications for file uploads',
      importance: Importance.high,
      priority: Priority.high,
      ongoing: false,
    );
    final platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
    );

    await _notificationsPlugin.show(
      id.hashCode,
      title,
      body,
      platformChannelSpecifics,
      payload: id,
    );
  }

  Future<bool> checkPermissions() async {
    final hasStorage = await _permissionService.hasStoragePermission();
    final hasNotification = await _permissionService
        .hasNotificationPermission();
    return hasStorage && hasNotification;
  }

  Future<Map<String, bool>> requestPermissions() async {
    return await _permissionService.requestAllPermissions();
  }

  Future<void> startUpload(File file) async {
    if (!await _permissionService.hasStoragePermission()) {
      final granted = await _permissionService.requestStoragePermission();
      if (!granted) {
        throw FileTransferException('Storage permission denied');
      }
    }

    if (!_isConnected) {
      throw FileTransferException('No internet connection');
    }

    try {
      _service.validateFile(file);
    } catch (e) {
      throw FileTransferException(e.toString());
    }

    final String id = const Uuid().v4();
    final item = TransferItem(
      id: id,
      type: TransferType.upload,
      filePath: file.path,
      status: TransferStatus.queued,
    );
    _uploads.add(item);
    notifyListeners();
    await _persistUploads();

    await _performUpload(item);
  }

  Future<void> _performUpload(TransferItem item) async {
    if (!_isConnected) {
      _updateStatus(
        item.id,
        TransferStatus.paused,
        error: 'No internet connection',
      );
      return;
    }

    _updateStatus(item.id, TransferStatus.inProgress);
    _showProgressNotification(item.id, 'Uploading ${item.fileName}', 0, 100);

    final cancelToken = CancelToken();
    _cancelTokens[item.id] = cancelToken;

    try {
      final response = await _service.uploadFile(
        file: File(item.filePath),
        cancelToken: cancelToken,
        onProgress: (sent, total) {
          _updateProgress(item.id, sent, total);
          if (total > 0) {
            _showProgressNotification(item.id, 'Uploading...', sent, total);
          }
        },
      );

      final index = _uploads.indexWhere((t) => t.id == item.id);
      if (index != -1 && response.fileUrl != null) {
        _uploads[index].url = response.fileUrl;
      }

      _updateStatus(item.id, TransferStatus.completed);
      await _storageService.saveToHistory(item);
      _showCompletionNotification(
        item.id,
        'Upload Complete',
        '${item.fileName} uploaded successfully.',
      );
    } catch (e) {
      if (e is DioException && CancelToken.isCancel(e)) {
        _updateStatus(item.id, TransferStatus.paused);
        _showCompletionNotification(
          item.id,
          'Upload Paused',
          'Upload was paused',
        );
      } else {
        final errorMessage = e.toString();
        _updateStatus(item.id, TransferStatus.failed, error: errorMessage);

        final index = _uploads.indexWhere((t) => t.id == item.id);
        if (index != -1) {
          _uploads[index].retryCount++;
        }

        _showCompletionNotification(
          item.id,
          'Upload Failed',
          'Error: $errorMessage',
        );
      }
    } finally {
      _cancelTokens.remove(item.id);
      await _persistUploads();
    }
  }

  void pauseUpload(String id) {
    if (_cancelTokens.containsKey(id)) {
      _cancelTokens[id]!.cancel();
      _updateStatus(id, TransferStatus.paused);
    }
  }

  void resumeUpload(String id) {
    final index = _uploads.indexWhere((t) => t.id == id);
    if (index == -1) return;

    final item = _uploads[index];

    if (!_isConnected) {
      _updateStatus(id, TransferStatus.paused, error: 'No internet connection');
      return;
    }

    if (item.status == TransferStatus.paused ||
        item.status == TransferStatus.failed) {
      item.error = null;
      _performUpload(item);
    }
  }

  void retryUpload(String id) => resumeUpload(id);

  void cancelUpload(String id) {
    if (_cancelTokens.containsKey(id)) {
      _cancelTokens[id]!.cancel();
    }
    _updateStatus(id, TransferStatus.canceled);
  }

  void removeUpload(String id) {
    _uploads.removeWhere((t) => t.id == id);
    _cancelTokens.remove(id);
    notifyListeners();
    _persistUploads();
  }

  void clearCompleted() {
    _uploads.removeWhere((t) => t.status == TransferStatus.completed);
    notifyListeners();
    _persistUploads();
  }

  void _updateStatus(String id, TransferStatus status, {String? error}) {
    final index = _uploads.indexWhere((t) => t.id == id);
    if (index != -1) {
      _uploads[index].status = status;
      _uploads[index].updatedAt = DateTime.now();
      if (error != null) {
        _uploads[index].error = error;
      }
      notifyListeners();
      _persistUploads();
    }
  }

  void _updateProgress(String id, int current, int total) {
    final index = _uploads.indexWhere((t) => t.id == id);
    if (index != -1) {
      final item = _uploads[index];
      item.bytesTransferred = current;
      item.totalBytes = total;
      item.updatedAt = DateTime.now();
      if (total > 0) {
        item.progress = current / total;
      }
      notifyListeners();

      if (item.progress == 1.0 ||
          item.bytesTransferred % (1024 * 1024 * 5) == 0) {
        _persistUploads();
      }
    }
  }

  String getConnectionStatus() {
    return _connectivityService.getConnectionType();
  }

  @override
  void dispose() {
    _connectivityService.dispose();
    super.dispose();
  }
}
