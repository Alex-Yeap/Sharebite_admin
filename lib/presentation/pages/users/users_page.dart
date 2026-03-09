import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:data_table_2/data_table_2.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';
import 'package:csv/csv.dart';
import 'package:universal_html/html.dart' as html;

import '../../../controllers/admin_controller.dart';
import '../../../core/admin_theme.dart';

class UsersPage extends StatefulWidget {
  const UsersPage({super.key});

  @override
  State<UsersPage> createState() => _UsersPageState();
}

class _UsersPageState extends State<UsersPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _searchQuery = "";

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  // --- CSV EXPORT LOGIC ---
  Future<void> _exportToCsv(String role) async {
    final snapshot = await FirebaseFirestore.instance.collection('users').where('role', isEqualTo: role).get();

    List<List<dynamic>> rows = [];
    rows.add(["ID", "Name/Business", "Email", "Role", "Joined Date", "Merit Score", "Is Suspended"]);

    for (var doc in snapshot.docs) {
      final data = doc.data();
      final name = role == 'merchant' ? data['businessName'] : data['name'];
      final joined = data['createdAt'] != null ? DateFormat('yyyy-MM-dd').format((data['createdAt'] as Timestamp).toDate()) : 'Unknown';

      rows.add([
        doc.id,
        name ?? "Unknown",
        data['email'] ?? "",
        data['role'] ?? "",
        joined,
        data['meritScore'] ?? (role == 'student' ? 100 : 'N/A'),
        data['isSuspended'] ?? false,
      ]);
    }

    String csv = const ListToCsvConverter().convert(rows);
    final bytes = utf8.encode(csv);
    final blob = html.Blob([bytes]);
    final url = html.Url.createObjectUrlFromBlob(blob);
    final anchor = html.AnchorElement(href: url)
      ..setAttribute("download", "sharebite_${role}s_export.csv")
      ..click();
    html.Url.revokeObjectUrl(url);
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1400),
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("User Database", style: AdminTheme.headerStyle),
                  Row(
                    children: [
                      SizedBox(
                        width: 250,
                        child: TextField(
                          decoration: InputDecoration(
                            hintText: "Search name, email...",
                            prefixIcon: const Icon(Icons.search, color: Colors.grey),
                            filled: true, fillColor: Colors.white,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                          ),
                          onChanged: (val) => setState(() => _searchQuery = val.toLowerCase()),
                        ),
                      ),
                      const SizedBox(width: 16),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.download, size: 16),
                        label: const Text("Export CSV"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AdminTheme.midnightBlack,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                        ),
                        onPressed: () {
                          final currentRole = _tabController.index == 0 ? "student" : "merchant";
                          _exportToCsv(currentRole);
                        },
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 24),

              Container(
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                child: TabBar(
                  controller: _tabController,
                  labelColor: AdminTheme.midnightBlack,
                  indicatorColor: AdminTheme.merchantOrange,
                  tabs: const [
                    Tab(text: "Students", icon: Icon(FontAwesomeIcons.userGraduate)),
                    Tab(text: "Merchants", icon: Icon(FontAwesomeIcons.store)),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildTable("student"),
                    _buildTable("merchant"),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTable(String targetRole) {
    final controller = Provider.of<AdminController>(context);

    return Container(
      decoration: AdminTheme.cardDecoration,
      padding: const EdgeInsets.all(16),
      child: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('users').snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

          final docs = snapshot.data!.docs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final role = (data['role'] ?? 'student').toString().toLowerCase();
            if (role != targetRole) return false;
            if (data['isSuspended'] == true) return false;

            final name = (data['businessName'] ?? data['name'] ?? '').toString().toLowerCase();
            final email = (data['email'] ?? '').toString().toLowerCase();
            return _searchQuery.isEmpty || name.contains(_searchQuery) || email.contains(_searchQuery);
          }).toList();

          if (docs.isEmpty) return const Center(child: Text("No users found."));

          return DataTable2(
            columnSpacing: 12,
            horizontalMargin: 12,
            minWidth: 900,
            headingTextStyle: AdminTheme.tableHeader,
            columns: [
              const DataColumn2(label: Text('Identity'), size: ColumnSize.L),
              const DataColumn(label: Text('Email')),
              const DataColumn(label: Text('Joined')),
              if (targetRole == 'student') const DataColumn(label: Text('Merit Score')),
              const DataColumn(label: Text('Status')),
              const DataColumn(label: Text('Actions')),
            ],
            rows: docs.map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              final name = targetRole == 'merchant' ? data['businessName'] : data['name'];
              final joined = data['createdAt'] != null ? DateFormat('yyyy-MM-dd').format((data['createdAt'] as Timestamp).toDate()) : '-';
              final score = data['meritScore'] ?? 100;

              return DataRow(cells: [
                DataCell(Text(name ?? "Unknown", style: const TextStyle(fontWeight: FontWeight.bold))),
                DataCell(Text(data['email'] ?? '-')),
                DataCell(Text(joined)),

                if (targetRole == 'student')
                  DataCell(Text("$score", style: TextStyle(color: score < 40 ? Colors.red : Colors.green, fontWeight: FontWeight.bold))),

                DataCell(Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: Colors.green.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
                  child: const Text("Active", style: TextStyle(color: Colors.green, fontSize: 11, fontWeight: FontWeight.bold)),
                )),

                DataCell(
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // MERIT MANAGEMENT BUTTON (Students Only)
                      if (targetRole == 'student')
                        IconButton(
                          icon: const Icon(Icons.star_half, color: Colors.amber),
                          tooltip: "Manage Merit Points",
                          onPressed: () => _showMeritDialog(context, doc.id, name, controller),
                        ),

                      IconButton(
                        icon: const Icon(Icons.block, color: Colors.red),
                        tooltip: "Suspend Account",
                        onPressed: () => _showBanDialog(context, doc.id, name, controller),
                      ),
                    ],
                  ),
                ),
              ]);
            }).toList(),
          );
        },
      ),
    );
  }

  void _showBanDialog(BuildContext context, String uid, String? name, AdminController controller) {
    final txt = TextEditingController();
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: Text("Suspend $name?"),
      content: TextField(controller: txt, decoration: const InputDecoration(labelText: "Reason for suspension")),
      actions: [
        TextButton(onPressed: ()=>Navigator.pop(ctx), child: const Text("Cancel")),
        ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: (){ controller.banUser(uid, txt.text); Navigator.pop(ctx); },
            child: const Text("Suspend User")
        )
      ],
    ));
  }

  // --- MANUAL MERIT POINT DIALOG ---
  void _showMeritDialog(BuildContext context, String uid, String? name, AdminController controller) {
    final pointsCtrl = TextEditingController();
    final reasonCtrl = TextEditingController();

    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: Text("Manage Merit for $name"),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text("Use negative numbers to deduct (e.g. -10), or positive to reward (e.g. 5).", style: TextStyle(fontSize: 12, color: Colors.grey)),
          const SizedBox(height: 16),
          TextField(
              controller: pointsCtrl,
              keyboardType: const TextInputType.numberWithOptions(signed: true),
              decoration: const InputDecoration(labelText: "Points Amount", border: OutlineInputBorder())
          ),
          const SizedBox(height: 16),
          TextField(
              controller: reasonCtrl,
              decoration: const InputDecoration(labelText: "Reason", border: OutlineInputBorder())
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: ()=>Navigator.pop(ctx), child: const Text("Cancel")),
        ElevatedButton(
            onPressed: () async {
              final points = int.tryParse(pointsCtrl.text);
              final reason = reasonCtrl.text.trim();

              if (points != null && reason.isNotEmpty) {
                Navigator.pop(ctx);
                bool success = await controller.adjustMeritPoints(uid, points, reason);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(success ? "Points updated successfully." : "Failed to update points."),
                        backgroundColor: success ? Colors.green : Colors.red,
                      )
                  );
                }
              }
            },
            child: const Text("Apply Changes")
        )
      ],
    ));
  }
}