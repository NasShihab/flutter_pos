
import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:flutter_pos/features/modul/models/file_transfer.dart';

class FileTransferProvider extends ChangeNotifier {
  final List<FileTransfer> _transfers = [];

  UnmodifiableListView<FileTransfer> get transfers => UnmodifiableListView(_transfers);

  void addTransfer(FileTransfer transfer) {
    _transfers.add(transfer);
    notifyListeners();
  }

  void updateTransfer(FileTransfer transfer) {
    final index = _transfers.indexWhere((t) => t.id == transfer.id);
    if (index != -1) {
      _transfers[index] = transfer;
      notifyListeners();
    }
  }
}
