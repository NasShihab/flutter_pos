import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:open_file/open_file.dart';
import '../../providers/download_provider.dart';
import '../../data/services/file_transfer_service.dart';
import '../../domain/transfer_state.dart';
import '../widgets/transfer_dashboard.dart';

class DownloadScreen extends StatefulWidget {
  const DownloadScreen({super.key});

  @override
  State<DownloadScreen> createState() => _DownloadScreenState();
}

class _DownloadScreenState extends State<DownloadScreen> {
  final TextEditingController _urlController = TextEditingController();
  bool _isLoading = false;

  static const String _defaultTestUrl = 'http://speedtest.tele2.net/100MB.zip';

  @override
  void initState() {
    super.initState();
    _urlController.text = _defaultTestUrl;
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  bool _isValidUrl(String url) {
    try {
      final uri = Uri.parse(url);
      return uri.hasScheme && (uri.scheme == 'http' || uri.scheme == 'https');
    } catch (e) {
      return false;
    }
  }

  Future<void> _startDownload() async {
    final url = _urlController.text.trim();

    if (url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a URL'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (!_isValidUrl(url)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid HTTP/HTTPS URL'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final provider = Provider.of<DownloadProvider>(context, listen: false);

      final hasPermissions = await provider.checkPermissions();
      if (!hasPermissions) {
        final permissions = await provider.requestPermissions();
        if (!permissions['notification']!) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Notification permission recommended for background progress',
                ),
                duration: Duration(seconds: 3),
              ),
            );
          }
        }
      }

      await provider.startDownload(url);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              "Download Started! File will be saved to Downloads folder",
            ),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
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

  Widget _buildCompletedDownloads() {
    return Consumer<DownloadProvider>(
      builder: (context, provider, child) {
        final completedDownloads = provider.downloads
            .where((t) => t.status == TransferStatus.completed)
            .toList();

        if (completedDownloads.isEmpty) {
          return const SizedBox.shrink();
        }

        return Card(
          margin: const EdgeInsets.all(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Recent Downloads',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                ...completedDownloads.take(3).map((transfer) {
                  return ListTile(
                    dense: true,
                    leading: const Icon(
                      Icons.check_circle,
                      color: Colors.green,
                    ),
                    title: Text(transfer.fileName),
                    subtitle: Text(transfer.filePath),
                    trailing: IconButton(
                      icon: const Icon(Icons.open_in_new),
                      onPressed: () async {
                        try {
                          await OpenFile.open(transfer.filePath);
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Cannot open: $e')),
                            );
                          }
                        }
                      },
                    ),
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Download File"),
        actions: [
          Consumer<DownloadProvider>(
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
            child: SingleChildScrollView(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Enter File URL to Download",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _urlController,
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            labelText: 'URL',
                            hintText: 'https://example.com/file.zip',
                            suffixIcon: Icon(Icons.link),
                          ),
                          maxLines: 3,
                          minLines: 1,
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _isLoading ? null : _startDownload,
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
                                : const Icon(Icons.download),
                            label: Text(
                              _isLoading ? "Starting..." : "Start Download",
                            ),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              textStyle: const TextStyle(fontSize: 16),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Tip: Files will be saved to Downloads folder',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _buildCompletedDownloads(),
                ],
              ),
            ),
          ),

          const TransferDashboard(),
        ],
      ),
    );
  }
}
