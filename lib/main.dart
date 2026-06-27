// Basic Flutter app showing weekly/monthly/annual stats with mock data.
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

void main() {
  runApp(RunAnalyzeApp());
}

class RunAnalyzeApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'RunAnalyze (MVP)',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: DashboardPage(),
    );
  }
}

enum Timeframe { week, month, year }

class Activity {
  final String id;
  final DateTime date;
  final String type;
  final double distanceKm;
  final int durationSec;
  final int elevationGain;

  Activity({required this.id, required this.date, required this.type, required this.distanceKm, required this.durationSec, required this.elevationGain});
}

// Mock data generator
List<Activity> mockActivities() {
  final now = DateTime.now();
  final List<Activity> list = [];
  for (int i = 0; i < 60; i++) {
    final d = now.subtract(Duration(days: i * 3));
    list.add(Activity(
      id: 'a$i',
      date: d,
      type: i % 5 == 0 ? 'ride' : 'run',
      distanceKm: (5 + (i % 6)) + (i % 3) * 0.2,
      durationSec: 30 * 60 + (i % 60) * 10,
      elevationGain: (i % 100) + 10,
    ));
  }
  return list;
}

class DashboardPage extends StatefulWidget {
  @override
  _DashboardPageState createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  Timeframe _timeframe = Timeframe.week;
  late List<Activity> _activities;

  @override
  void initState() {
    super.initState();
    _activities = mockActivities();
  }

  List<Activity> _filtered() {
    final now = DateTime.now();
    Duration span;
    if (_timeframe == Timeframe.week) span = Duration(days: 7);
    else if (_timeframe == Timeframe.month) span = Duration(days: 30);
    else span = Duration(days: 365);

    return _activities.where((a) => a.date.isAfter(now.subtract(span))).toList();
  }

  double _totalDistance(List<Activity> list) => list.fold(0.0, (p, e) => p + e.distanceKm);
  int _totalDuration(List<Activity> list) => list.fold(0, (p, e) => p + e.durationSec);
  int _totalElevation(List<Activity> list) => list.fold(0, (p, e) => p + e.elevationGain);

  String _formatDuration(int seconds) {
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    return '${hours}h ${minutes}m';
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered();
    final totalDist = _totalDistance(filtered);
    final totalDur = _totalDuration(filtered);
    final totalElev = _totalElevation(filtered);
    final avgPace = totalDist > 0 ? (totalDur / 60) / totalDist : 0; // min per km

    return Scaffold(
      appBar: AppBar(title: Text('RunAnalyze (MVP)')),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ChoiceChip(label: Text('Week'), selected: _timeframe == Timeframe.week, onSelected: (_) => setState(() => _timeframe = Timeframe.week)),
                ChoiceChip(label: Text('Month'), selected: _timeframe == Timeframe.month, onSelected: (_) => setState(() => _timeframe = Timeframe.month)),
                ChoiceChip(label: Text('Year'), selected: _timeframe == Timeframe.year, onSelected: (_) => setState(() => _timeframe = Timeframe.year)),
              ],
            ),
            SizedBox(height: 12),
            // Summary cards
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _SummaryCard(title: 'Distance', value: '${totalDist.toStringAsFixed(1)} km'),
                _SummaryCard(title: 'Duration', value: _formatDuration(totalDur)),
                _SummaryCard(title: 'Elevation', value: '${totalElev} m'),
              ],
            ),
            SizedBox(height: 12),
            _MiniChart(activities: filtered),
            SizedBox(height: 12),
            Expanded(
              child: Card(
                child: ListView.builder(
                  itemCount: filtered.length,
                  itemBuilder: (context, idx) {
                    final a = filtered[idx];
                    return ListTile(
                      title: Text('${a.type.toUpperCase()} • ${a.distanceKm.toStringAsFixed(1)} km'),
                      subtitle: Text('${a.date.toLocal().toIso8601String().split('T').first} • ${_formatDuration(a.durationSec)}'),
                      trailing: Text('${(a.durationSec/60 / a.distanceKm).toStringAsFixed(1)} min/km'),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String title;
  final String value;
  _SummaryCard({required this.title, required this.value});
  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            children: [
              Text(title, style: TextStyle(fontSize: 12, color: Colors.grey[700])),
              SizedBox(height: 8),
              Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniChart extends StatelessWidget {
  final List<Activity> activities;
  _MiniChart({required this.activities});

  @override
  Widget build(BuildContext context) {
    // Aggregate distance per day for the chart
    final Map<String, double> perDay = {};
    for (var a in activities) {
      final k = a.date.toLocal().toIso8601String().split('T').first;
      perDay[k] = (perDay[k] ?? 0) + a.distanceKm;
    }
    final entries = perDay.entries.toList()..sort((a,b) => a.key.compareTo(b.key));

    final spots = List.generate(entries.length, (i) => FlSpot(i.toDouble(), entries[i].value));

    if (spots.isEmpty) {
      return Center(child: Text('No data for this period'));
    }

    return SizedBox(
      height: 120,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: LineChart(
            LineChartData(
              gridData: FlGridData(show: false),
              titlesData: FlTitlesData(show: false),
              borderData: FlBorderData(show: false),
              lineBarsData: [
                LineChartBarData(spots: spots, isCurved: true, dotData: FlDotData(show: false), colors: [Colors.blue])
              ],
            ),
          ),
        ),
      ),
    );
  }
}
