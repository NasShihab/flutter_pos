import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import '../../providers/upload_provider.dart';
import '../../data/services/file_transfer_service.dart';
import '../widgets/transfer_dashboard.dart';

class UploadScreen extends StatefulWidget {
  const UploadScreen({super.key});

  @override
  State<UploadScreen> createState() => _UploadScreenState();
}

class _UploadScreenState extends State<UploadScreen> {
  File? _selectedFile;
  bool _isLoading = false;

  Future<void> _pickFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: false,
      );

      if (result != null && result.files.single.path != null) {
        final file = File(result.files.single.path!);

        final fileSize = file.lengthSync();
        final fileSizeMB = fileSize / (1024 * 1024);

        setState(() {
          _selectedFile = file;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Selected: ${file.path.split('/').last.split('\\').last} (${fileSizeMB.toStringAsFixed(2)} MB)',
              ),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error picking file: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _startUpload() async {
    if (_selectedFile == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final provider = Provider.of<UploadProvider>(context, listen: false);

      final hasPermissions = await provider.checkPermissions();
      if (!hasPermissions) {
        final permissions = await provider.requestPermissions();
        if (!permissions['storage']!) {
          throw Exception('Storage permission is required to upload files');
        }
      }

      await provider.startUpload(_selectedFile!);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Upload Started! Check the dashboard below."),
            backgroundColor: Colors.green,
          ),
        );

        setState(() {
          _selectedFile = null;
        });
      }
    } on FileTransferException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(2)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Upload File"),
        actions: [
          Consumer<UploadProvider>(
            builder: (context, provider, child) {
              final connectionStatus = provider.getConnectionStatus();
              final isConnected = provider.isConnected;

              return Padding(
                padding: const EdgeInsets.all(8.0),
                child: Chip(
                  avatar: Icon(
                    isConnected ? Icons.wifi : Icons.wifi_off,
                    color: isConnected ? Colors.green : Colors.red,
                    size: 16,
                  ),
                  label: Text(
                    connectionStatus,
                    style: const TextStyle(fontSize: 12),
                  ),
                  backgroundColor: isConnected
                      ? Colors.green.shade50
                      : Colors.red.shade50,
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (_selectedFile != null) ...[
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.blue.shade200),
                        ),
                        child: Column(
                          children: [
                            const Icon(
                              Icons.insert_drive_file,
                              size: 64,
                              color: Colors.blue,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _selectedFile!.path
                                  .split('/')
                                  .last
                                  .split('\\')
                                  .last,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _formatFileSize(_selectedFile!.lengthSync()),
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        onPressed: _isLoading ? null : _startUpload,
                        icon: _isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
                                ),
                              )
                            : const Icon(Icons.cloud_upload),
                        label: Text(
                          _isLoading ? "Starting..." : "Start Upload",
                        ),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 32,
                            vertical: 16,
                          ),
                          textStyle: const TextStyle(fontSize: 16),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextButton.icon(
                        onPressed: _isLoading ? null : _pickFile,
                        icon: const Icon(Icons.swap_horiz),
                        label: const Text("Pick Different File"),
                      ),
                    ] else ...[
                      Icon(
                        Icons.cloud_upload_outlined,
                        size: 80,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 24),
                      Text(
                        "No file selected",
                        style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "Select a large file (>50MB recommended)\nto test background upload",
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                      ),
                      const SizedBox(height: 32),
                      ElevatedButton.icon(
                        onPressed: _pickFile,
                        icon: const Icon(Icons.folder_open),
                        label: const Text("Select File"),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 32,
                            vertical: 16,
                          ),
                          textStyle: const TextStyle(fontSize: 16),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),

          const TransferDashboard(),
        ],
      ),
    );
  }
}
