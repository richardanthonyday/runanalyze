import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'models/activity.dart';
import 'services/runalyze_client.dart';
import 'services/activity_service.dart';
import 'utils/activity_grouper.dart';

const bool kApiProbeMode = bool.fromEnvironment(
  'API_PROBE_MODE',
  defaultValue: false,
);

void main() {
  runApp(const RunAnalyzeApp());
}

class RunAnalyzeApp extends StatelessWidget {
  const RunAnalyzeApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'RunAnalyze (Basic)',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: kApiProbeMode ? const ApiProbePage() : const DashboardPage(),
    );
  }
}

class ApiProbePage extends StatefulWidget {
  const ApiProbePage({Key? key}) : super(key: key);

  @override
  State<ApiProbePage> createState() => _ApiProbePageState();
}

class _ApiProbePageState extends State<ApiProbePage> {
  bool _loading = true;
  RunalyzeApiProbeResult? _result;
  String _probeMode = 'latest';
  int _probeItemsPerPage = 1;
  int _probeWindowDays = 7;

  void _dumpProbeToConsole() {
    final result = _result;
    if (result == null) return;

    final weekly = _probeMode == 'week-first-page'
      ? _windowFilteredFromFirstPage(result.responseBody)
        : null;

    final payload = {
      'probe_mode': _probeMode,
      'probe_items_per_page': _probeItemsPerPage,
      'probe_window_days': _probeWindowDays,
      'duration_ms': result.durationMs,
      'status': result.statusCode,
      'error': result.error,
      'request_url': result.requestUrl,
      'request_headers': result.requestHeaders,
      'response_headers': result.responseHeaders,
      'response_body': result.responseBody,
      'window_filtered_from_first_page': weekly,
    };

    final pretty = const JsonEncoder.withIndent('  ').convert(payload);
    debugPrint('=== RUNANALYZE_API_PROBE_START ===');
    for (final line in pretty.split('\n')) {
      debugPrint(line);
    }
    debugPrint('=== RUNANALYZE_API_PROBE_END ===');

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Probe dumped to Flutter console output')),
    );
  }

  @override
  void initState() {
    super.initState();
    _runProbe();
  }

  Future<void> _runProbe() async {
    setState(() {
      _loading = true;
      _result = null;
    });

    final client = RunalyzeClient(
      apiToken: 'pt#fc0bc78894a497c647fc7208b08364fa',
    );

    final result = await client.probeActivityPage(
      page: 1,
      itemsPerPage: _probeItemsPerPage,
    );

    setState(() {
      _loading = false;
      _result = result;
    });
  }

  Map<String, dynamic>? _windowFilteredFromFirstPage(String? body) {
    if (body == null || body.isEmpty) return null;
    final decoded = jsonDecode(body);
    if (decoded is! List) return null;

    final now = DateTime.now();
    final windowStart = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: _probeWindowDays - 1));

    final weekly = decoded.whereType<Map>().where((item) {
      final dtRaw = item['date_time'];
      if (dtRaw is! String) return false;
      final dt = DateTime.tryParse(dtRaw)?.toLocal();
      if (dt == null) return false;
      return !dt.isBefore(windowStart);
    }).toList();

    final totalKm = weekly.fold<double>(
      0,
      (sum, item) => sum + ((item['distance'] as num?)?.toDouble() ?? 0.0),
    );

    return {
      'window_days': _probeWindowDays,
      'window_start_local': windowStart.toIso8601String(),
      'first_page_count': decoded.length,
      'window_count_from_first_page': weekly.length,
      'window_total_distance_km_from_first_page': totalKm,
      'activities': weekly,
    };
  }

  String _formatPretty(String? body) {
    if (body == null || body.isEmpty) return '(empty)';
    try {
      final decoded = jsonDecode(body);
      return const JsonEncoder.withIndent('  ').convert(decoded);
    } catch (_) {
      return body;
    }
  }

  void _backToApp() {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
      return;
    }

    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => const DashboardPage(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('API Probe'),
        actions: [
          IconButton(
            icon: const Icon(Icons.home),
            tooltip: 'Back to app',
            onPressed: _backToApp,
          ),
          IconButton(
            icon: const Icon(Icons.terminal),
            tooltip: 'Dump probe to console',
            onPressed: _loading ? null : _dumpProbeToConsole,
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.tune),
            onSelected: (value) {
              setState(() {
                if (value.startsWith('mode:')) {
                  _probeMode = value.substring(5);
                  if (_probeMode == 'week-first-page' && _probeItemsPerPage == 1) {
                    _probeItemsPerPage = 100;
                  }
                } else if (value.startsWith('size:')) {
                  _probeItemsPerPage = int.tryParse(value.substring(5)) ?? _probeItemsPerPage;
                } else if (value.startsWith('window:')) {
                  _probeWindowDays = int.tryParse(value.substring(7)) ?? _probeWindowDays;
                }
              });
              _runProbe();
            },
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: 'mode:latest',
                child: Text('Mode: Latest payload'),
              ),
              PopupMenuItem(
                value: 'mode:week-first-page',
                child: Text('Mode: Window-filter from first page'),
              ),
              PopupMenuDivider(),
              PopupMenuItem(
                value: 'size:1',
                child: Text('Size: 1 record'),
              ),
              PopupMenuItem(
                value: 'size:25',
                child: Text('Size: 25 records'),
              ),
              PopupMenuItem(
                value: 'size:50',
                child: Text('Size: 50 records'),
              ),
              PopupMenuItem(
                value: 'size:100',
                child: Text('Size: 100 records'),
              ),
              PopupMenuItem(
                value: 'size:500',
                child: Text('Size: 500 records'),
              ),
              PopupMenuItem(
                value: 'size:1000',
                child: Text('Size: 1000 records'),
              ),
              PopupMenuDivider(),
              PopupMenuItem(
                value: 'window:7',
                child: Text('Window: last 7 days'),
              ),
              PopupMenuItem(
                value: 'window:14',
                child: Text('Window: last 14 days'),
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _runProbe,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(12),
              child: _result == null
                  ? const Text('No probe result available.')
                  : SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Probe mode: $_probeMode'),
                          Text('Probe itemsPerPage: $_probeItemsPerPage'),
                          Text('Probe window days: $_probeWindowDays'),
                          Text('Duration: ${_result!.durationMs} ms'),
                          Text('Status: ${_result!.statusCode ?? 'no response'}'),
                          if (_result!.error != null)
                            Text(
                              'Error: ${_result!.error}',
                              style: const TextStyle(color: Colors.red),
                            ),
                          const SizedBox(height: 12),
                          const Text(
                            'Request URL',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          SelectableText(_result!.requestUrl),
                          const SizedBox(height: 12),
                          const Text(
                            'Request Headers',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          SelectableText(const JsonEncoder.withIndent('  ')
                              .convert(_result!.requestHeaders)),
                          const SizedBox(height: 12),
                          const Text(
                            'Response Headers',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          SelectableText(const JsonEncoder.withIndent('  ')
                              .convert(_result!.responseHeaders)),
                          const SizedBox(height: 12),
                          const Text(
                            'Response Body',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          SelectableText(_formatPretty(_result!.responseBody)),
                          if (_probeMode == 'week-first-page') ...[
                            const SizedBox(height: 12),
                            Text(
                              'Window Filtered Result (Last $_probeWindowDays Days, From First Page)',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            SelectableText(
                              _formatPretty(
                                jsonEncode(
                                  _windowFilteredFromFirstPage(
                                        _result!.responseBody,
                                      ) ??
                                      {
                                        'error': 'Could not parse response as a JSON list',
                                      },
                                ),
                              ),
                            ),
                          ],
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: _backToApp,
                            child: const Text('Back to App'),
                          ),
                        ],
                      ),
                    ),
            ),
    );
  }
}

