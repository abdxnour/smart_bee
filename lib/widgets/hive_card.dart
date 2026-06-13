import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/app_colors.dart';
import '../core/lang.dart';
import '../models/hive_model.dart';
import '../screens/history_page.dart';

class HiveCard extends StatefulWidget {
  final String hiveId;
  const HiveCard({super.key, required this.hiveId});

  @override
  State<HiveCard> createState() => _HiveCardState();
}

class _HiveCardState extends State<HiveCard> {
  Future<Map?>? _cacheFuture;
  String? _lastSavedJson;

  @override
  void initState() {
    super.initState();
    _cacheFuture = _loadCachedData();
  }

  @override
  void didUpdateWidget(HiveCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.hiveId != widget.hiveId) {
      setState(() {
        _cacheFuture = _loadCachedData();
        _lastSavedJson = null;
      });
    }
  }

  Future<void> _saveToCache(Map data) async {
    final jsonStr = json.encode(data);
    if (jsonStr == _lastSavedJson) return; 
    
    _lastSavedJson = jsonStr;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('cache_${widget.hiveId}', jsonStr);
  }

  Future<Map?> _loadCachedData() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString('cache_${widget.hiveId}');
    if (jsonStr != null) {
      try {
        _lastSavedJson = jsonStr;
        return json.decode(jsonStr);
      } catch (e) {
        return null;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBgColor = isDark ? Theme.of(context).cardColor : Colors.grey[100];

    return Container(
      decoration: BoxDecoration(
        color: cardBgColor,
        borderRadius: BorderRadius.circular(25),
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.05),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black.withOpacity(0.3) : Colors.grey.withOpacity(0.2),
            blurRadius: 12,
            offset: const Offset(0, 6),
          )
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(25),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => HistoryPage(hiveId: widget.hiveId)),
          ),
          child: StreamBuilder(
            stream: FirebaseDatabase.instance.ref("hives/${widget.hiveId}/latest").onValue,
            builder: (context, snapshot) {
              return StreamBuilder(
                stream: FirebaseDatabase.instance.ref("settings").onValue,
                builder: (context, settingsSnapshot) {
                  return FutureBuilder<Map?>(
                    future: _cacheFuture,
                    builder: (context, cacheSnapshot) {
                      final dynamic value = snapshot.data?.snapshot.value;
                      final Map? remoteData = value is Map ? value : null;

                      if (remoteData != null) {
                        _saveToCache(remoteData);
                      }

                      final rawData = remoteData ?? cacheSnapshot.data;

                      if (rawData == null) {
                        return const Center(child: CircularProgressIndicator(strokeWidth: 2));
                      }

                      final data = HiveLatestData.fromMap(rawData);

                      // Fetch threshold settings from Firebase
                      double tMax = 38.0;
                      double tMin = 10.0;
                      double hMax = 80.0;
                      double hMin = 30.0;
                      
                      final settingsValue = settingsSnapshot.data?.snapshot.value;
                      if (settingsValue is Map) {
                        tMax = double.tryParse(settingsValue['temp_max']?.toString() ?? '38.0') ?? 38.0;
                        tMin = double.tryParse(settingsValue['temp_min']?.toString() ?? '10.0') ?? 10.0;
                        hMax = double.tryParse(settingsValue['hum_max']?.toString() ?? '80.0') ?? 80.0;
                        hMin = double.tryParse(settingsValue['hum_min']?.toString() ?? '30.0') ?? 30.0;
                      }

                      // Temperature icon and color logic
                      IconData tempIcon = Icons.thermostat;
                      Color tempColor = AppColors.temp;
                      bool isTempCritical = false;

                      if (data.temp > tMax) {
                        tempIcon = Icons.whatshot; // Heat alert
                        tempColor = Colors.redAccent;
                        isTempCritical = true;
                      } else if (data.temp < tMin) {
                        tempIcon = Icons.ac_unit; // Cold alert
                        tempColor = Colors.lightBlue;
                        isTempCritical = true;
                      }

                      // Humidity icon and color logic
                      IconData humIcon = Icons.water_drop;
                      Color humColor = AppColors.hum;
                      bool isHumCritical = false;

                      if (data.hum > hMax) {
                        humIcon = Icons.water; // High humidity
                        humColor = Colors.blue;
                        isHumCritical = true;
                      } else if (data.hum < hMin) {
                        humIcon = Icons.wb_sunny_outlined; // Dryness/Low humidity
                        humColor = Colors.orange;
                        isHumCritical = true;
                      }

                      bool isAnyCritical = isTempCritical || isHumCritical;
                      Color borderColor = isTempCritical ? tempColor : (isHumCritical ? humColor : Colors.transparent);

                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 500),
                        padding: const EdgeInsets.all(16.0),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(25),
                          border: isAnyCritical ? Border.all(color: borderColor.withOpacity(0.5), width: 2) : null,
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    widget.hiveId,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                      color: isAnyCritical ? borderColor : null,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Icon(Icons.circle, size: 10, color: data.isOffline ? AppColors.offline : AppColors.online),
                              ],
                            ),
                            Expanded(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(tempIcon, color: tempColor, size: 26),
                                      Text("${data.temp}°", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: tempColor)),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(humIcon, color: humColor, size: 22),
                                      Text("${data.hum}%", style: TextStyle(fontSize: 20, fontWeight: FontWeight.w500, color: humColor)),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              data.isOffline ? Lang.t(context, 'offline') : "${Lang.t(context, 'updated')} ${data.lastTimeStr}",
                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: data.isOffline ? Colors.red[300] : Colors.grey[500]),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}
