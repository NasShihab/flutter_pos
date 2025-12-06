
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_pos/features/modul/controllers/file_transfer_provider.dart';
import 'package:flutter_pos/features/modul/models/file_transfer.dart';
import 'package:flutter_pos/features/modul/services/api_service.dart';
import 'package:provider/provider.dart';

class UploadScreen extends StatefulWidget {
  const UploadScreen({super.key});

  @override
  State<UploadScreen> createState() => _UploadScreenState();
}

class _UploadScreenState extends State<UploadScreen> {
  final ApiService _apiService = ApiService();

  Future<void> _pickAndUploadFile() async {
    final result = await FilePicker.platform.pickFiles();

    if (result != null) {
      final file = File(result.files.single.path!);
      final transfer = FileTransfer(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        fileName: file.path.split('/').last,
      );

      context.read<FileTransferProvider>().addTransfer(transfer);

      await _apiService.uploadFile(
        file.path,
        onSendProgress: (sent, total) {
          final progress = sent / total;
          context.read<FileTransferProvider>().updateTransfer(
                transfer.copyWith(status: TransferStatus.inProgress, progress: progress),
              );
        },
      );

      context.read<FileTransferProvider>().updateTransfer(
            transfer.copyWith(status: TransferStatus.completed, progress: 1.0),
          );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Upload File'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: _pickAndUploadFile,
              child: const Text('Pick and Upload File'),
            ),
          ],
        ),
      ),
    );
  }
}
