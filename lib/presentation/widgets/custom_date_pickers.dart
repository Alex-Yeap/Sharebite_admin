import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/admin_theme.dart';

class YearPickerDialog extends StatelessWidget {
  final DateTime initialDate;
  const YearPickerDialog({super.key, required this.initialDate});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text("Select Year"),
      content: SizedBox(
        width: 300,
        height: 300,
        child: YearPicker(
          firstDate: DateTime(2023),
          lastDate: DateTime.now(),
          selectedDate: initialDate,
          onChanged: (DateTime dateTime) {
            Navigator.pop(context, dateTime);
          },
        ),
      ),
    );
  }
}

class MonthPickerDialog extends StatefulWidget {
  final DateTime initialDate;
  const MonthPickerDialog({super.key, required this.initialDate});

  @override
  State<MonthPickerDialog> createState() => _MonthPickerDialogState();
}

class _MonthPickerDialogState extends State<MonthPickerDialog> {
  late int _selectedYear;

  @override
  void initState() {
    super.initState();
    _selectedYear = widget.initialDate.year;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(icon: const Icon(Icons.chevron_left), onPressed: () => setState(() => _selectedYear--)),
          Text("$_selectedYear", style: const TextStyle(fontWeight: FontWeight.bold)),
          IconButton(
              icon: const Icon(Icons.chevron_right),
              onPressed: _selectedYear >= DateTime.now().year ? null : () => setState(() => _selectedYear++)
          ),
        ],
      ),
      content: SizedBox(
        width: 300,
        height: 300,
        child: GridView.builder(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            childAspectRatio: 1.5,
          ),
          itemCount: 12,
          itemBuilder: (context, index) {
            final monthIndex = index + 1;
            final isFuture = _selectedYear == DateTime.now().year && monthIndex > DateTime.now().month;
            return InkWell(
              onTap: isFuture ? null : () => Navigator.pop(context, DateTime(_selectedYear, monthIndex)),
              child: Container(
                margin: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: isFuture ? Colors.grey.shade100 : Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                alignment: Alignment.center,
                child: Text(
                  DateFormat('MMM').format(DateTime(2024, monthIndex)),
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isFuture ? Colors.grey : Colors.green.shade800
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class WeeklyDatePickerDialog extends StatefulWidget {
  final DateTime initialDate;
  const WeeklyDatePickerDialog({super.key, required this.initialDate});

  @override
  State<WeeklyDatePickerDialog> createState() => _WeeklyDatePickerDialogState();
}

class _WeeklyDatePickerDialogState extends State<WeeklyDatePickerDialog> {
  late DateTime _currentMonth;

  @override
  void initState() {
    super.initState();
    _currentMonth = DateTime(widget.initialDate.year, widget.initialDate.month);
  }

  @override
  Widget build(BuildContext context) {
    final daysInMonth = DateTime(_currentMonth.year, _currentMonth.month + 1, 0).day;
    final firstDayOffset = DateTime(_currentMonth.year, _currentMonth.month, 1).weekday - 1;

    return AlertDialog(
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(icon: const Icon(Icons.chevron_left), onPressed: () => setState(() => _currentMonth = DateTime(_currentMonth.year, _currentMonth.month - 1))),
          Text(DateFormat('MMMM yyyy').format(_currentMonth), style: const TextStyle(fontWeight: FontWeight.bold)),
          IconButton(icon: const Icon(Icons.chevron_right), onPressed: () => setState(() => _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + 1))),
        ],
      ),
      content: SizedBox(
        width: 320,
        height: 320,
        child: Column(
          children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: ["M","T","W","T","F","S","S"].map((d) => Text(d, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey))).toList()),
            const SizedBox(height: 10),
            Expanded(
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 7),
                itemCount: daysInMonth + firstDayOffset,
                itemBuilder: (context, index) {
                  if (index < firstDayOffset) return const SizedBox();
                  final day = index - firstDayOffset + 1;
                  final date = DateTime(_currentMonth.year, _currentMonth.month, day);

                  return InkWell(
                    onTap: () => Navigator.pop(context, date),
                    child: Container(
                      margin: const EdgeInsets.all(2),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(4)),
                      child: Text("$day"),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}