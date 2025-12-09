import 'package:permission_handler/permission_handler.dart';
import 'dart:io';

class PermissionService {
  Future<bool> requestStoragePermission() async {
    if (Platform.isAndroid) {
      if (await _isAndroid13OrHigher()) {
        final statuses = await [
          Permission.photos,
          Permission.videos,
          Permission.audio,
        ].request();

        return statuses.values.every(
          (status) => status.isGranted || status.isLimited,
        );
      } else {
        final status = await Permission.storage.request();
        return status.isGranted;
      }
    } else if (Platform.isIOS) {
      final status = await Permission.photos.request();
      return status.isGranted || status.isLimited;
    }

    return true;
  }

  Future<bool> requestNotificationPermission() async {
    if (Platform.isAndroid) {
      if (await _isAndroid13OrHigher()) {
        final status = await Permission.notification.request();
        return status.isGranted;
      }
      return true;
    } else if (Platform.isIOS) {
      final status = await Permission.notification.request();
      return status.isGranted;
    }

    return true;
  }

  Future<bool> hasStoragePermission() async {
    if (Platform.isAndroid) {
      if (await _isAndroid13OrHigher()) {
        final photos = await Permission.photos.status;
        final videos = await Permission.videos.status;
        return photos.isGranted || videos.isGranted;
      } else {
        final status = await Permission.storage.status;
        return status.isGranted;
      }
    } else if (Platform.isIOS) {
      final status = await Permission.photos.status;
      return status.isGranted || status.isLimited;
    }

    return true;
  }

  Future<bool> hasNotificationPermission() async {
    if (Platform.isAndroid && await _isAndroid13OrHigher()) {
      final status = await Permission.notification.status;
      return status.isGranted;
    } else if (Platform.isIOS) {
      final status = await Permission.notification.status;
      return status.isGranted;
    }

    return true;
  }

  Future<Map<String, bool>> requestAllPermissions() async {
    final storage = await requestStoragePermission();
    final notification = await requestNotificationPermission();

    return {'storage': storage, 'notification': notification};
  }

  Future<void> openAppSettings() async {
    await openAppSettings();
  }

  Future<bool> _isAndroid13OrHigher() async {
    if (!Platform.isAndroid) return false;

    try {
      await Permission.notification.status;
      return true;
    } catch (e) {
      return false;
    }
  }

  String getStoragePermissionRationale() {
    return 'Storage permission is required to select and upload files. '
        'Please grant access to continue.';
  }

  String getNotificationPermissionRationale() {
    return 'Notification permission allows you to see upload/download progress '
        'even when the app is in the background.';
  }
}
