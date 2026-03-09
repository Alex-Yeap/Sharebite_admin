import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:data_table_2/data_table_2.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';
import '../../../controllers/admin_controller.dart';
import '../../../core/admin_theme.dart';

class BannedUsersPage extends StatefulWidget {
  const BannedUsersPage({super.key});

  @override
  State<BannedUsersPage> createState() => _BannedUsersPageState();
}

class _BannedUsersPageState extends State<BannedUsersPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Suspended Accounts", style: AdminTheme.headerStyle.copyWith(color: AdminTheme.dangerRed)),
          const SizedBox(height: 24),

          Container(
            height: 60,
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
            child: TabBar(
              controller: _tabController,
              labelColor: Colors.red,
              unselectedLabelColor: Colors.grey,
              indicatorColor: Colors.red,
              tabs: [
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(FontAwesomeIcons.userXmark, size: 16), SizedBox(width: 8), Text("Suspended Students")]),
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(FontAwesomeIcons.shopLock, size: 16), SizedBox(width: 8), Text("Suspended Merchants")]),
              ],
            ),
          ),
          const SizedBox(height: 20),

          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildBannedTable("student"),
                _buildBannedTable("merchant"),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBannedTable(String role) {
    final controller = Provider.of<AdminController>(context);

    return Container(
      decoration: AdminTheme.cardDecoration,
      padding: const EdgeInsets.all(16),
      child: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('users').where('isSuspended', isEqualTo: true).where('role', isEqualTo: role).snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final docs = snapshot.data!.docs;

          if (docs.isEmpty) return const Center(child: Text("No suspended accounts in this category."));

          return DataTable2(
            columnSpacing: 12, horizontalMargin: 12, minWidth: 800,
            headingTextStyle: AdminTheme.tableHeader,
            columns: const [
              DataColumn2(label: Text('Identity'), size: ColumnSize.M),
              DataColumn2(label: Text('Ban Reason'), size: ColumnSize.L),
              DataColumn(label: Text('Banned Date')),
              DataColumn(label: Text('Actions')),
            ],
            rows: docs.map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              final name = role == 'merchant' ? data['businessName'] : data['name'];
              final date = data['bannedAt'] != null ? DateFormat('MMM dd, yyyy').format((data['bannedAt'] as Timestamp).toDate()) : '-';

              return DataRow(cells: [
                DataCell(Text(name ?? "Unknown", style: const TextStyle(fontWeight: FontWeight.bold))),
                DataCell(Text(data['banReason'] ?? "Policy Violation", style: const TextStyle(color: Colors.red))),
                DataCell(Text(date)),
                DataCell(
                  ElevatedButton.icon(
                    icon: const Icon(Icons.lock_open, size: 16),
                    label: const Text("Unban"),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                    onPressed: () {
                      showDialog(context: context, builder: (ctx) => AlertDialog(
                        title: const Text("Restore Account?"),
                        content: Text("This will allow $name to log in again."),
                        actions: [TextButton(onPressed: ()=>Navigator.pop(ctx), child: const Text("Cancel")), ElevatedButton(onPressed: (){ controller.unbanUser(doc.id); Navigator.pop(ctx); }, child: const Text("Restore Access"))],
                      ));
                    },
                  ),
                ),
              ]);
            }).toList(),
          );
        },
      ),
    );
  }
}