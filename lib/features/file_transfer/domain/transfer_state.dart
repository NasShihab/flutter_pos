enum TransferType { upload, download }

enum TransferStatus {
  idle,
  queued,
  inProgress,
  paused,
  completed,
  failed,
  canceled,
}

class TransferItem {
  final String id;
  final TransferType type;
  final String filePath;
  String? url;

  TransferStatus status;
  double progress;
  String? error;
  int bytesTransferred;
  int totalBytes;
  int retryCount;
  DateTime createdAt;
  DateTime updatedAt;

  TransferItem({
    required this.id,
    required this.type,
    required this.filePath,
    this.url,
    this.status = TransferStatus.idle,
    this.progress = 0.0,
    this.bytesTransferred = 0,
    this.totalBytes = 0,
    this.error,
    this.retryCount = 0,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();

  String get fileName {
    return filePath.split('/').last.split('\\').last;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type.name,
      'filePath': filePath,
      'url': url,
      'status': status.name,
      'progress': progress,
      'error': error,
      'bytesTransferred': bytesTransferred,
      'totalBytes': totalBytes,
      'retryCount': retryCount,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory TransferItem.fromJson(Map<String, dynamic> json) {
    return TransferItem(
      id: json['id'] as String,
      type: TransferType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => TransferType.upload,
      ),
      filePath: json['filePath'] as String,
      url: json['url'] as String?,
      status: TransferStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => TransferStatus.idle,
      ),
      progress: (json['progress'] as num?)?.toDouble() ?? 0.0,
      error: json['error'] as String?,
      bytesTransferred: (json['bytesTransferred'] as num?)?.toInt() ?? 0,
      totalBytes: (json['totalBytes'] as num?)?.toInt() ?? 0,
      retryCount: (json['retryCount'] as num?)?.toInt() ?? 0,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'] as String)
          : DateTime.now(),
    );
  }

  TransferItem copyWith({
    TransferStatus? status,
    double? progress,
    String? error,
    int? bytesTransferred,
    int? totalBytes,
    int? retryCount,
    String? url,
  }) {
    return TransferItem(
      id: id,
      type: type,
      filePath: filePath,
      url: url ?? this.url,
      status: status ?? this.status,
      progress: progress ?? this.progress,
      error: error ?? this.error,
      bytesTransferred: bytesTransferred ?? this.bytesTransferred,
      totalBytes: totalBytes ?? this.totalBytes,
      retryCount: retryCount ?? this.retryCount,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }
}
