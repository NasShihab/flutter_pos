
enum TransferStatus { pending, inProgress, completed, failed, paused }

class FileTransfer {
  final String id;
  final String fileName;
  final TransferStatus status;
  final double progress;

  FileTransfer({
    required this.id,
    required this.fileName,
    this.status = TransferStatus.pending,
    this.progress = 0.0,
  });

  FileTransfer copyWith({
    TransferStatus? status,
    double? progress,
  }) {
    return FileTransfer(
      id: id,
      fileName: fileName,
      status: status ?? this.status,
      progress: progress ?? this.progress,
    );
  }
}
