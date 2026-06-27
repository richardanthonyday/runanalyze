import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'models/activity.dart';
import 'services/runalyze_client.dart';
import 'services/activity_service.dart';
import 'utils/activity_grouper.dart';

void main() {
  runApp(const RunAnalyzeApp());
}

class RunAnalyzeApp extends StatelessWidget {
  const RunAnalyzeApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'RunAnalyze (MVP)',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const DashboardPage(),
    );
  }
}

enum Timeframe { week, month, year }

class DashboardPage extends StatefulWidget {
  const DashboardPage({Key? key}) : super(key: key);

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  Timeframe _timeframe = Timeframe.week;
  late ActivityService _activityService;
  List<Activity> _activities = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    // TODO: Load API token from secure storage or environment
    final apiToken = 'pt#fc0bc78894a497c647fc7208b08364fa';
    final client = RunalyzeClient(apiToken: apiToken);
    _activityService = ActivityService(client: client);
    _loadActivities();
  }

  Future<void> _loadActivities() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final activities = await _activityService.getActivities(forceRefresh: true);
      setState(() {
        _activities = activities;
        _loading = false;
      });
    } on RunalyzeException catch (e) {
      setState(() {
        _error = e.message;
        _loading = false;
      });
    }
  }

  List<Activity> _filtered() {
    int days;
    if (_timeframe == Timeframe.week) {
      days = 7;
    } else if (_timeframe == Timeframe.month) {
      days = 30;
    } else {
      days = 365;
    }
    return _activityService.filterByDays(_activities, days);
  }

  List<ActivityGroup> _getGroups() {
    final filtered = _filtered();
    if (_timeframe == Timeframe.week) {
      return ActivityGrouper.groupByWeek(filtered);
    } else if (_timeframe == Timeframe.month) {
      return ActivityGrouper.groupByMonth(filtered);
    } else {
      return ActivityGrouper.groupByYear(filtered);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('RunAnalyze (MVP)')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('RunAnalyze (MVP)')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text(
                'Error: $_error',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _loadActivities,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    final filtered = _filtered();
    final totalDist = _activityService.totalDistance(filtered);
    final totalDur = _activityService.totalDuration(filtered);
    final avgPace = _activityService.averagePace(filtered);
    final groups = _getGroups();

    return Scaffold(
      appBar: AppBar(
        title: const Text('RunAnalyze (MVP)'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadActivities,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            // Timeframe selector
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ChoiceChip(
                  label: const Text('Week'),
                  selected: _timeframe == Timeframe.week,
                  onSelected: (_) =>
                      setState(() => _timeframe = Timeframe.week),
                ),
                ChoiceChip(
                  label: const Text('Month'),
                  selected: _timeframe == Timeframe.month,
                  onSelected: (_) =>
                      setState(() => _timeframe = Timeframe.month),
                ),
                ChoiceChip(
                  label: const Text('Year'),
                  selected: _timeframe == Timeframe.year,
                  onSelected: (_) =>
                      setState(() => _timeframe = Timeframe.year),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Summary cards
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _SummaryCard(
                  title: 'Distance',
                  value: '${totalDist.toStringAsFixed(1)} km',
                ),
                _SummaryCard(
                  title: 'Duration',
                  value: _formatDuration(totalDur),
                ),
                _SummaryCard(
                  title: 'Avg Pace',
                  value: '${avgPace.toStringAsFixed(2)} min/km',
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Chart
            if (filtered.isNotEmpty)
              _MiniChart(activities: filtered)
            else
              const Card(
                child: SizedBox(
                  height: 120,
                  child: Center(child: Text('No activities in this period')),
                ),
              ),
            const SizedBox(height: 12),

            // Grouped activity list
            Expanded(
              child: Card(
                child: filtered.isEmpty
                    ? const Center(child: Text('No activities found'))
                    : ListView.builder(
                        itemCount: groups.length,
                        itemBuilder: (context, idx) {
                          return _GroupCard(group: groups[idx]);
                        },
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDuration(int seconds) {
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }
    return '${minutes}m';
  }
}

class _GroupCard extends StatefulWidget {
  final ActivityGroup group;

  const _GroupCard({
    Key? key,
    required this.group,
  }) : super(key: key);

  @override
  State<_GroupCard> createState() => _GroupCardState();
}

class _GroupCardState extends State<_GroupCard> {
  bool _expanded = true;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ListTile(
          title: Text(
            widget.group.label,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          subtitle: Text(
            '${widget.group.count} activities • ${widget.group.totalDistance.toStringAsFixed(1)} km • ${_formatDuration(widget.group.totalDuration)}',
            style: const TextStyle(fontSize: 12),
          ),
          trailing: Icon(
            _expanded ? Icons.expand_less : Icons.expand_more,
          ),
          onTap: () => setState(() => _expanded = !_expanded),
        ),
        if (_expanded)
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: widget.group.activities.length,
            itemBuilder: (context, idx) {
              final activity = widget.group.activities[idx];
              return Padding(
                padding: const EdgeInsets.only(left: 16.0, right: 16.0, top: 4, bottom: 4),
                child: Card(
                  child: ListTile(
                    dense: true,
                    title: Text(
                      '${activity.sport}${activity.type != null ? ' • ${activity.type}' : ''} • ${activity.distance.toStringAsFixed(1)} km',
                      style: const TextStyle(fontSize: 14),
                    ),
                    subtitle: Text(
                      '${DateFormat('MMM d, EEE').format(activity.dateTime)} • ${activity.formatDuration()}',
                      style: const TextStyle(fontSize: 11),
                    ),
                    trailing: Text(
                      activity.formatPace(),
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ),
              );
            },
          )
        else
          const Divider(),
      ],
    );
  }

  String _formatDuration(int seconds) {
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }
    return '${minutes}m';
  }
}

class _SummaryCard extends StatelessWidget {
  final String title;
  final String value;

  const _SummaryCard({
    Key? key,
    required this.title,
    required this.value,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            children: [
              Text(
                title,
                style: TextStyle(fontSize: 12, color: Colors.grey[700]),
              ),
              const SizedBox(height: 8),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniChart extends StatelessWidget {
  final List<Activity> activities;

  const _MiniChart({
    Key? key,
    required this.activities,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Aggregate distance per day for the chart
    final Map<String, double> perDay = {};
    for (var a in activities) {
      final k = a.dateTime.toLocal().toIso8601String().split('T').first;
      perDay[k] = (perDay[k] ?? 0) + a.distance;
    }
    final entries = perDay.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    final spots = List.generate(
      entries.length,
      (i) => FlSpot(i.toDouble(), entries[i].value),
    );

    if (spots.isEmpty) {
      return const Card(
        child: SizedBox(
          height: 120,
          child: Center(child: Text('No data for this period')),
        ),
      );
    }

    return SizedBox(
      height: 120,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: LineChart(
            LineChartData(
              gridData: const FlGridData(show: false),
              titlesData: const FlTitlesData(show: false),
              borderData: const FlBorderData(show: false),
              lineBarsData: [
                LineChartBarData(
                  spots: spots,
                  isCurved: true,
                  dotData: const FlDotData(show: false),
                  colors: const [Colors.blue],
                )
              ],
            ),
          ),
        ),
      ),
    );
  }
}
