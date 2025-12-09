import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../domain/transfer_state.dart';

class StorageService {
  static const String _transfersKey = 'transfers';
  static const String _transferHistoryKey = 'transfer_history';

  Future<void> saveTransfers(List<TransferItem> transfers) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final transfersJson = transfers.map((t) => t.toJson()).toList();
      await prefs.setString(_transfersKey, jsonEncode(transfersJson));
    } catch (e) {
      print('Error saving transfers: $e');
    }
  }

  Future<List<TransferItem>> loadTransfers() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final transfersString = prefs.getString(_transfersKey);

      if (transfersString == null) return [];

      final List<dynamic> transfersJson = jsonDecode(transfersString);
      return transfersJson.map((json) => TransferItem.fromJson(json)).toList();
    } catch (e) {
      print('Error loading transfers: $e');
      return [];
    }
  }

  Future<void> clearTransfers() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_transfersKey);
    } catch (e) {
      print('Error clearing transfers: $e');
    }
  }

  Future<void> saveToHistory(TransferItem transfer) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final historyString = prefs.getString(_transferHistoryKey);

      List<Map<String, dynamic>> history = [];
      if (historyString != null) {
        final List<dynamic> historyJson = jsonDecode(historyString);
        history = historyJson.cast<Map<String, dynamic>>();
      }

      history.insert(0, transfer.toJson());

      if (history.length > 50) {
        history = history.sublist(0, 50);
      }

      await prefs.setString(_transferHistoryKey, jsonEncode(history));
    } catch (e) {
      print('Error saving to history: $e');
    }
  }

  Future<List<TransferItem>> getHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final historyString = prefs.getString(_transferHistoryKey);

      if (historyString == null) return [];

      final List<dynamic> historyJson = jsonDecode(historyString);
      return historyJson.map((json) => TransferItem.fromJson(json)).toList();
    } catch (e) {
      print('Error loading history: $e');
      return [];
    }
  }

  Future<void> clearHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_transferHistoryKey);
    } catch (e) {
      print('Error clearing history: $e');
    }
  }
}
