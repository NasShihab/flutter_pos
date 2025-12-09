import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'features/file_transfer/data/services/api_service.dart';
import 'features/file_transfer/data/services/file_transfer_service.dart';
import 'features/file_transfer/data/services/connectivity_service.dart';
import 'features/file_transfer/data/services/storage_service.dart';
import 'features/file_transfer/data/services/permission_service.dart';
import 'features/file_transfer/providers/download_provider.dart';
import 'features/file_transfer/providers/upload_provider.dart';
import 'features/file_transfer/presentation/screens/upload_screen.dart';
import 'features/file_transfer/presentation/screens/download_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final apiService = ApiService();
    final fileTransferService = FileTransferService(apiService);
    final connectivityService = ConnectivityService();
    final storageService = StorageService();
    final permissionService = PermissionService();

    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => DownloadProvider(
            fileTransferService,
            connectivityService,
            storageService,
            permissionService,
          ),
        ),
        ChangeNotifierProvider(
          create: (_) => UploadProvider(
            fileTransferService,
            connectivityService,
            storageService,
            permissionService,
          ),
        ),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'POS File Transfer',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
          useMaterial3: true,
        ),
        home: const HomeScreen(),
      ),
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('POS File Transfer Demo'),
        centerTitle: true,
        elevation: 2,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.deepPurple.shade50,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.cloud_sync,
                  size: 80,
                  color: Colors.deepPurple.shade400,
                ),
              ),
              const SizedBox(height: 32),

              const Text(
                'Background File Transfer',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),

              Text(
                'Upload and download files with progress tracking,\nbackground support, and network resilience',
                style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 48),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const UploadScreen()),
                  ),
                  icon: const Icon(Icons.cloud_upload),
                  label: const Text('Upload Module'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    textStyle: const TextStyle(fontSize: 16),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const DownloadScreen()),
                  ),
                  icon: const Icon(Icons.cloud_download),
                  label: const Text('Download Module'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    textStyle: const TextStyle(fontSize: 16),
                  ),
                ),
              ),
              const SizedBox(height: 32),

              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Features:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildFeature(
                        Icons.check_circle,
                        'Real-time progress tracking',
                      ),
                      _buildFeature(
                        Icons.check_circle,
                        'Pause & Resume transfers',
                      ),
                      _buildFeature(
                        Icons.check_circle,
                        'Background notifications',
                      ),
                      _buildFeature(
                        Icons.check_circle,
                        'Network connectivity monitoring',
                      ),
                      _buildFeature(
                        Icons.check_circle,
                        'Auto-retry on failure',
                      ),
                      _buildFeature(
                        Icons.check_circle,
                        'Persistent transfer state',
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeature(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.green),
          const SizedBox(width: 8),
          Text(text, style: const TextStyle(fontSize: 14)),
        ],
      ),
    );
  }
}
