import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../../core/admin_theme.dart';
import '../../../controllers/admin_controller.dart';
import '../../widgets/co2_tree_widget.dart';
import '../../widgets/custom_date_pickers.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  DateTime _selectedDate = DateTime.now();
  String _range = "Monthly";
  Timer? _cleanupTimer;
  bool _isCleaning = false;

  @override
  void initState() {
    super.initState();
    _runDatabaseCleanup();
    _cleanupTimer = Timer.periodic(const Duration(minutes: 5), (timer) { _runDatabaseCleanup(); });
  }

  @override
  void dispose() { _cleanupTimer?.cancel(); super.dispose(); }

  Future<void> _runDatabaseCleanup() async {
    if (_isCleaning || !mounted) return;
    setState(() => _isCleaning = true);
    try {
      final now = DateTime.now();
      final firestore = FirebaseFirestore.instance;
      final snapshot = await firestore.collection('listings').where('status', isEqualTo: 'available').get();
      final WriteBatch batch = firestore.batch();
      int expiredCount = 0;

      for (var doc in snapshot.docs) {
        final data = doc.data();
        if (data['pickupEndTime'] != null) {
          final Timestamp endTs = data['pickupEndTime'];
          if (endTs.toDate().isBefore(now)) {
            batch.update(doc.reference, {'status': 'expired'});
            expiredCount++;
          }
        }
      }
      if (expiredCount > 0) await batch.commit();
    } catch (e) {
      print("Cleanup Error: $e");
    } finally {
      if(mounted) setState(() => _isCleaning = false);
    }
  }

  Future<void> _pickDate() async {
    DateTime? picked;
    if (_range == "Monthly") {
      picked = await showDialog(context: context, builder: (c) => MonthPickerDialog(initialDate: _selectedDate));
    } else {
      picked = await showDialog(context: context, builder: (c) => WeeklyDatePickerDialog(initialDate: _selectedDate));
    }
    if (picked != null) setState(() => _selectedDate = picked!);
  }

  @override
  Widget build(BuildContext context) {
    final controller = Provider.of<AdminController>(context);
    String dateLabel = "";

    if (_range == "Monthly") {
      dateLabel = DateFormat('MMMM yyyy').format(_selectedDate);
    } else {
      DateTime start = _selectedDate.subtract(Duration(days: _selectedDate.weekday - 1));
      DateTime end = start.add(const Duration(days: 6));
      dateLabel = "${DateFormat('MMM dd').format(start)} - ${DateFormat('MMM dd').format(end)}";
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Executive Dashboard", style: AdminTheme.headerStyle),
          const SizedBox(height: 20),

          LayoutBuilder(builder: (context, constraints) {
            final isWide = constraints.maxWidth > 1200;

            final statsGrid = GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              // Adjust ratio dynamically to prevent squishing on different screens
              childAspectRatio: isWide ? 2.2 : 1.8,
              children: [
                _StatCard(title: "Total Users", icon: FontAwesomeIcons.users, color: Colors.orange, stream: FirebaseFirestore.instance.collection('users').snapshots(), onTap: () => controller.navigateTo(AdminPage.users)),
                _ActiveListingsCard(onTap: () => controller.navigateTo(AdminPage.listings)),
                _StatCard(title: "Reports", icon: FontAwesomeIcons.flag, color: Colors.red, stream: FirebaseFirestore.instance.collection('reports').where('status', isEqualTo: 'pending').snapshots(), onTap: () => controller.navigateTo(AdminPage.reports)),
                _StatCard(title: "Meals Saved", icon: FontAwesomeIcons.utensils, color: Colors.green, stream: FirebaseFirestore.instance.collection('reservations').where('status', isEqualTo: 'picked_up').snapshots(), onTap: () => controller.navigateTo(AdminPage.detailedReports, tabIndex: 1)),
              ],
            );

            // Green Impact Tree
            final treeWidget = InkWell(
              onTap: () => controller.navigateTo(AdminPage.detailedReports, tabIndex: 0),
              child: SizedBox(
                height: 250,
                child: _buildTreeStream(),
              ),
            );

            // User Demographics Pie
            final pieWidget = SizedBox(
              height: 250,
              child: _buildUserPieChart(),
            );

            if (isWide) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start, // Allows children to dictate height naturally
                children: [
                  Expanded(flex: 3, child: statsGrid),
                  const SizedBox(width: 16),
                  Expanded(flex: 2, child: treeWidget),
                  const SizedBox(width: 16),
                  Expanded(flex: 2, child: pieWidget),
                ],
              );
            } else {
              return Column(
                children: [
                  statsGrid, // Removed the strict 240 height restriction!
                  const SizedBox(height: 16),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: treeWidget),
                      const SizedBox(width: 16),
                      Expanded(child: pieWidget),
                    ],
                  )
                ],
              );
            }
          }),

          const SizedBox(height: 32),

          Container(
            padding: const EdgeInsets.all(24),
            decoration: AdminTheme.cardDecoration,
            height: 600,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Traffic Analysis", style: AdminTheme.subHeaderStyle),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade300)),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _range,
                          items: ["Monthly", "Weekly"].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                          onChanged: (val) { if(val!=null) setState(() => _range = val); },
                        ),
                      ),
                    ),
                    InkWell(
                      onTap: _pickDate,
                      child: Padding(padding: const EdgeInsets.all(8.0), child: Row(children: [const Icon(Icons.calendar_month, size: 16), const SizedBox(width: 8), Text(dateLabel, style: const TextStyle(fontWeight: FontWeight.bold, color: AdminTheme.merchantOrange)), const Icon(Icons.arrow_drop_down, color: AdminTheme.merchantOrange)])),
                    ),
                  ],
                ),
                const SizedBox(height: 30),
                Expanded(child: _buildTrafficChart(dateLabel)),
                const Divider(height: 20),
                _buildTrafficExplanation(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrafficChart(String label) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('reservations').snapshots(),
      builder: (context, snapshot) {
        if(!snapshot.hasData) return const Center(child: CircularProgressIndicator());

        Map<int, double> buckets = {};
        int maxKey = _range == "Monthly" ? 5 : 7;
        for(int i=1; i<=maxKey; i++) buckets[i] = 0;
        double maxY = 0;
        DateTime weekStart = _selectedDate.subtract(Duration(days: _selectedDate.weekday - 1));

        for(var doc in snapshot.data!.docs) {
          final data = doc.data() as Map<String, dynamic>;
          if(data['reservedAt'] != null) {
            final date = (data['reservedAt'] as Timestamp).toDate();
            bool match = false;
            int key = 0;

            if(_range == "Monthly") {
              if(date.year == _selectedDate.year && date.month == _selectedDate.month) {
                key = ((date.day - 1) / 7).floor() + 1;
                if(key > 5) key = 5; match = true;
              }
            } else {
              DateTime weekEnd = weekStart.add(const Duration(days: 6, hours: 23));
              if (date.isAfter(weekStart.subtract(const Duration(seconds: 1))) && date.isBefore(weekEnd)) {
                key = date.weekday; match = true;
              }
            }
            if(match) { buckets[key] = (buckets[key] ?? 0) + 1; if(buckets[key]! > maxY) maxY = buckets[key]!; }
          }
        }
        if(maxY == 0) maxY = 5;

        return BarChart(BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: maxY * 1.2,
          barTouchData: BarTouchData(touchTooltipData: BarTouchTooltipData(getTooltipColor: (_) => AdminTheme.midnightBlack)),
          titlesData: FlTitlesData(
            show: true,
            bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, getTitlesWidget: (val, _) {
              if (_range == "Monthly") return Text("Wk ${val.toInt()}", style: const TextStyle(fontSize: 10));
              const days = ["M","T","W","T","F","S","S"];
              if(val>=1 && val<=7) return Text(days[val.toInt()-1], style: const TextStyle(fontSize: 10));
              return const SizedBox();
            })),

            leftTitles: AxisTitles(sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 30,
                interval: 1,
                getTitlesWidget: (val, _) {
                  return Text(val.toInt().toString(), style: const TextStyle(fontSize: 10));
                }
            )),

            topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              horizontalInterval: 1
          ),
          borderData: FlBorderData(show: false),
          barGroups: buckets.entries.map((e) => BarChartGroupData(x: e.key, barRods: [BarChartRodData(toY: e.value, color: AdminTheme.merchantOrange, width: 16, borderRadius: BorderRadius.circular(2))])).toList(),
        ));
      },
    );
  }

  Widget _buildTrafficExplanation() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text("Interpretation:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
      const SizedBox(height: 4),
      Text(_range == "Monthly" ? "Aggregates traffic by weeks. Identifies which weeks performed best." : "Shows daily traffic for the specific week selected.", style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
    ]);
  }

  Widget _buildTreeStream() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('reservations').where('status', isEqualTo: 'picked_up').snapshots(),
      builder: (context, snapshot) {
        double totalCo2 = 0;
        if(snapshot.hasData) {
          for(var doc in snapshot.data!.docs) {
            final data = doc.data() as Map<String, dynamic>;
            if (data.containsKey('co2Saved')) totalCo2 += (data['co2Saved'] ?? 0).toDouble(); else totalCo2 += 2.5;
          }
        }
        return Co2TreeWidget(totalCo2Saved: totalCo2);
      },
    );
  }

  Widget _buildUserPieChart() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AdminTheme.cardDecoration,
      child: Column(
        children: [
          Text("User Demographics", style: AdminTheme.subHeaderStyle),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('users').snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                int merchants = 0; int students = 0;
                for (var doc in snapshot.data!.docs) {
                  final role = (doc.data() as Map<String, dynamic>)['role'].toString().toLowerCase();
                  if (role == 'merchant') merchants++; else students++;
                }
                if (merchants == 0 && students == 0) return const Center(child: Text("No users found."));

                return Stack(
                  alignment: Alignment.center,
                  children: [
                    PieChart(PieChartData(
                      sectionsSpace: 2, centerSpaceRadius: 40,
                      sections: [
                        PieChartSectionData(color: AdminTheme.merchantOrange, value: merchants.toDouble(), title: '${((merchants/(merchants+students))*100).toStringAsFixed(0)}%', radius: 40, titleStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white)),
                        PieChartSectionData(color: AdminTheme.studentGreen, value: students.toDouble(), title: '${((students/(merchants+students))*100).toStringAsFixed(0)}%', radius: 40, titleStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white)),
                      ],
                    )),
                    Column(mainAxisSize: MainAxisSize.min, children: [Text("${merchants + students}", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)), const Text("Users", style: TextStyle(fontSize: 10, color: Colors.grey))])
                  ],
                );
              },
            ),
          ),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            _legendItem(AdminTheme.merchantOrange, "Merchants"),
            const SizedBox(width: 12),
            _legendItem(AdminTheme.studentGreen, "Students")
          ])
        ],
      ),
    );
  }

  Widget _legendItem(Color color, String text) => Row(children: [Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)), const SizedBox(width: 6), Text(text, style: const TextStyle(fontSize: 11))]);
}

