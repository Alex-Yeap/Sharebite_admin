import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:data_table_2/data_table_2.dart';
import 'package:intl/intl.dart';
import '../../../controllers/admin_controller.dart';
import '../../../core/admin_theme.dart';

class ReportsPage extends StatefulWidget {
  const ReportsPage({super.key});

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  bool _showResolved = false;
  Key _streamKey = UniqueKey();

  void _refreshList() {
    setState(() {
      _streamKey = UniqueKey();
    });
  }

  @override
  Widget build(BuildContext context) {
    final adminController = Provider.of<AdminController>(context);

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Text("User & Content Reports", style: AdminTheme.headerStyle),
                  const SizedBox(width: 16),
                  InkWell(
                    onTap: _refreshList,
                    borderRadius: BorderRadius.circular(30),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(color: Colors.grey.shade300),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.refresh, color: AdminTheme.merchantOrange, size: 20),
                    ),
                  ),
                ],
              ),
              FilterChip(
                label: Text(_showResolved ? "View Pending" : "View History"),
                selected: _showResolved,
                onSelected: (v) => setState(() => _showResolved = v),
                backgroundColor: Colors.white,
                selectedColor: AdminTheme.merchantOrange.withOpacity(0.2),
                checkmarkColor: AdminTheme.merchantOrange,
              )
            ],
          ),
          const SizedBox(height: 20),

          Expanded(
            child: Container(
              decoration: AdminTheme.cardDecoration,
              padding: const EdgeInsets.all(16),
              child: StreamBuilder<QuerySnapshot>(
                key: _streamKey, // Key change triggers rebuild
                stream: FirebaseFirestore.instance.collection('reports').orderBy('timestamp', descending: true).snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return const Center(child: Text("No reports found.", style: TextStyle(color: Colors.grey)));
                  }

                  final docs = snapshot.data!.docs.where((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    final status = data['status'] ?? 'pending';
                    return _showResolved ? status == 'resolved' : status == 'pending';
                  }).toList();

                  if (docs.isEmpty) {
                    return Center(child: Text(_showResolved ? "No resolved reports." : "No pending reports.", style: const TextStyle(color: Colors.grey)));
                  }

                  return DataTable2(
                    columnSpacing: 12,
                    horizontalMargin: 12,
                    minWidth: 900,
                    headingTextStyle: AdminTheme.tableHeader,
                    columns: const [
                      DataColumn2(label: Text('Date'), size: ColumnSize.S),
                      DataColumn(label: Text('Type')),
                      DataColumn(label: Text('Complaint / Content')),
                      DataColumn(label: Text('Reported User')),
                      DataColumn(label: Text('Actions')),
                    ],
                    rows: docs.map((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      final type = data['type'] ?? 'general';
                      final date = data['timestamp'] != null ? DateFormat('MM-dd HH:mm').format((data['timestamp'] as Timestamp).toDate()) : '-';

                      bool isContentReport = type == 'comment' || type == 'review';

                      return DataRow(cells: [
                        DataCell(Text(date, style: const TextStyle(fontSize: 12))),
                        DataCell(Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                              color: isContentReport ? Colors.purple.shade50 : Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: isContentReport ? Colors.purple.shade200 : Colors.blue.shade200)
                          ),
                          child: Text(type.toUpperCase(), style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: isContentReport ? Colors.purple.shade800 : Colors.blue.shade800)),
                        )),
                        DataCell(
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(data['reason'] ?? 'No reason', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                if (data['contentSnapshot'] != null)
                                  Text("\"${data['contentSnapshot']}\"", style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Colors.grey.shade600), maxLines: 1, overflow: TextOverflow.ellipsis),
                              ],
                            )
                        ),
                        DataCell(Text(data['reportedId'] ?? 'Unknown', style: const TextStyle(fontFamily: 'monospace', fontSize: 11))),
                        DataCell(
                            isContentReport && !_showResolved
                                ? ElevatedButton.icon(
                              icon: const Icon(Icons.gavel, size: 16),
                              label: const Text("Moderate"),
                              style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red.shade50,
                                  foregroundColor: Colors.red,
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8)
                              ),
                              onPressed: () => _showMultiActionDialog(context, doc, adminController),
                            )
                                : IconButton(
                              icon: const Icon(Icons.check_circle_outline, color: Colors.green),
                              tooltip: "Mark Resolved",
                              onPressed: () async {
                                await adminController.resolveReport(doc.id);
                                _refreshList();
                              },
                            )
                        ),
                      ]);
                    }).toList(),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showMultiActionDialog(BuildContext context, DocumentSnapshot reportDoc, AdminController controller) {
    final data = reportDoc.data() as Map<String, dynamic>;

    final String targetId = data['targetId'] ?? '';
    final String offenderId = data['reportedId'] ?? '';

    bool deleteComment = false;
    bool suspendUser = false;
    bool deductMerit = false;
    bool isProcessing = false;

    showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) {
          return StatefulBuilder(
            builder: (context, setState) {
              return AlertDialog(
                title: const Text("Moderation Console"),
                content: SizedBox(
                  width: 400,
                  child: isProcessing
                      ? const Center(child: CircularProgressIndicator())
                      : Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(8)),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          const Text("Reported Content Snapshot:", style: TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Text(data['contentSnapshot'] ?? "[Unavailable]", style: const TextStyle(fontStyle: FontStyle.italic)),
                        ]),
                      ),
                      const SizedBox(height: 20),
                      const Text("Select Actions:", style: TextStyle(fontWeight: FontWeight.bold)),

                      CheckboxListTile(
                        title: const Text("Delete Comment"),
                        subtitle: targetId.isEmpty ? const Text("No Target ID found", style: TextStyle(color: Colors.red, fontSize: 10)) : null,
                        value: deleteComment,
                        activeColor: Colors.red,
                        enabled: targetId.isNotEmpty,
                        onChanged: (v) => setState(() => deleteComment = v!),
                      ),
                      CheckboxListTile(
                        title: const Text("Deduct Merit (-10)"),
                        value: deductMerit,
                        activeColor: Colors.orange,
                        enabled: offenderId.isNotEmpty,
                        onChanged: (v) => setState(() => deductMerit = v!),
                      ),
                      CheckboxListTile(
                        title: const Text("Suspend User"),
                        value: suspendUser,
                        activeColor: Colors.red[900],
                        enabled: offenderId.isNotEmpty,
                        onChanged: (v) => setState(() => suspendUser = v!),
                      ),
                    ],
                  ),
                ),
                actions: isProcessing ? [] : [
                  TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                    onPressed: () async {
                      setState(() => isProcessing = true);

                      bool success = await controller.moderateContent(
                        reportId: reportDoc.id,
                        targetId: targetId,
                        offenderId: offenderId,
                        deleteContent: deleteComment,
                        suspendUser: suspendUser,
                        deductMerit: deductMerit,
                      );

                      Navigator.pop(ctx);

                      if (success) {
                        _refreshList();
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                              content: Text("Action Confirmed. Report moved to History."),
                              backgroundColor: Colors.green
                          ));
                        }
                      } else {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                              content: Text("Action Failed. Check console logs."),
                              backgroundColor: Colors.red
                          ));
                        }
                      }
                    },
                    child: const Text("Confirm & Execute"),
                  ),
                ],
              );
            },
          );
        }
    );
  }
}