enum Timeframe { week, month, year }
enum DistanceUnit { km, mi }

class DashboardPage extends StatefulWidget {
  const DashboardPage({Key? key}) : super(key: key);

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  static const String _recordsPerPageKey = 'records_per_page';
  static const String _distanceUnitKey = 'distance_unit';
  Timeframe _timeframe = Timeframe.week;
  DistanceUnit _distanceUnit = DistanceUnit.km;
  String _sportFilter = 'Running';
  int _recordsPerPage = 10;
  late ActivityService _activityService;
  List<Activity> _activities = [];
  bool _loading = true;
  bool _loadingMore = false;
  String? _error;
  DateTime? _loadedNotBefore;
  int _loadedPeriods = 1;
  bool _queuedLoadMoreFromPlaceholder = false;
  final ScrollController _scrollController = ScrollController();

  static const double _kmToMiles = 0.621371;

  @override
  void initState() {
    super.initState();
    // TODO: Load API token from secure storage or environment
    final apiToken = 'pt#fc0bc78894a497c647fc7208b08364fa';
    final client = RunalyzeClient(apiToken: apiToken);
    _activityService = ActivityService(client: client);
    _scrollController.addListener(_onScroll);
    _initAndLoad();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _initAndLoad() async {
    final savedRecords = await _loadRecordsPerPagePreference();
    final savedUnit = await _loadDistanceUnitPreference();
    if ((savedRecords != null || savedUnit != null) && mounted) {
      setState(() {
        if (savedRecords != null) {
          _recordsPerPage = savedRecords;
        }
        if (savedUnit != null) {
          _distanceUnit = savedUnit;
        }
      });
    }
    if (!mounted) return;
    await _loadActivities(cutoff: _cutoffFor(Timeframe.week, periods: _loadedPeriods));
  }

  Future<int?> _loadRecordsPerPagePreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final value = prefs.getInt(_recordsPerPageKey);
      if (value == null) return null;
      if (value != 10 && value != 25 && value != 50) return null;
      return value;
    } catch (_) {
      return null;
    }
  }

  Future<void> _saveRecordsPerPagePreference(int value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_recordsPerPageKey, value);
    } catch (_) {
      // Non-fatal; keep running even if persistence is unavailable.
    }
  }

  Future<DistanceUnit?> _loadDistanceUnitPreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final value = prefs.getString(_distanceUnitKey);
      if (value == null) return null;
      if (value == 'km') return DistanceUnit.km;
      if (value == 'mi') return DistanceUnit.mi;
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<void> _saveDistanceUnitPreference(DistanceUnit value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_distanceUnitKey, value == DistanceUnit.km ? 'km' : 'mi');
    } catch (_) {
      // Non-fatal; keep running even if persistence is unavailable.
    }
  }

  Future<void> _openSettingsDialog() async {
    DistanceUnit tempUnit = _distanceUnit;
    int tempRecordsPerPage = _recordsPerPage;

    final action = await showDialog<String>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setLocalState) {
            return AlertDialog(
              title: const Text('Settings'),
              content: SizedBox(
                width: 360,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Display',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<DistanceUnit>(
                      value: tempUnit,
                      decoration: const InputDecoration(
                        labelText: 'Distance Unit',
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: DistanceUnit.km,
                          child: Text('Kilometers (km)'),
                        ),
                        DropdownMenuItem(
                          value: DistanceUnit.mi,
                          child: Text('Miles (mi)'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value == null) return;
                        setLocalState(() => tempUnit = value);
                      },
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Advanced',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<int>(
                      value: tempRecordsPerPage,
                      decoration: const InputDecoration(
                        labelText: 'API Paging',
                        helperText: 'Records per API page request',
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                      items: const [10, 25, 50]
                          .map(
                            (size) => DropdownMenuItem<int>(
                              value: size,
                              child: Text('$size records'),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value == null) return;
                        setLocalState(() => tempRecordsPerPage = value);
                      },
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: () => Navigator.of(context).pop('probe'),
                        icon: const Icon(Icons.bug_report),
                        label: const Text('Open API Probe'),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop('cancel'),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop('apply'),
                  child: const Text('Apply'),
                ),
              ],
            );
          },
        );
      },
    );

    if (action == 'probe') {
      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => const ApiProbePage(),
        ),
      );
      return;
    }

    if (action != 'apply') return;

    final pagingChanged = tempRecordsPerPage != _recordsPerPage;
    setState(() {
      _distanceUnit = tempUnit;
      _recordsPerPage = tempRecordsPerPage;
      if (pagingChanged) {
        _loadedNotBefore = null;
        _loadedPeriods = 1;
      }
    });

    await _saveDistanceUnitPreference(tempUnit);
    await _saveRecordsPerPagePreference(tempRecordsPerPage);

    if (pagingChanged) {
      await _loadActivities(cutoff: _cutoffFor(_timeframe, periods: _loadedPeriods));
    }
  }

  DateTime _cutoffFor(Timeframe timeframe, {int periods = 1}) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    if (timeframe == Timeframe.week) {
      // Sunday-Saturday week boundaries.
      final weekStart = today.subtract(Duration(days: today.weekday % 7));
      return weekStart.subtract(Duration(days: (periods - 1) * 7));
    }
    if (timeframe == Timeframe.month) {
      final monthStart = DateTime(now.year, now.month, 1);
      return DateTime(monthStart.year, monthStart.month - (periods - 1), 1);
    }
    final yearStart = DateTime(now.year, 1, 1);
    return DateTime(yearStart.year - (periods - 1), 1, 1);
  }

  Future<void> _loadActivities({
    required DateTime cutoff,
    bool forceRefresh = true,
    bool appendMode = false,
    int? loadedPeriodsOnSuccess,
  }) async {
    if (appendMode) {
      setState(() {
        _loadingMore = true;
      });
    } else {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final activities = await _activityService
          .getActivities(
        forceRefresh: forceRefresh,
        notBefore: cutoff,
        itemsPerPage: _recordsPerPage,
      )
          .timeout(
        _timeoutForCutoff(cutoff),
        onTimeout: () {
          throw RunalyzeException(
            'Refreshing activities took too long. Please wait a minute and retry.',
          );
        },
      );
      setState(() {
        _activities = activities;
        _loadedNotBefore = cutoff;
        if (loadedPeriodsOnSuccess != null) {
          _loadedPeriods = loadedPeriodsOnSuccess;
        }
        _loading = false;
        _loadingMore = false;
      });
    } on RunalyzeException catch (e) {
      setState(() {
        _error = e.message;
        _loading = false;
        _loadingMore = false;
      });
    }
  }

  Duration _timeoutForCutoff(DateTime cutoff) {
    final now = DateTime.now();
    final weekStart = _cutoffFor(Timeframe.week);
    final monthStart = _cutoffFor(Timeframe.month);

    if (cutoff.isAtSameMomentAs(weekStart)) {
      return const Duration(seconds: 30);
    }
    if (cutoff.isAtSameMomentAs(monthStart)) {
      return const Duration(seconds: 60);
    }
    if (cutoff.year == now.year && cutoff.month == 1 && cutoff.day == 1) {
      return const Duration(seconds: 90);
    }
    return const Duration(seconds: 40);
  }

  Future<void> _switchTimeframe(Timeframe timeframe) async {
    if (_timeframe == timeframe) return;
    setState(() {
      _timeframe = timeframe;
      _loadedPeriods = 1;
      _loadedNotBefore = null;
    });
    await _loadActivities(
      cutoff: _cutoffFor(_timeframe, periods: _loadedPeriods),
      forceRefresh: false,
    );
  }

  Future<void> _loadMorePeriods() async {
    if (_loading || _loadingMore) return;

    final maxPeriods = _maxPeriodsFor(_timeframe);
    if (_loadedPeriods >= maxPeriods) return;

    final nextPeriods = (_loadedPeriods + 1).clamp(1, maxPeriods);
    await _loadActivities(
      cutoff: _cutoffFor(_timeframe, periods: nextPeriods),
      forceRefresh: false,
      appendMode: true,
      loadedPeriodsOnSuccess: nextPeriods,
    );
  }

  Future<void> _fullRefresh() async {
    setState(() {
      _loadedNotBefore = null;
      _loadedPeriods = 1;
      _error = null;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cache cleared, reloading from page 1...'),
          duration: Duration(seconds: 2),
        ),
      );
    }

    await _loadActivities(
      cutoff: _cutoffFor(_timeframe, periods: _loadedPeriods),
      forceRefresh: true,
    );
  }

  void _goHomeFromError() {
    setState(() {
      _error = null;
      _loading = false;
    });
  }

  void _onScroll() {
    if (!_scrollController.hasClients || _loading || _loadingMore) return;
    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 180) {
      _loadMorePeriods();
    }
  }

  int _maxPeriodsFor(Timeframe timeframe) {
    if (timeframe == Timeframe.week) return 52;
    if (timeframe == Timeframe.month) return 24;
    return 10;
  }

  bool _hasMorePeriods() {
    return _loadedPeriods < _maxPeriodsFor(_timeframe);
  }

  DateTime _nextPeriodStart() {
    final currentCutoff = _cutoffFor(_timeframe, periods: _loadedPeriods);
    if (_timeframe == Timeframe.week) {
      return currentCutoff.subtract(const Duration(days: 7));
    }
    if (_timeframe == Timeframe.month) {
      return DateTime(currentCutoff.year, currentCutoff.month - 1, 1);
    }
    return DateTime(currentCutoff.year - 1, 1, 1);
  }

  List<Activity> _filtered() {
    final now = DateTime.now();

    return _activities
      .where((a) => !a.dateTime.isAfter(now))
        .where((a) => _sportFilter == 'All' || a.sport == _sportFilter)
        .toList();
  }

  List<String> _sportOptions() {
    final sports = _activities
        .map((a) => a.sport)
        .where((s) => s.trim().isNotEmpty)
        .toSet()
        .toList()
      ..sort();

    final options = <String>{'All', ...sports};
    options.add('Running');
    return options.toList();
  }

  List<ActivityGroup> _getGroups() {
    final filtered = _filtered();
    List<ActivityGroup> groups;
    if (_timeframe == Timeframe.week) {
      groups = ActivityGrouper.groupByWeek(filtered);
    } else if (_timeframe == Timeframe.month) {
      groups = ActivityGrouper.groupByMonth(filtered);
    } else {
      groups = ActivityGrouper.groupByYear(filtered);
    }

    final byStart = <String, ActivityGroup>{
      for (final g in groups) _periodKey(g.startDate): g,
    };

    for (final start in _expectedPeriodStarts()) {
      final key = _periodKey(start);
      byStart.putIfAbsent(
        key,
        () => ActivityGroup(
          label: _periodLabel(start),
          activities: const [],
          startDate: start,
        ),
      );
    }

    final merged = byStart.values.toList()
      ..sort((a, b) => b.startDate.compareTo(a.startDate));
    return merged;
  }

  String _periodKey(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  List<DateTime> _expectedPeriodStarts() {
    final now = DateTime.now();
    final starts = <DateTime>[];
    final current = _cutoffFor(_timeframe);

    for (int i = 0; i < _loadedPeriods; i++) {
      if (_timeframe == Timeframe.week) {
        starts.add(current.subtract(Duration(days: i * 7)));
      } else if (_timeframe == Timeframe.month) {
        starts.add(DateTime(now.year, now.month - i, 1));
      } else {
        starts.add(DateTime(now.year - i, 1, 1));
      }
    }
    return starts;
  }

  String _periodLabel(DateTime start) {
    if (_timeframe == Timeframe.week) {
      final end = start.add(const Duration(days: 6));
      return 'Week ${DateFormat('MMM d').format(start)} - ${DateFormat('MMM d, yyyy').format(end)}';
    }
    if (_timeframe == Timeframe.month) {
      return DateFormat('MMMM yyyy').format(start);
    }
    return DateFormat('yyyy').format(start);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('RunAnalyze (Basic)')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('RunAnalyze (Basic)')),
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
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton(
                    onPressed: () => _loadActivities(
                      cutoff: _cutoffFor(_timeframe, periods: _loadedPeriods),
                    ),
                    child: const Text('Retry'),
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton(
                    onPressed: _goHomeFromError,
                    child: const Text('Home'),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    final filtered = _filtered();
    final groups = _getGroups();

    return Scaffold(
      appBar: AppBar(
        title: const Text('RunAnalyze (Basic)'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: _openSettingsDialog,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Full refresh',
            onPressed: _fullRefresh,
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
                  onSelected: (_) => _switchTimeframe(Timeframe.week),
                ),
                ChoiceChip(
                  label: const Text('Month'),
                  selected: _timeframe == Timeframe.month,
                  onSelected: (_) => _switchTimeframe(Timeframe.month),
                ),
                ChoiceChip(
                  label: const Text('Year'),
                  selected: _timeframe == Timeframe.year,
                  onSelected: (_) => _switchTimeframe(Timeframe.year),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Text('Activity:'),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _sportFilter,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                    items: _sportOptions()
                        .map(
                          (sport) => DropdownMenuItem<String>(
                            value: sport,
                            child: Text(sport),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() => _sportFilter = value);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Grouped infinite activity list
            Expanded(
              child: Card(
                child: Column(
                  children: [
                    const Padding(
                      padding: EdgeInsets.fromLTRB(12, 10, 12, 6),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 4,
                            child: Text(
                              'Date',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                          Expanded(
                            flex: 3,
                            child: Text(
                              'Distance',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                          Expanded(
                            flex: 3,
                            child: Text(
                              'Pace',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                          SizedBox(
                            width: 28,
                            child: Text(
                              ' ',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    Expanded(
                      child: groups.isEmpty
                          ? const Center(child: Text('No activities found'))
                          : ListView.builder(
                              controller: _scrollController,
                              itemCount: groups.length + (_hasMorePeriods() ? 1 : 0),
                              itemBuilder: (context, idx) {
                                if (idx == groups.length && _hasMorePeriods()) {
                                  if (!_loadingMore && !_queuedLoadMoreFromPlaceholder) {
                                    _queuedLoadMoreFromPlaceholder = true;
                                    WidgetsBinding.instance.addPostFrameCallback((_) async {
                                      if (!mounted) return;
                                      await _loadMorePeriods();
                                      _queuedLoadMoreFromPlaceholder = false;
                                    });
                                  }

                                  return InkWell(
                                    onTap: _loadingMore ? null : _loadMorePeriods,
                                    child: Padding(
                                      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            flex: 4,
                                            child: Text(
                                              _periodLabel(_nextPeriodStart()),
                                              style: const TextStyle(
                                                fontSize: 13,
                                                color: Colors.grey,
                                              ),
                                            ),
                                          ),
                                          const Expanded(
                                            flex: 3,
                                            child: Text('...', style: TextStyle(color: Colors.grey)),
                                          ),
                                          const Expanded(
                                            flex: 3,
                                            child: Text('...', style: TextStyle(color: Colors.grey)),
                                          ),
                                          SizedBox(
                                            width: 28,
                                            child: _loadingMore
                                                ? const SizedBox(
                                                    width: 16,
                                                    height: 16,
                                                    child: CircularProgressIndicator(strokeWidth: 2),
                                                  )
                                                : const Icon(
                                                    Icons.hourglass_top,
                                                    size: 16,
                                                    color: Colors.grey,
                                                  ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                }
                                return _GroupCard(
                                  group: groups[idx],
                                  distanceUnit: _distanceUnit,
                                );
                              },
                            ),
                    ),
                  ],
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

  double _distanceForUnit(double kilometers) {
    return _distanceUnit == DistanceUnit.km ? kilometers : kilometers * _kmToMiles;
  }

  double _paceForUnit(double minPerKm) {
    return _distanceUnit == DistanceUnit.km ? minPerKm : minPerKm / _kmToMiles;
  }

  String _distanceLabel() {
    return _distanceUnit == DistanceUnit.km ? 'km' : 'mi';
  }

  String _formatPace(double minPerKm) {
    final minPerUnit = _paceForUnit(minPerKm);
    if (minPerUnit <= 0) {
      return '--:-- min/${_distanceLabel()}';
    }

    final totalSeconds = (minPerUnit * 60).round();
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    final secondsPadded = seconds.toString().padLeft(2, '0');
    return '${minutes}:${secondsPadded} min/${_distanceLabel()}';
  }
}

class _GroupCard extends StatefulWidget {
  final ActivityGroup group;
  final DistanceUnit distanceUnit;

  const _GroupCard({
    Key? key,
    required this.group,
    required this.distanceUnit,
  }) : super(key: key);

  @override
  State<_GroupCard> createState() => _GroupCardState();
}

class _GroupCardState extends State<_GroupCard> {
  bool _expanded = false;
  static const double _kmToMiles = 0.621371;

  @override
  Widget build(BuildContext context) {
    final rangeLabel = _groupDateRangeLabel();
    final isEmptyGroup = widget.group.activities.isEmpty;
    final distanceLabel = isEmptyGroup
      ? '0 ${_distanceLabel()}'
      : '${_distanceForUnit(widget.group.totalDistance).toStringAsFixed(1)} ${_distanceLabel()}';
    final paceLabel = isEmptyGroup ? '0' : _formatPace(widget.group.averagePace);

    return Column(
      children: [
        InkWell(
          onTap: () => setState(() => _expanded = !_expanded),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            child: Row(
              children: [
                Expanded(
                  flex: 4,
                  child: Text(
                    '$rangeLabel (${widget.group.count})',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Text(
                    distanceLabel,
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Text(
                    paceLabel,
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
                SizedBox(
                  width: 28,
                  child: Icon(
                    _expanded ? Icons.expand_less : Icons.expand_more,
                    size: 18,
                  ),
                ),
              ],
            ),
          ),
        ),
        const Divider(height: 1),
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
                      '${activity.sport}${activity.type != null ? ' • ${activity.type}' : ''} • ${_distanceForUnit(activity.distance).toStringAsFixed(1)} ${_distanceLabel()}',
                      style: const TextStyle(fontSize: 14),
                    ),
                    subtitle: Text(
                      '${DateFormat('MMM d, EEE').format(activity.dateTime)} • ${activity.formatDuration()}',
                      style: const TextStyle(fontSize: 11),
                    ),
                    trailing: Text(
                      _formatPace(activity.paceMinPerKm),
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

  String _groupDateRangeLabel() {
    return widget.group.label;
  }

  String _formatDuration(int seconds) {
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }
    return '${minutes}m';
  }

  double _distanceForUnit(double kilometers) {
    return widget.distanceUnit == DistanceUnit.km ? kilometers : kilometers * _kmToMiles;
  }

  String _distanceLabel() {
    return widget.distanceUnit == DistanceUnit.km ? 'km' : 'mi';
  }

  String _formatPace(double minPerKm) {
    final minPerUnit = widget.distanceUnit == DistanceUnit.km
        ? minPerKm
        : minPerKm / _kmToMiles;

    if (minPerUnit <= 0) {
      return '--:-- min/${_distanceLabel()}';
    }

    final totalSeconds = (minPerUnit * 60).round();
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    final secondsPadded = seconds.toString().padLeft(2, '0');
    return '${minutes}:${secondsPadded} min/${_distanceLabel()}';
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
  final DistanceUnit distanceUnit;
  static const double _kmToMiles = 0.621371;

  const _MiniChart({
    Key? key,
    required this.activities,
    required this.distanceUnit,
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
      (i) => FlSpot(
        i.toDouble(),
        _distanceForUnit(entries[i].value),
      ),
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
              gridData: FlGridData(show: false),
              titlesData: FlTitlesData(show: false),
              borderData: FlBorderData(show: false),
              lineBarsData: [
                LineChartBarData(
                  spots: spots,
                  isCurved: true,
                  dotData: FlDotData(show: false),
                  color: Colors.blue,
                )
              ],
            ),
          ),
        ),
      ),
    );
  }

  double _distanceForUnit(double kilometers) {
    return distanceUnit == DistanceUnit.km ? kilometers : kilometers * _kmToMiles;
  }
}
