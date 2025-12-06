
import 'dart:isolate';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_downloader/flutter_downloader.dart';
import 'package:flutter_pos/features/modul/controllers/file_transfer_provider.dart';
import 'package:flutter_pos/features/modul/models/file_transfer.dart';
import 'package:flutter_pos/features/modul/services/api_service.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

class DownloadScreen extends StatefulWidget {
  const DownloadScreen({super.key});

  @override
  State<DownloadScreen> createState() => _DownloadScreenState();
}

class _DownloadScreenState extends State<DownloadScreen> {
  final ApiService _apiService = ApiService();
  List<dynamic> _permittedApps = [];
  final ReceivePort _port = ReceivePort();

  @override
  void initState() {
    super.initState();
    _getPermittedApps();
    IsolateNameServer.registerPortWithName(_port.sendPort, 'downloader_send_port');
    _port.listen((dynamic data) {
      final String id = data[0];
      final DownloadTaskStatus status = DownloadTaskStatus.fromInt(data[1]);
      final int progress = data[2];

      final transfer = context.read<FileTransferProvider>().transfers.firstWhere((t) => t.id == id);

      if (status == DownloadTaskStatus.running) {
        context.read<FileTransferProvider>().updateTransfer(
              transfer.copyWith(status: TransferStatus.inProgress, progress: progress / 100),
            );
      } else if (status == DownloadTaskStatus.complete) {
        context.read<FileTransferProvider>().updateTransfer(
              transfer.copyWith(status: TransferStatus.completed, progress: 1.0),
            );
      } else if (status == DownloadTaskStatus.failed) {
        context.read<FileTransferProvider>().updateTransfer(
              transfer.copyWith(status: TransferStatus.failed),
            );
      }
    });
    FlutterDownloader.registerCallback(downloadCallback);
  }

  @pragma('vm:entry-point')
  static void downloadCallback(String id, int status, int progress) {
    final SendPort? send = IsolateNameServer.lookupPortByName('downloader_send_port');
    send?.send([id, status, progress]);
  }

  @override
  void dispose() {
    IsolateNameServer.removePortNameMapping('downloader_send_port');
    super.dispose();
  }

  Future<void> _getPermittedApps() async {
    final apps = await _apiService.getPermittedApps();
    setState(() {
      _permittedApps = apps;
    });
  }

  Future<void> _downloadFile(String url, String fileName) async {
    final status = await Permission.storage.request();

    if (status.isGranted) {
      final taskId = await _apiService.downloadFile(url, fileName);
      if (taskId != null) {
        final transfer = FileTransfer(
          id: taskId,
          fileName: fileName,
        );
        context.read<FileTransferProvider>().addTransfer(transfer);
      }
    } else {
      print('Permission denied');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Download File'),
      ),
      body: _permittedApps.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: _permittedApps.length,
              itemBuilder: (context, index) {
                final app = _permittedApps[index];
                return ListTile(
                  title: Text(app['appName']),
                  trailing: IconButton(
                    icon: const Icon(Icons.download),
                    onPressed: () {
                      // Since the API doesn't provide a download URL,
                      // we'll use the preview URL as a placeholder.
                      _downloadFile(app['appLogo'], app['appName'] + '.jpg');
                    },
                  ),
                );
              },
            ),
    );
  }
}
