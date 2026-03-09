import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../../core/admin_theme.dart';
import '../../../controllers/admin_controller.dart';
import '../../widgets/custom_date_pickers.dart';
import '../../widgets/co2_tree_widget.dart';

class DetailedReportPage extends StatefulWidget {
  const DetailedReportPage({super.key});

  @override
  State<DetailedReportPage> createState() => _DetailedReportPageState();
}

class _DetailedReportPageState extends State<DetailedReportPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  DateTime _selectedDate = DateTime.now();
  String _range = "Yearly";

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final controller = Provider.of<AdminController>(context, listen: false);
      if (controller.detailedReportTabIndex != 0) {
        _tabController.animateTo(controller.detailedReportTabIndex);
      }
    });
  }

  Future<void> _pickDate() async {
    DateTime? picked;
    if (_range == "Yearly") {
      picked = await showDialog(context: context, builder: (c) => YearPickerDialog(initialDate: _selectedDate));
    } else if (_range == "Monthly") {
      picked = await showDialog(context: context, builder: (c) => MonthPickerDialog(initialDate: _selectedDate));
    } else {
      picked = await showDialog(context: context, builder: (c) => WeeklyDatePickerDialog(initialDate: _selectedDate));
    }
    if (picked != null) setState(() => _selectedDate = picked!);
  }

  //pdf print
  Future<void> _printReport(String title, String explanation, String interpretation, List<Map<String, dynamic>> dataPoints) async {
    if (dataPoints.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("No data available to export.")));
      return;
    }

    final pdf = pw.Document();

    final fontRegular = await PdfGoogleFonts.openSansRegular();
    final fontBold = await PdfGoogleFonts.openSansBold();
    final fontItalic = await PdfGoogleFonts.openSansItalic();

    final bool isEfficiency = dataPoints.first.containsKey('posted');
    double totalMain = 0;
    double totalSecondary = 0;
    double peakValue = 0;
    int count = dataPoints.length;

    for (var e in dataPoints) {
      if (isEfficiency) {
        double rescued = (e['rescued'] as int).toDouble();
        double posted = (e['posted'] as int).toDouble();
        totalMain += rescued;
        totalSecondary += posted;
        if (rescued > peakValue) peakValue = rescued;
        if (posted > peakValue) peakValue = posted;
      } else {
        double val = (e['value'] as double);
        totalMain += val;
        if (val > peakValue) peakValue = val;
      }
    }

    double average = count > 0 ? totalMain / count : 0;
    String primaryUnit = isEfficiency ? "Items" : "kg";
    String mainTotalStr = isEfficiency ? totalMain.toInt().toString() : "${totalMain.toStringAsFixed(1)} kg";

    //page1
    pdf.addPage(pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (ctx) {
          return pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Header(level: 0, child: pw.Text("ShareBite Analytics: $title", style: pw.TextStyle(font: fontBold, fontSize: 18))),
            pw.Text("Period: $_range View", style: pw.TextStyle(font: fontRegular, fontSize: 10)),
            pw.Text("Date Reference: ${DateFormat('yyyy-MM-dd').format(_selectedDate)}", style: pw.TextStyle(font: fontRegular, fontSize: 10, color: PdfColors.grey700)),
            pw.SizedBox(height: 20),

            pw.Container(
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey300), borderRadius: pw.BorderRadius.circular(4)),
                child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                  pw.Text("Report Purpose:", style: pw.TextStyle(font: fontBold, fontSize: 10)),
                  pw.Text(explanation, style: pw.TextStyle(font: fontRegular, fontSize: 10)),
                  pw.SizedBox(height: 5),
                  pw.Text("Interpretation:", style: pw.TextStyle(font: fontBold, fontSize: 10)),
                  pw.Text(interpretation, style: pw.TextStyle(font: fontRegular, fontSize: 10, color: PdfColors.blue900)),
                ])
            ),

            pw.SizedBox(height: 20),

            pw.Table.fromTextArray(
              context: ctx,
              headerStyle: pw.TextStyle(font: fontBold, color: PdfColors.white),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.black),
              cellStyle: pw.TextStyle(font: fontRegular, fontSize: 10),
              headers: isEfficiency
                  ? ['Time Period', 'Posted', 'Rescued', 'Efficiency (%)']
                  : ['Time Period', 'Value'],
              data: dataPoints.map((e) {
                String label = e['label'];
                if (_range == "Monthly" && e.containsKey('x')) {
                  label = "$label (${_getDateRangeForWeek(e['x'])})";
                }

                if (isEfficiency) {
                  return [
                    label,
                    e['posted'].toString(),
                    e['rescued'].toString(),
                    "${((e['rescued']/(e['posted']==0?1:e['posted']))*100).toStringAsFixed(1)}%"
                  ];
                } else {
                  return [label, (e['value'] as double).toStringAsFixed(2)];
                }
              }).toList(),
            )
          ]);
        }
    ));

    //page2
    pdf.addPage(pw.Page(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.symmetric(vertical: 40, horizontal: 60),
        build: (ctx) {
          return pw.Column(children: [
            pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                    pw.Text("$title Analysis ${_selectedDate.year}", style: pw.TextStyle(font: fontBold, fontSize: 24, color: PdfColors.blueGrey900)),
                    pw.Text("$_range Comparison | ${DateFormat('MM/dd/yyyy').format(_selectedDate)}", style: pw.TextStyle(font: fontRegular, fontSize: 10, color: PdfColors.grey600)),
                  ]),
                  pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
                    pw.Text("Total ${isEfficiency ? 'Rescued' : 'Impact'}", style: pw.TextStyle(font: fontRegular, fontSize: 10, color: PdfColors.grey600)),
                    pw.Text(mainTotalStr, style: pw.TextStyle(font: fontBold, fontSize: 24, color: PdfColors.blueGrey900)),
                  ]),
                ]
            ),
            pw.Divider(color: PdfColors.grey300),
            pw.SizedBox(height: 10),

            pw.Expanded(
                child: pw.Container(
                    padding: const pw.EdgeInsets.all(10),
                    decoration: pw.BoxDecoration(
                        color: PdfColors.white,
                        border: pw.Border.all(color: PdfColors.grey200),
                        borderRadius: pw.BorderRadius.circular(4)
                    ),
                    child: pw.Column(children: [
                      pw.Row(mainAxisAlignment: pw.MainAxisAlignment.end, children: [
                        if (isEfficiency) ...[
                          _buildPdfLegendBox(PdfColors.grey400, "Posted"),
                          pw.SizedBox(width: 10),
                        ],
                        _buildPdfLegendBox(isEfficiency ? PdfColors.indigo : PdfColors.indigo, isEfficiency ? "Rescued" : "Value"),
                      ]),
                      pw.SizedBox(height: 10),
                      pw.Expanded(
                          child: _buildProfessionalPdfChart(dataPoints, isEfficiency, peakValue, fontRegular, fontBold)
                      ),
                    ])
                )
            ),

            pw.SizedBox(height: 15),

            pw.Container(
                width: double.infinity,
                child: _buildPdfStatBox("Performance Overview", [
                  "Peak Period Value: ${peakValue.toStringAsFixed(1)} $primaryUnit",
                  "Average per Period: ${average.toStringAsFixed(1)} $primaryUnit",
                  if(isEfficiency) "Total Efficiency Rate: ${totalSecondary==0?0:((totalMain/totalSecondary)*100).toStringAsFixed(1)}%",
                  "Data Points Analyzed: $count periods",
                  "Trend Direction: ${totalMain > 0 ? 'Active' : 'No Data'}"
                ], fontBold, fontRegular)
            )
          ]);
        }
    ));

    await Printing.layoutPdf(onLayout: (f) => pdf.save());
  }

  pw.Widget _buildProfessionalPdfChart(List<Map<String, dynamic>> data, bool isEfficiency, double maxY, pw.Font font, pw.Font fontBold) {
    if (maxY == 0) maxY = 1;

    double interval = _calculateInterval(maxY);
    int gridLines = (maxY / interval).ceil();
    if(gridLines < 4) gridLines = 4;
    double adjustedMaxY = gridLines * interval;

    return pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Column(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              ...List.generate(gridLines + 1, (index) {
                double value = adjustedMaxY - (index * interval);
                return pw.Text(value.toInt().toString(), style: pw.TextStyle(color: PdfColors.grey600, fontSize: 9, font: font));
              }),
              pw.SizedBox(height: 10),
            ],
          ),
          pw.SizedBox(width: 5),

          pw.Expanded(
              child: pw.Column(
                  children: [
                    pw.Expanded(
                      child: pw.Stack(
                          alignment: pw.Alignment.bottomLeft,
                          children: [
                            pw.Column(
                                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                                children: List.generate(gridLines + 1, (index) =>
                                    _buildDottedLine()
                                )
                            ),

                            pw.Row(
                              mainAxisAlignment: pw.MainAxisAlignment.spaceEvenly,
                              crossAxisAlignment: pw.CrossAxisAlignment.end,
                              children: data.map((e) {
                                return pw.Expanded(
                                  child: _buildBarColumn(e, isEfficiency, adjustedMaxY, fontBold),
                                );
                              }).toList(),
                            ),

                            pw.Container(width: 1, height: double.infinity, color: PdfColors.grey800),
                          ]
                      ),
                    ),

                    pw.Container(height: 1, width: double.infinity, color: PdfColors.grey800),
                    pw.SizedBox(height: 4),

                    pw.Row(
                      children: data.map((e) {
                        String label = e['label'].toString().replaceAll("Wk", "W");
                        if(label.length > 3 && !_range.contains("Year")) label = label.substring(0,3);
                        return pw.Expanded(
                          child: pw.Center(
                              child: pw.Text(label, style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey800))
                          ),
                        );
                      }).toList(),
                    )
                  ]
              )
          ),
        ]
    );
  }

  pw.Widget _buildBarColumn(Map<String, dynamic> e, bool isEfficiency, double adjustedMaxY, pw.Font fontBold) {
    if (isEfficiency) {
      double postedVal = (e['posted'] as int).toDouble();
      double rescuedVal = (e['rescued'] as int).toDouble();
      double postedH = (postedVal / adjustedMaxY) * 200;
      double rescuedH = (rescuedVal / adjustedMaxY) * 200;

      return pw.Column(mainAxisAlignment: pw.MainAxisAlignment.end, children: [
        pw.Text(
            "${rescuedVal.toInt()}/${postedVal.toInt()}",
            style: pw.TextStyle(fontSize: 8, font: fontBold, color: PdfColors.black)
        ),
        pw.SizedBox(height: 2),
        pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.center,
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              _buildBar(postedH, PdfColors.grey400, 16),
              pw.SizedBox(width: 2),
              _buildBar(rescuedH, PdfColors.indigo, 16),
            ]
        ),
      ]);
    } else {
      double val = (e['value'] as double);
      double valH = (val / adjustedMaxY) * 200;

      return pw.Column(mainAxisAlignment: pw.MainAxisAlignment.end, children: [
        pw.Text(val.toStringAsFixed(1), style: pw.TextStyle(fontSize: 8, font: fontBold, color: PdfColors.black)),
        pw.SizedBox(height: 2),
        _buildBar(valH, PdfColors.indigo, 32),
      ]);
    }
  }

  pw.Widget _buildBar(double height, PdfColor color, double width) {
    if (height < 0) height = 0;
    return pw.Container(width: width, height: height, color: color);
  }

  double _calculateInterval(double max) {
    if (max <= 10) return 2;
    if (max <= 25) return 5;
    if (max <= 50) return 10;
    if (max <= 100) return 20;
    if (max <= 250) return 50;
    if (max <= 500) return 100;
    if (max <= 1000) return 200;
    return max / 5;
  }

  pw.Widget _buildDottedLine() {
    return pw.Row(
        children: List.generate(60, (i) =>
            pw.Expanded(child: pw.Container(
                height: 0.5,
                color: i % 2 == 0 ? PdfColors.grey400 : PdfColors.white
            ))
        )
    );
  }

  pw.Widget _buildPdfLegendBox(PdfColor color, String text) {
    return pw.Row(children: [
      pw.Container(width: 12, height: 12, color: color),
      pw.SizedBox(width: 5),
      pw.Text(text, style: const pw.TextStyle(fontSize: 11)),
    ]);
  }

  pw.Widget _buildPdfStatBox(String title, List<String> lines, pw.Font fontBold, pw.Font fontRegular) {
    return pw.Container(
        padding: const pw.EdgeInsets.all(12),
        decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey300), borderRadius: pw.BorderRadius.circular(4), color: PdfColors.grey50),
        child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Text(title, style: pw.TextStyle(font: fontBold, fontSize: 12, color: PdfColors.blueGrey800)),
          pw.Divider(color: PdfColors.grey300),
          pw.SizedBox(height: 5),
          pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: lines.map((l) =>
              pw.Row(children: [
                pw.Container(
                    width: 4,
                    height: 4,
                    decoration: const pw.BoxDecoration(color: PdfColors.black, shape: pw.BoxShape.circle)
                ),
                pw.SizedBox(width: 4),
                pw.Text(l, style: pw.TextStyle(fontSize: 10, font: fontRegular))
              ])
              ).toList()
          )
        ])
    );
  }

  @override
  Widget build(BuildContext context) {
    String dateLabel = "";
    if (_range == "Yearly") dateLabel = DateFormat('yyyy').format(_selectedDate);
    else if (_range == "Monthly") dateLabel = DateFormat('MMMM yyyy').format(_selectedDate);
    else {
      DateTime start = _selectedDate.subtract(Duration(days: _selectedDate.weekday - 1));
      DateTime end = start.add(const Duration(days: 6));
      dateLabel = "${DateFormat('MMM dd').format(start)} - ${DateFormat('MMM dd').format(end)}";
    }

    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Detailed Reports", style: AdminTheme.headerStyle),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade300)),
                    child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                            value: _range,
                            items: ["Weekly", "Monthly", "Yearly"].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                            onChanged: (v) => setState(() => _range = v!)
                        )
                    ),
                  ),
                  const SizedBox(width: 16),
                  InkWell(
                    onTap: _pickDate,
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Row(children: [
                        const Icon(Icons.calendar_month, size: 16),
                        const SizedBox(width: 8),
                        Text("Report for: $dateLabel", style: const TextStyle(fontWeight: FontWeight.bold, color: AdminTheme.merchantOrange)),
                        const Icon(Icons.arrow_drop_down),
                      ]),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),

          TabBar(
            controller: _tabController,
            labelColor: AdminTheme.merchantOrange,
            unselectedLabelColor: Colors.grey,
            indicatorColor: AdminTheme.merchantOrange,
            indicatorWeight: 3,
            tabs: const [
              Tab(text: "Eco Impact", icon: Icon(FontAwesomeIcons.leaf)),
              Tab(text: "Listing Efficiency", icon: Icon(FontAwesomeIcons.chartPie)),
            ],
          ),
          const SizedBox(height: 20),

          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildEcoReport(),
                _buildEfficiencyReport(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEcoReport() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('reservations').where('status', isEqualTo: 'picked_up').snapshots(),
      builder: (context, snapshot) {
        if(!snapshot.hasData) return const Center(child: CircularProgressIndicator());

        Map<int, double> buckets = {};
        double totalValue = 0;
        int maxBuckets = _getMaxBuckets();
        for(int i=1; i<=maxBuckets; i++) buckets[i]=0;

        for(var doc in snapshot.data!.docs) {
          final data = doc.data() as Map<String, dynamic>;
          if(data['reservedAt']!=null) {
            final date = (data['reservedAt'] as Timestamp).toDate();
            if(_isDateInRange(date)) {
              double val = (data['co2Saved']??2.5).toDouble();
              int key = _getBucketKey(date);
              buckets[key] = (buckets[key]??0)+val;
              totalValue += val;
            }
          }
        }

        List<Map<String, dynamic>> graphData = [];
        double maxY = 0;
        buckets.forEach((k,v) {
          if(v>maxY) maxY=v;
          graphData.add({'x':k, 'value':v, 'label':_getLabel(k)});
        });
        if(maxY==0) maxY=10;

        return _buildLayout(
            title: "Environmental Impact",
            desc: "Measures total CO2 (kg) prevented by food rescue.",
            explanation: "This report tracks the environmental benefit of the platform. Each rescued meal diverts CO2 that would have been generated by decomposing food waste.",
            interpretation: "A total of ${totalValue.toStringAsFixed(1)}kg CO2 was saved in this period. Peaks indicate high activity days.",
            graphData: graphData,
            maxY: maxY,
            color: Colors.green,
            unit: "kg",
            extraWidget: Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: Co2TreeWidget(totalCo2Saved: totalValue),
            )
        );
      },
    );
  }

  Widget _buildEfficiencyReport() {
    return FutureBuilder<List<QuerySnapshot>>(
      future: Future.wait([
        FirebaseFirestore.instance.collection('listings').get(),
        FirebaseFirestore.instance.collection('reservations').where('status', isEqualTo: 'picked_up').get(),
      ]),
      builder: (context, snapshot) {
        if(!snapshot.hasData) return const Center(child: CircularProgressIndicator());

        Map<int, int> postedMap = {};
        Map<int, int> rescuedMap = {};
        int maxBuckets = _getMaxBuckets();
        for(int i=1; i<=maxBuckets; i++) { postedMap[i]=0; rescuedMap[i]=0; }

        int totalPosted=0, totalRescued=0;

        for(var doc in snapshot.data![0].docs) {
          final d = (doc.data() as Map)['createdAt'] as Timestamp?;
          if(d!=null && _isDateInRange(d.toDate())) {
            int key = _getBucketKey(d.toDate());
            postedMap[key] = (postedMap[key]??0)+1;
            totalPosted++;
          }
        }
        for(var doc in snapshot.data![1].docs) {
          final d = (doc.data() as Map)['reservedAt'] as Timestamp?;
          if(d!=null && _isDateInRange(d.toDate())) {
            int key = _getBucketKey(d.toDate());
            rescuedMap[key] = (rescuedMap[key]??0)+1;
            totalRescued++;
          }
        }

        List<Map<String, dynamic>> graphData = [];
        double maxY = 0;
        postedMap.forEach((k, v) {
          int r = rescuedMap[k] ?? 0;
          if(v > maxY) maxY = v.toDouble();
          if(r > maxY) maxY = r.toDouble();
          graphData.add({'x':k, 'posted':v, 'rescued':r, 'label':_getLabel(k)});
        });
        if(maxY==0) maxY=5;

        double rate = totalPosted == 0 ? 0 : (totalRescued/totalPosted)*100;

        return _buildLayout(
            title: "Listing Efficiency",
            desc: "Comparison of Posted vs Rescued Listings.",
            explanation: "This report analyzes supply vs. demand. 'Posted' is the amount of food merchants listed. 'Rescued' is what was actually picked up.",
            interpretation: "$totalRescued rescued out of $totalPosted posted. Efficiency Rate: ${rate.toStringAsFixed(1)}%. ${rate < 50 ? 'Low efficiency suggests a need for more students or better food variety.' : 'High efficiency indicates strong demand.'}",
            graphData: graphData,
            maxY: maxY,
            color: AdminTheme.merchantOrange,
            unit: "",
            isEfficiency: true
        );
      },
    );
  }

  Widget _buildLayout({
    required String title, required String desc, required String explanation, required String interpretation,
    required List<Map<String, dynamic>> graphData, required double maxY,
    required Color color, required String unit,
    Widget? extraWidget, bool isEfficiency = false
  }) {
    return SingleChildScrollView(
      child: Column(
        children: [
          if(extraWidget != null) extraWidget,

          Container(
            decoration: AdminTheme.cardDecoration,
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  margin: const EdgeInsets.only(bottom: 24),
                  decoration: BoxDecoration(color: color.withOpacity(0.05), borderRadius: BorderRadius.circular(8), border: Border.all(color: color.withOpacity(0.2))),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 4),
                      Text(explanation, style: TextStyle(color: Colors.grey[800], fontSize: 13)),
                    ],
                  ),
                ),

                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Text("Visual Data", style: AdminTheme.subHeaderStyle),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.print, size: 16),
                    label: const Text("Export PDF"),
                    style: ElevatedButton.styleFrom(backgroundColor: color, foregroundColor: Colors.white),
                    onPressed: () => _printReport(title, explanation, interpretation, graphData),
                  )
                ]),
                const SizedBox(height: 30),

                SizedBox(
                  height: 350,
                  child: BarChart(BarChartData(
                    alignment: BarChartAlignment.spaceAround,
                    maxY: maxY * 1.2,
                    barTouchData: BarTouchData(
                        touchTooltipData: BarTouchTooltipData(
                            getTooltipColor: (_) => AdminTheme.midnightBlack,
                            getTooltipItem: (group, groupIndex, rod, rodIndex) {
                              String mainLabel = graphData[group.x.toInt()-1]['label'];
                              String subLabel = "";
                              if (_range == "Monthly") subLabel = "\n${_getDateRangeForWeek(group.x.toInt())}";

                              if(isEfficiency) {
                                String type = rodIndex == 0 ? "Posted" : "Rescued";
                                return BarTooltipItem("$mainLabel$subLabel\n$type: ${rod.toY.toInt()}", const TextStyle(color: Colors.white));
                              }
                              return BarTooltipItem("$mainLabel$subLabel\n${rod.toY.toStringAsFixed(1)} $unit", const TextStyle(color: Colors.white));
                            }
                        )
                    ),
                    titlesData: FlTitlesData(
                      show: true,
                      bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, getTitlesWidget: (val, _) {
                        int idx = val.toInt() - 1;
                        if(idx >= 0 && idx < graphData.length) {
                          return Padding(padding: const EdgeInsets.only(top:8), child: Text(graphData[idx]['label'], style: const TextStyle(fontSize: 10, color: Colors.grey)));
                        }
                        return const SizedBox();
                      })),
                      leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 30, getTitlesWidget: (v,_) => Text(v.toInt().toString(), style: const TextStyle(fontSize: 10)))),
                      topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    ),
                    gridData: FlGridData(show: true, drawVerticalLine: false),
                    borderData: FlBorderData(show: false),
                    barGroups: graphData.map((e) {
                      if(isEfficiency) {
                        return BarChartGroupData(x: e['x'], barsSpace: 4, barRods: [
                          BarChartRodData(toY: (e['posted'] as int).toDouble(), color: Colors.grey.shade300, width: _getBarWidth(), borderRadius: BorderRadius.circular(2)),
                          BarChartRodData(toY: (e['rescued'] as int).toDouble(), color: Colors.green, width: _getBarWidth(), borderRadius: BorderRadius.circular(2)),
                        ]);
                      } else {
                        return BarChartGroupData(x: e['x'], barRods: [BarChartRodData(toY: (e['value'] as double), color: color, width: _getBarWidth() + 4, borderRadius: BorderRadius.circular(4))]);
                      }
                    }).toList(),
                  )),
                ),

                if(isEfficiency)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [_legendItem(Colors.grey.shade300, "Posted"), const SizedBox(width: 16), _legendItem(Colors.green, "Rescued")]),
                  ),

                const Divider(height: 40),

                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Data Interpretation:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    const SizedBox(height: 4),
                    Text(interpretation, style: TextStyle(color: Colors.grey[700], fontSize: 13, height: 1.4)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  int _getMaxBuckets() {
    if (_range == "Yearly") return 12;
    if (_range == "Monthly") return 5;
    return 7;
  }

  bool _isDateInRange(DateTime date) {
    if (_range == "Yearly") return date.year == _selectedDate.year;
    if (_range == "Monthly") return date.year == _selectedDate.year && date.month == _selectedDate.month;
    DateTime start = _selectedDate.subtract(Duration(days: _selectedDate.weekday - 1));
    DateTime end = start.add(const Duration(days: 6, hours: 23));
    return date.isAfter(start.subtract(const Duration(seconds: 1))) && date.isBefore(end);
  }

  int _getBucketKey(DateTime date) {
    if (_range == "Yearly") return date.month;
    if (_range == "Monthly") {
      return ((date.day - 1) / 7).floor() + 1;
    }
    return date.weekday;
  }

  String _getLabel(int k) {
    if (_range == "Yearly") return DateFormat('MMM').format(DateTime(_selectedDate.year, k));
    if (_range == "Monthly") return "Wk $k";
    const days = ["Mon","Tue","Wed","Thu","Fri","Sat","Sun"];
    return days[k-1];
  }

  String _getDateRangeForWeek(int weekNum) {
    DateTime firstDayOfMonth = DateTime(_selectedDate.year, _selectedDate.month, 1);
    DateTime start = firstDayOfMonth.add(Duration(days: (weekNum - 1) * 7));
    DateTime end = start.add(const Duration(days: 6));
    int daysInMonth = DateTime(_selectedDate.year, _selectedDate.month + 1, 0).day;
    if (end.month != start.month || end.day > daysInMonth) end = DateTime(_selectedDate.year, _selectedDate.month, daysInMonth);
    return "${DateFormat('MMM d').format(start)} - ${DateFormat('d').format(end)}";
  }

  double _getBarWidth() {
    if (_range == "Yearly") return 16;
    if (_range == "Monthly") return 24;
    return 20;
  }

  Widget _legendItem(Color color, String text) => Row(children: [Container(width: 12, height: 12, color: color), const SizedBox(width: 4), Text(text, style: const TextStyle(fontSize: 12))]);
}