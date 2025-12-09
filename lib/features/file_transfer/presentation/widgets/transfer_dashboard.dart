import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/download_provider.dart';
import '../../providers/upload_provider.dart';
import '../../domain/transfer_state.dart';
import 'transfer_list_item.dart';

class TransferDashboard extends StatefulWidget {
  const TransferDashboard({super.key});

  @override
  State<TransferDashboard> createState() => _TransferDashboardState();
}

class _TransferDashboardState extends State<TransferDashboard> {
  TransferStatus? _filterStatus;

  @override
  Widget build(BuildContext context) {
    return Consumer2<DownloadProvider, UploadProvider>(
      builder: (context, downloadProvider, uploadProvider, child) {
        final allTransfers = [
          ...downloadProvider.downloads,
          ...uploadProvider.uploads,
        ];

        var filteredTransfers = allTransfers;
        if (_filterStatus != null) {
          filteredTransfers = filteredTransfers
              .where((t) => t.status == _filterStatus)
              .toList();
        }

        if (allTransfers.isEmpty) {
          return Container(
            height: 120,
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: const Center(
              child: Padding(
                padding: EdgeInsets.all(20.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.inbox_outlined, size: 40, color: Colors.grey),
                    SizedBox(height: 8),
                    Text(
                      "No Active Transfers",
                      style: TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        return Container(
          height: 350,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(16),
              topRight: Radius.circular(16),
            ),
            boxShadow: [
              BoxShadow(blurRadius: 10, color: Colors.black12, spreadRadius: 5),
            ],
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(12.0),
                child: Row(
                  children: [
                    const Text(
                      "Transfer Dashboard",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),

                    PopupMenuButton<TransferStatus?>(
                      icon: Icon(
                        Icons.filter_list,
                        color: _filterStatus != null
                            ? Colors.blue
                            : Colors.grey,
                      ),
                      tooltip: 'Filter',
                      onSelected: (status) {
                        setState(() {
                          _filterStatus = status;
                        });
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(value: null, child: Text('All')),
                        const PopupMenuItem(
                          value: TransferStatus.inProgress,
                          child: Text('In Progress'),
                        ),
                        const PopupMenuItem(
                          value: TransferStatus.paused,
                          child: Text('Paused'),
                        ),
                        const PopupMenuItem(
                          value: TransferStatus.completed,
                          child: Text('Completed'),
                        ),
                        const PopupMenuItem(
                          value: TransferStatus.failed,
                          child: Text('Failed'),
                        ),
                      ],
                    ),

                    if (allTransfers.any(
                      (t) => t.status == TransferStatus.completed,
                    ))
                      IconButton(
                        icon: const Icon(Icons.clear_all),
                        tooltip: 'Clear Completed',
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text('Clear Completed'),
                              content: const Text(
                                'Remove all completed transfers from the list?',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: const Text('Cancel'),
                                ),
                                TextButton(
                                  onPressed: () {
                                    downloadProvider.clearCompleted();
                                    uploadProvider.clearCompleted();
                                    Navigator.pop(context);
                                  },
                                  child: const Text('Clear'),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                  ],
                ),
              ),
              const Divider(height: 1),

              Expanded(
                child: filteredTransfers.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(20.0),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.filter_alt_off,
                                size: 40,
                                color: Colors.grey[400],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'No ${_filterStatus?.name ?? ''} transfers',
                                style: TextStyle(color: Colors.grey[600]),
                              ),
                            ],
                          ),
                        ),
                      )
                    : ListView.builder(
                        itemCount: filteredTransfers.length,
                        itemBuilder: (context, index) {
                          final item =
                              filteredTransfers[filteredTransfers.length -
                                  1 -
                                  index];
                          return TransferListItem(
                            item: item,
                            isDownload: item.type == TransferType.download,
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}
