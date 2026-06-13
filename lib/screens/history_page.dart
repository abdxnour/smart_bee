import 'dart:async';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:table_calendar/table_calendar.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../core/app_colors.dart';
import '../core/lang.dart';

class DataPoint {
  final DateTime time;
  final double value;
  DataPoint(this.time, this.value);
}

class HistoryPage extends StatefulWidget {
  final String hiveId;
  const HistoryPage({super.key, required this.hiveId});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  List<DataPoint> _tempData = [];
  List<DataPoint> _humData = [];
  bool _isLoading = false;
  String _error = "";
  bool _isOnline = true;
  bool _showOnlineGreen = false;
  Timer? _onlineTimer;

  // Stream subscription for Firebase listener
  StreamSubscription? _connectionSubscription;

  // Track the touched/selected spot for highlighting
  double? _touchedX;

  // Published CSV URL containing recorded data
  final String csvUrl = "https://docs.google.com/spreadsheets/d/e/2PACX-1vSstXZhF_KGVxT6LD5FnFirmZRhDI0FmaqE3qye5yjzRqQc6FXjJw_n11CHUsmTmCNhlogNuFsnUnbb/pub?output=csv";

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    _listenToConnection();
    _fetchDataDirectly(_selectedDay!);
  }

  void _listenToConnection() {
    FirebaseDatabase.instance.ref(".info/connected").get().then((snapshot) {
      final connected = snapshot.value as bool? ?? false;
      if (mounted) setState(() => _isOnline = connected);
    });

    _connectionSubscription = FirebaseDatabase.instance.ref(".info/connected").onValue.listen((event) {
      final connected = event.snapshot.value as bool? ?? false;
      if (mounted) {
        if (!_isOnline && connected) {
          setState(() { _isOnline = true; _showOnlineGreen = true; });
          _onlineTimer?.cancel();
          _onlineTimer = Timer(const Duration(seconds: 3), () {
            if (mounted) setState(() => _showOnlineGreen = false);
          });
        } else {
          setState(() => _isOnline = connected);
        }
      }
    });
  }

  @override
  void dispose() {
    _onlineTimer?.cancel();
    _connectionSubscription?.cancel();
    super.dispose();
  }

  double? _smartParse(dynamic input) {
    if (input == null) return null;
    try {
      // Handle both Arabic decimal separator '٫' and standard '.' for correct parsing
      String clean = input.toString().trim()
          .replaceAll('٫', '.')
          .replaceAll(',', '.');
      return double.tryParse(clean);
    } catch (e) { return null; }
  }

  Future<void> _fetchDataDirectly(DateTime day) async {
    if (!mounted) return;
    setState(() { _isLoading = true; _error = ""; });

    try {
      final response = await http.get(Uri.parse(csvUrl));
      if (response.statusCode != 200) throw Exception("Failed");

      final fullBody = utf8.decode(response.bodyBytes);
      final lines = fullBody.split(RegExp(r'\r?\n'));
      
      final ty = day.year;
      final tm = day.month;
      final td = day.day;

      // List of possible date formats for flexible matching
      final possibleDates = {
        DateFormat('yyyy-MM-dd').format(day),
        DateFormat('d/M/yyyy').format(day),
        DateFormat('M/d/yyyy').format(day),
        DateFormat('dd/MM/yyyy').format(day),
        DateFormat('MM/dd/yyyy').format(day),
        DateFormat('yyyy/MM/dd').format(day),
        DateFormat('d-M-yyyy').format(day),
        DateFormat('dd-MM-yyyy').format(day),
      };

      List<DataPoint> tList = [];
      List<DataPoint> hList = [];

      for (int i = 1; i < lines.length; i++) {
        final row = lines[i].split(',');
        if (row.length < 5) continue;

        final rowDateStr = row[0].trim().replaceAll('"', '');
        final rowHiveId = row[2].trim().replaceAll('"', '').toUpperCase();
        
        if (rowHiveId != widget.hiveId.toUpperCase()) continue;

        bool dateMatch = possibleDates.contains(rowDateStr);

        // Additional matching attempt for different date formats
        if (!dateMatch) {
          try {
             var parts = rowDateStr.split(RegExp(r'[/-]'));
             if (parts.length == 3) {
               int p0 = int.parse(parts[0]);
               int p1 = int.parse(parts[1]);
               int p2 = int.parse(parts[2]);
               if (p2 < 100) p2 += 2000;
               // Check year first then day/month or month/day combinations
               if (p2 == ty && ((p0 == td && p1 == tm) || (p1 == td && p0 == tm))) {
                 dateMatch = true;
               }
             }
          } catch (_) {}
        }

        if (dateMatch) {
          try {
            final tStr = row[1].trim().replaceAll('"', '');
            // Improve time handling for various formats (e.g., 14:30, 02:30 PM, or 14:30:05)
            String cleanTime = tStr.split(' ')[0]; // Time part
            final tParts = cleanTime.split(':');
            if (tParts.length < 2) continue;
            
            int hour = int.parse(tParts[0]);
            int minute = int.parse(tParts[1]);

            if (tStr.toUpperCase().contains("PM") && hour < 12) hour += 12;
            if (tStr.toUpperCase().contains("AM") && hour == 12) hour = 0;

            final time = DateTime(ty, tm, td, hour, minute);
            
            double? temp = _smartParse(row[3]);
            double? hum = _smartParse(row[4]);
            if (temp != null && hum != null) {
              tList.add(DataPoint(time, temp));
              hList.add(DataPoint(time, hum));
            }
          } catch (e) { continue; }
        }
      }

      if (mounted) {
        setState(() {
          // Sort data by time to ensure correct line rendering
          _tempData = tList..sort((a, b) => a.time.compareTo(b.time));
          _humData = hList..sort((a, b) => a.time.compareTo(b.time));
          if (_tempData.isEmpty) _error = Lang.t(context, 'no_records');
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = Lang.t(context, 'connection_error'));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDarkMode ? null : AppColors.backgroundLight,
      appBar: AppBar(
        title: Text("${widget.hiveId} ${Lang.t(context, 'analysis')}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        actions: [IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: () => _fetchDataDirectly(_selectedDay!))],
      ),
      body: Column(
        children: [
          if (!_isOnline || _showOnlineGreen)
            Container(
              height: 32, width: double.infinity,
              color: _isOnline ? Colors.green : Colors.redAccent,
              child: Center(child: Text(_isOnline ? Lang.t(context, 'online_mode') : Lang.t(context, 'offline_mode'), style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold))),
            ),
          _buildCalendar(),
          Expanded(child: _isLoading ? const Center(child: CircularProgressIndicator(color: AppColors.primary)) : _error.isNotEmpty ? _buildErrorView() : _buildDataView(isDarkMode)),
        ],
      ),
    );
  }

  Widget _buildCalendar() {
    final locale = Localizations.localeOf(context).languageCode;
    return Container(
      color: Theme.of(context).cardColor,
      child: TableCalendar(
        locale: locale == 'ar' ? 'ar_DZ' : 'en_US',
        firstDay: DateTime.utc(2023, 1, 1),
        lastDay: DateTime.now().add(const Duration(days: 1)),
        focusedDay: _focusedDay,
        calendarFormat: CalendarFormat.week,
        selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
        onDaySelected: (selectedDay, focusedDay) {
          setState(() { _selectedDay = selectedDay; _focusedDay = focusedDay; });
          _fetchDataDirectly(selectedDay);
        },
        headerStyle: const HeaderStyle(
          formatButtonVisible: false, 
          titleCentered: true,
          titleTextStyle: TextStyle(fontWeight: FontWeight.bold),
        ),
        calendarStyle: CalendarStyle(
          selectedDecoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
          todayDecoration: BoxDecoration(color: AppColors.primary.withOpacity(0.3), shape: BoxShape.circle),
          weekendTextStyle: const TextStyle(color: Colors.redAccent),
        ),
        daysOfWeekStyle: const DaysOfWeekStyle(
          weekendStyle: TextStyle(color: Colors.redAccent),
        ),
      ),
    );
  }

  Widget _buildErrorView() => Center(child: Text(_error, style: const TextStyle(color: Colors.grey)));

  Widget _buildDataView(bool isDarkMode) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          _buildStatSection(Lang.t(context, 'temp_label'), _tempData, AppColors.temp, "°C"),
          const SizedBox(height: 12),
          _buildStatSection(Lang.t(context, 'hum_label'), _humData, AppColors.hum, "%"),
          const SizedBox(height: 24),
          Align(alignment: Alignment.centerLeft, child: Text(Lang.t(context, 'trends_label'), style: const TextStyle(fontWeight: FontWeight.bold))),
          const SizedBox(height: 12),
          Container(
            height: 350,
            padding: const EdgeInsets.fromLTRB(10, 20, 25, 5),
            decoration: BoxDecoration(
              color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
            ),
            child: _buildChart(),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildStatSection(String title, List<DataPoint> data, Color color, String unit) {
    if (data.isEmpty) return const SizedBox();
    double avg = data.map((e) => e.value).reduce((a, b) => a + b) / data.length;
    double min = data.map((e) => e.value).reduce((a, b) => a < b ? a : b);
    double max = data.map((e) => e.value).reduce((a, b) => a > b ? a : b);
    return Row(
      children: [
        _statCard(Lang.t(context, 'min'), min, unit, color),
        const SizedBox(width: 8),
        _statCard(Lang.t(context, 'avg'), avg, unit, color),
        const SizedBox(width: 8),
        _statCard(Lang.t(context, 'max'), max, unit, color),
      ],
    );
  }

  Widget _statCard(String label, double value, String unit, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(15)),
        child: Column(children: [
          Text(label, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.bold)),
          Text("${value.toStringAsFixed(1)}$unit", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
        ]),
      ),
    );
  }

  Widget _buildChart() {
    if (_tempData.isEmpty && _humData.isEmpty) return const SizedBox();
    
    double getM(DateTime dt) => dt.hour * 60.0 + dt.minute;

    final allPoints = [..._tempData, ..._humData];
    if (allPoints.isEmpty) return const SizedBox();

    double minX = allPoints.map((e) => getM(e.time)).reduce((a, b) => a < b ? a : b);
    double maxX = allPoints.map((e) => getM(e.time)).reduce((a, b) => a > b ? a : b);
    double minY = allPoints.map((e) => e.value).reduce((a, b) => a < b ? a : b);
    double maxY = allPoints.map((e) => e.value).reduce((a, b) => a > b ? a : b);

    // Padding for axes
    minY = (minY - 2).clamp(0, 100);
    maxY = (maxY + 2).clamp(0, 100);

    if (minX == maxX) { minX -= 30; maxX += 30; }
    if (minY == maxY) { minY -= 5; maxY += 5; }

    return LineChart(
      LineChartData(
        minX: minX, 
        maxX: maxX,
        minY: minY, 
        maxY: maxY,
        clipData: const FlClipData.none(),
        lineTouchData: LineTouchData(
          handleBuiltInTouches: true,
          touchSpotThreshold: 20,
          touchCallback: (FlTouchEvent event, LineTouchResponse? touchResponse) {
            if (!mounted) return;
            
            final bool isInterested = event.isInterestedForInteractions && 
                                      touchResponse != null && 
                                      touchResponse.lineBarSpots != null && 
                                      touchResponse.lineBarSpots!.isNotEmpty;
            
            final double? newX = isInterested ? touchResponse.lineBarSpots!.first.x : null;
            
            if (newX != _touchedX) {
              setState(() => _touchedX = newX);
            }
          },
          getTouchedSpotIndicator: (LineChartBarData barData, List<int> spotIndexes) {
            return spotIndexes.map((index) {
              return TouchedSpotIndicatorData(
                const FlLine(color: Colors.transparent, strokeWidth: 0),
                FlDotData(
                  show: true,
                  getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(
                    radius: 6,
                    color: barData.color ?? Colors.blue,
                    strokeWidth: 2,
                    strokeColor: Colors.white,
                  ),
                ),
              );
            }).toList();
          },
          touchTooltipData: LineTouchTooltipData(
            tooltipBgColor: Colors.black.withOpacity(0.8),
            fitInsideHorizontally: true,
            fitInsideVertically: true,
            tooltipRoundedRadius: 8,
            getTooltipItems: (List<LineBarSpot> touchedSpots) {
              if (touchedSpots.isEmpty) return [];
              
              final double x = touchedSpots.first.x;
              final int hour = (x ~/ 60).toInt() % 24;
              final int minute = (x % 60).toInt();
              final timeStr = "${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}";

              return touchedSpots.map((spot) {
                final isTemp = spot.barIndex == 0;
                return LineTooltipItem(
                  spot == touchedSpots.first ? "$timeStr\n" : "",
                  const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                  children: [
                    TextSpan(
                      text: isTemp ? "🌡️ ${spot.y.toStringAsFixed(1)}°C" : "💧 ${spot.y.toStringAsFixed(1)}%",
                      style: TextStyle(color: isTemp ? AppColors.temp : AppColors.hum, fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                  ],
                );
              }).toList();
            },
          ),
        ),
        gridData: FlGridData(
          show: true, 
          drawVerticalLine: true,
          horizontalInterval: 10, 
          verticalInterval: 120, // Every 2 hours
          getDrawingHorizontalLine: (_) => FlLine(color: Colors.grey.withOpacity(0.1), strokeWidth: 1),
          getDrawingVerticalLine: (_) => FlLine(color: Colors.grey.withOpacity(0.1), strokeWidth: 1, dashArray: [5, 5]),
        ),
        borderData: FlBorderData(show: false),
        titlesData: const FlTitlesData(show: false),
        extraLinesData: ExtraLinesData(
          verticalLines: [
            if (_touchedX != null)
              VerticalLine(
                x: _touchedX!,
                color: Colors.red.withOpacity(0.4),
                strokeWidth: 2,
                dashArray: [5, 5],
              ),
          ],
        ),
        lineBarsData: [
          if (_tempData.isNotEmpty) _lineData(_tempData.map((p) => FlSpot(getM(p.time), p.value)).toList(), AppColors.temp),
          if (_humData.isNotEmpty) _lineData(_humData.map((p) => FlSpot(getM(p.time), p.value)).toList(), AppColors.hum),
        ],
      ),
      duration: Duration.zero,
    );
  }

  LineChartBarData _lineData(List<FlSpot> spots, Color color) => LineChartBarData(
    spots: spots, 
    isCurved: true, 
    curveSmoothness: 0.7, // تقليل النعومة قليلاً لتجنب أخطاء الرسم مع الحفاظ على الانسيابية
    preventCurveOverShooting: true,
    color: color, 
    barWidth: 3, 
    dotData: const FlDotData(show: false),
    belowBarData: BarAreaData(
      show: true, 
      gradient: LinearGradient(
        colors: [color.withOpacity(0.2), color.withOpacity(0.01)], 
        begin: Alignment.topCenter, 
        end: Alignment.bottomCenter
      ),
    ),
  );
}
