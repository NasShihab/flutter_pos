
import 'package:flutter/material.dart';
import 'package:flutter_pos/features/modul/controllers/file_transfer_provider.dart';
import 'package:flutter_pos/features/modul/models/file_transfer.dart';
import 'package:flutter_pos/features/modul/screens/download_screen.dart';
import 'package:flutter_pos/features/modul/screens/upload_screen.dart';
import 'package:provider/provider.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('File Transfer Dashboard'),
      ),
      body: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const UploadScreen()),
                  );
                },
                child: const Text('Upload a File'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const DownloadScreen()),
                  );
                },
                child: const Text('Download a File'),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Text('Ongoing Transfers', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          Expanded(
            child: Consumer<FileTransferProvider>(
              builder: (context, provider, child) {
                if (provider.transfers.isEmpty) {
                  return const Center(child: Text('No ongoing transfers.'));
                }
                return ListView.builder(
                  itemCount: provider.transfers.length,
                  itemBuilder: (context, index) {
                    final transfer = provider.transfers[index];
                    return ListTile(
                      title: Text(transfer.fileName),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Status: ${transfer.status.toString().split('.').last}'),
                          if (transfer.status == TransferStatus.inProgress)
                            LinearProgressIndicator(value: transfer.progress),
                        ],
                      ),
                      trailing: Text('${(transfer.progress * 100).toStringAsFixed(0)}%'),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