class _StatCard extends StatelessWidget {
  final String title; final IconData icon; final Color color; final Stream<QuerySnapshot> stream; final VoidCallback onTap;
  const _StatCard({required this.title, required this.icon, required this.color, required this.stream, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap, borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: AdminTheme.cardDecoration,
        child: StreamBuilder<QuerySnapshot>(
          stream: stream,
          builder: (context, snapshot) {
            String count = "..."; if (snapshot.hasData) count = snapshot.data!.docs.length.toString();
            return Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(icon, color: color, size: 20), const SizedBox(height: 8), Text(count, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)), Text(title, style: const TextStyle(fontSize: 11, color: Colors.grey))]);
          },
        ),
      ),
    );
  }
}

class _ActiveListingsCard extends StatelessWidget {
  final VoidCallback onTap;
  const _ActiveListingsCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap, borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: AdminTheme.cardDecoration,
        child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('listings').where('status', isEqualTo: 'available').snapshots(),
          builder: (context, snapshot) {
            String count = "...";
            if (snapshot.hasData) {
              final now = DateTime.now();
              final activeDocs = snapshot.data!.docs.where((doc) {
                final data = doc.data() as Map<String, dynamic>;
                if (data['pickupEndTime'] == null) return false;
                return (data['pickupEndTime'] as Timestamp).toDate().isAfter(now);
              }).toList();
              count = activeDocs.length.toString();
            }
            return Column(mainAxisAlignment: MainAxisAlignment.center, children: [const Icon(FontAwesomeIcons.burger, color: Colors.blue, size: 20), const SizedBox(height: 8), Text(count, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)), const Text("Active Listings", style: TextStyle(fontSize: 11, color: Colors.grey))]);
          },
        ),
      ),
    );
  }
}