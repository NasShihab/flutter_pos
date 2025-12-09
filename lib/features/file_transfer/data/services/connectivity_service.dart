import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';

class ConnectivityService {
  final Connectivity _connectivity = Connectivity();

  final StreamController<ConnectivityResult> _connectivityController =
      StreamController<ConnectivityResult>.broadcast();

  Stream<ConnectivityResult> get connectivityStream =>
      _connectivityController.stream;

  ConnectivityResult _currentStatus = ConnectivityResult.none;
  ConnectivityResult get currentStatus => _currentStatus;

  bool get isConnected => _currentStatus != ConnectivityResult.none;

  ConnectivityService() {
    _init();
  }

  void _init() {
    _connectivity.onConnectivityChanged.listen((
      List<ConnectivityResult> results,
    ) {
      final result = results.isNotEmpty
          ? results.first
          : ConnectivityResult.none;
      _currentStatus = result;
      _connectivityController.add(result);
    });

    _checkInitialStatus();
  }

  Future<void> _checkInitialStatus() async {
    try {
      final results = await _connectivity.checkConnectivity();
      _currentStatus = results.isNotEmpty
          ? results.first
          : ConnectivityResult.none;
      _connectivityController.add(_currentStatus);
    } catch (e) {
      print('Error checking connectivity: $e');
      _currentStatus = ConnectivityResult.none;
    }
  }

  Future<bool> checkConnection() async {
    try {
      final results = await _connectivity.checkConnectivity();
      _currentStatus = results.isNotEmpty
          ? results.first
          : ConnectivityResult.none;
      return isConnected;
    } catch (e) {
      print('Error checking connection: $e');
      return false;
    }
  }

  String getConnectionType() {
    switch (_currentStatus) {
      case ConnectivityResult.wifi:
        return 'WiFi';
      case ConnectivityResult.mobile:
        return 'Mobile Data';
      case ConnectivityResult.ethernet:
        return 'Ethernet';
      case ConnectivityResult.vpn:
        return 'VPN';
      case ConnectivityResult.bluetooth:
        return 'Bluetooth';
      case ConnectivityResult.other:
        return 'Other';
      case ConnectivityResult.none:
        return 'No Connection';
    }
  }

  void dispose() {
    _connectivityController.close();
  }
}
