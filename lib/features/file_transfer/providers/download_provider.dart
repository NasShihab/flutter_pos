import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:uuid/uuid.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:path_provider/path_provider.dart';
import '../domain/transfer_state.dart';
import '../data/services/file_transfer_service.dart';
import '../data/services/connectivity_service.dart';
import '../data/services/storage_service.dart';
import '../data/services/permission_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class DownloadProvider extends ChangeNotifier {
  final FileTransferService _service;
  final ConnectivityService _connectivityService;
  final StorageService _storageService;
  final PermissionService _permissionService;

  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  final List<TransferItem> _downloads = [];
  List<TransferItem> get downloads => List.unmodifiable(_downloads);

  final Map<String, CancelToken> _cancelTokens = {};

  bool _isConnected = true;
  bool get isConnected => _isConnected;

  DownloadProvider(
    this._service,
    this._connectivityService,
    this._storageService,
    this._permissionService,
  ) {
    _initNotifications();
    _initConnectivity();
    _loadPersistedDownloads();
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
        _autoResumePausedDownloads();
      }

      notifyListeners();
    });

    _isConnected = _connectivityService.isConnected;
  }

  Future<void> _loadPersistedDownloads() async {
    try {
      final savedTransfers = await _storageService.loadTransfers();

      for (var transfer in savedTransfers) {
        if (transfer.type == TransferType.download &&
            transfer.status != TransferStatus.completed) {
          if (transfer.status == TransferStatus.inProgress) {
            transfer.status = TransferStatus.paused;
          }
          _downloads.add(transfer);
        }
      }

      notifyListeners();
    } catch (e) {
      print('Error loading persisted downloads: $e');
    }
  }

  Future<void> _persistDownloads() async {
    try {
      await _storageService.saveTransfers(_downloads);
    } catch (e) {
      print('Error persisting downloads: $e');
    }
  }

  void _autoResumePausedDownloads() {
    for (var download in _downloads) {
      if (download.status == TransferStatus.paused && download.error != null) {
        if (download.error!.contains('network') ||
            download.error!.contains('connection') ||
            download.error!.contains('internet')) {
          resumeDownload(download.id);
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
      'download_channel',
      'File Downloads',
      channelDescription: 'Notifications for file downloads',
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
      'download_channel',
      'File Downloads',
      channelDescription: 'Notifications for file downloads',
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
    final hasNotification = await _permissionService
        .hasNotificationPermission();
    return hasNotification;
  }

  Future<Map<String, bool>> requestPermissions() async {
    return await _permissionService.requestAllPermissions();
  }

  Future<String> _getDownloadPath(String url) async {
    final downloadsDir = await getDownloadsDirectory();
    if (downloadsDir == null) {
      throw FileTransferException('Could not access downloads directory');
    }

    final fileName = url.split('/').last.split('?').first;
    final sanitizedFileName = fileName.isEmpty
        ? 'download_${DateTime.now().millisecondsSinceEpoch}'
        : fileName;

    return '${downloadsDir.path}/$sanitizedFileName';
  }

  Future<void> startDownload(String url) async {
    if (!await _permissionService.hasNotificationPermission()) {
      await _permissionService.requestNotificationPermission();
    }

    if (!_isConnected) {
      throw FileTransferException('No internet connection');
    }

    final savePath = await _getDownloadPath(url);

    final String id = const Uuid().v4();
    final item = TransferItem(
      id: id,
      type: TransferType.download,
      filePath: savePath,
      url: url,
      status: TransferStatus.queued,
    );
    _downloads.add(item);
    notifyListeners();
    await _persistDownloads();

    await _performDownload(item);
  }

  Future<void> _performDownload(TransferItem item) async {
    if (!_isConnected) {
      _updateStatus(
        item.id,
        TransferStatus.paused,
        error: 'No internet connection',
      );
      return;
    }

    _updateStatus(item.id, TransferStatus.inProgress);
    _showProgressNotification(item.id, 'Downloading ${item.fileName}', 0, 100);

    final cancelToken = CancelToken();
    _cancelTokens[item.id] = cancelToken;

    try {
      if (item.url == null) throw FileTransferException('URL is null');

      await _service.downloadFile(
        url: item.url!,
        savePath: item.filePath,
        cancelToken: cancelToken,
        onProgress: (received, total) {
          _updateProgress(item.id, received, total);
          if (total > 0) {
            _showProgressNotification(
              item.id,
              'Downloading...',
              received,
              total,
            );
          }
        },
      );

      _updateStatus(item.id, TransferStatus.completed);
      await _storageService.saveToHistory(item);
      _showCompletionNotification(
        item.id,
        'Download Complete',
        'File saved to ${item.filePath}',
      );
    } catch (e) {
      if (e is DioException && CancelToken.isCancel(e)) {
        _updateStatus(item.id, TransferStatus.paused);
        _showCompletionNotification(
          item.id,
          'Download Paused',
          'Download was paused',
        );
      } else {
        final errorMessage = e.toString();
        _updateStatus(item.id, TransferStatus.failed, error: errorMessage);

        final index = _downloads.indexWhere((t) => t.id == item.id);
        if (index != -1) {
          _downloads[index].retryCount++;
        }

        _showCompletionNotification(
          item.id,
          'Download Failed',
          'Error: $errorMessage',
        );
      }
    } finally {
      _cancelTokens.remove(item.id);
      await _persistDownloads();
    }
  }

  void pauseDownload(String id) {
    if (_cancelTokens.containsKey(id)) {
      _cancelTokens[id]!.cancel();
      _updateStatus(id, TransferStatus.paused);
    }
  }

  void resumeDownload(String id) {
    final index = _downloads.indexWhere((t) => t.id == id);
    if (index == -1) return;

    final item = _downloads[index];

    if (!_isConnected) {
      _updateStatus(id, TransferStatus.paused, error: 'No internet connection');
      return;
    }

    if (item.status == TransferStatus.paused ||
        item.status == TransferStatus.failed) {
      item.error = null;
      _performDownload(item);
    }
  }

  void retryDownload(String id) => resumeDownload(id);

  void cancelDownload(String id) {
    if (_cancelTokens.containsKey(id)) {
      _cancelTokens[id]!.cancel();
    }
    _updateStatus(id, TransferStatus.canceled);
  }

  void removeDownload(String id) {
    _downloads.removeWhere((t) => t.id == id);
    _cancelTokens.remove(id);
    notifyListeners();
    _persistDownloads();
  }

  void clearCompleted() {
    _downloads.removeWhere((t) => t.status == TransferStatus.completed);
    notifyListeners();
    _persistDownloads();
  }

  void _updateStatus(String id, TransferStatus status, {String? error}) {
    final index = _downloads.indexWhere((t) => t.id == id);
    if (index != -1) {
      _downloads[index].status = status;
      _downloads[index].updatedAt = DateTime.now();
      if (error != null) {
        _downloads[index].error = error;
      }
      notifyListeners();
      _persistDownloads();
    }
  }

  void _updateProgress(String id, int current, int total) {
    final index = _downloads.indexWhere((t) => t.id == id);
    if (index != -1) {
      final item = _downloads[index];
      item.bytesTransferred = current;
      item.totalBytes = total;
      item.updatedAt = DateTime.now();
      if (total > 0) {
        item.progress = current / total;
      }
      notifyListeners();

      if (item.progress == 1.0 ||
          item.bytesTransferred % (1024 * 1024 * 5) == 0) {
        _persistDownloads();
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
