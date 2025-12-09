import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:percent_indicator/linear_percent_indicator.dart';
import '../../domain/transfer_state.dart';
import '../../providers/download_provider.dart';
import '../../providers/upload_provider.dart';

class TransferListItem extends StatelessWidget {
  final TransferItem item;
  final bool isDownload;

  const TransferListItem({
    super.key,
    required this.item,
    this.isDownload = false,
  });

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: Key(item.id),
      direction:
          item.status == TransferStatus.completed ||
              item.status == TransferStatus.canceled ||
              item.status == TransferStatus.failed
          ? DismissDirection.endToStart
          : DismissDirection.none,
      background: Container(
        color: Colors.red,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      confirmDismiss: (direction) async {
        return await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Remove Transfer'),
            content: const Text('Remove this transfer from the list?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Remove'),
              ),
            ],
          ),
        );
      },
      onDismissed: (direction) {
        if (isDownload) {
          Provider.of<DownloadProvider>(
            context,
            listen: false,
          ).removeDownload(item.id);
        } else {
          Provider.of<UploadProvider>(
            context,
            listen: false,
          ).removeUpload(item.id);
        }
      },
      child: Card(
        margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 10),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        item.type == TransferType.upload
                            ? Icons.upload
                            : Icons.download,
                        color: item.type == TransferType.upload
                            ? Colors.blue
                            : Colors.green,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: MediaQuery.of(context).size.width * 0.4,
                        child: Text(
                          item.fileName,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  _buildActionButtons(context, item),
                ],
              ),
              const SizedBox(height: 8),

              if (item.status == TransferStatus.failed && item.error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.error_outline,
                        color: Colors.red,
                        size: 16,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          item.error!,
                          style: const TextStyle(
                            color: Colors.red,
                            fontSize: 12,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),

              Row(
                children: [
                  Expanded(
                    child: LinearPercentIndicator(
                      lineHeight: 8.0,
                      percent: item.progress.clamp(0.0, 1.0),
                      backgroundColor: Colors.grey[200],
                      progressColor: _getColorForStatus(item.status),
                      barRadius: const Radius.circular(4),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text('${(item.progress * 100).toStringAsFixed(0)}%'),
                ],
              ),
              const SizedBox(height: 4),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${_formatBytes(item.bytesTransferred)} / ${_formatBytes(item.totalBytes)}',
                    style: TextStyle(color: Colors.grey[600], fontSize: 11),
                  ),
                  Row(
                    children: [
                      if (item.retryCount > 0)
                        Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: Text(
                            'Retry: ${item.retryCount}',
                            style: TextStyle(
                              color: Colors.orange[700],
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      Text(
                        item.status.name.toUpperCase(),
                        style: TextStyle(
                          color: _getColorForStatus(item.status),
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context, TransferItem item) {
    if (item.status == TransferStatus.inProgress) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.pause, size: 20),
            tooltip: 'Pause',
            onPressed: () {
              if (isDownload) {
                Provider.of<DownloadProvider>(
                  context,
                  listen: false,
                ).pauseDownload(item.id);
              } else {
                Provider.of<UploadProvider>(
                  context,
                  listen: false,
                ).pauseUpload(item.id);
              }
            },
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      );
    } else if (item.status == TransferStatus.paused ||
        item.status == TransferStatus.failed) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.play_arrow, size: 20),
            tooltip: item.status == TransferStatus.failed ? 'Retry' : 'Resume',
            onPressed: () {
              if (isDownload) {
                Provider.of<DownloadProvider>(
                  context,
                  listen: false,
                ).resumeDownload(item.id);
              } else {
                Provider.of<UploadProvider>(
                  context,
                  listen: false,
                ).resumeUpload(item.id);
              }
            },
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
          if (item.status == TransferStatus.inProgress ||
              item.status == TransferStatus.paused)
            IconButton(
              icon: const Icon(Icons.close, size: 20),
              tooltip: 'Cancel',
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Cancel Transfer'),
                    content: const Text(
                      'Are you sure you want to cancel this transfer?',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('No'),
                      ),
                      TextButton(
                        onPressed: () {
                          if (isDownload) {
                            Provider.of<DownloadProvider>(
                              context,
                              listen: false,
                            ).cancelDownload(item.id);
                          } else {
                            Provider.of<UploadProvider>(
                              context,
                              listen: false,
                            ).cancelUpload(item.id);
                          }
                          Navigator.pop(context);
                        },
                        child: const Text('Yes'),
                      ),
                    ],
                  ),
                );
              },
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
        ],
      );
    }

    return const SizedBox.shrink();
  }

  Color _getColorForStatus(TransferStatus status) {
    switch (status) {
      case TransferStatus.completed:
        return Colors.green;
      case TransferStatus.failed:
        return Colors.red;
      case TransferStatus.paused:
        return Colors.orange;
      case TransferStatus.canceled:
        return Colors.grey;
      case TransferStatus.inProgress:
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}
