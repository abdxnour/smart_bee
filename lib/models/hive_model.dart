import 'package:intl/intl.dart';

/// Data model representing the most recent status of a beehive.
/// Handles parsing logic and determines if a hive is currently 'offline'.
class HiveLatestData {
  /// Temperature in Celsius
  final double temp;
  
  /// Humidity percentage (0-100)
  final double hum;
  
  /// The exact timestamp of the last reading
  final DateTime lastUpdate;
  
  /// Boolean indicating if the hive has missed more than 30 minutes of updates
  final bool isOffline;
  
  /// Formatted string of the last update time (HH:mm)
  final String lastTimeStr;

  HiveLatestData({
    required this.temp,
    required this.hum,
    required this.lastUpdate,
    required this.isOffline,
    required this.lastTimeStr,
  });

  /// Factory to create a [HiveLatestData] instance from a Firebase Map.
  /// Handles potential parsing errors and provides default values.
  factory HiveLatestData.fromMap(Map data) {
    DateTime lastUpdate;
    bool isOffline = true;
    String lastTimeStr = "--:--";
    double temp = 0;
    double hum = 0;

    try {
      // Parsing logic for 'date' (YYYY-MM-DD) and 'time' (HH:mm:ss) from Firebase
      lastUpdate = DateTime.parse("${data['date']} ${data['time']}");
      
      // A hive is considered offline if no data has been received for over 30 minutes.
      isOffline = DateTime.now().difference(lastUpdate).inMinutes > 30;
      
      lastTimeStr = DateFormat('HH:mm').format(lastUpdate);
      temp = double.tryParse(data['temp'].toString()) ?? 0;
      hum = double.tryParse(data['hum'].toString()) ?? 0;
    } catch (e) {
      // Fallback values if parsing fails
      lastUpdate = DateTime.now();
      isOffline = true;
    }

    return HiveLatestData(
      temp: temp,
      hum: hum,
      lastUpdate: lastUpdate,
      isOffline: isOffline,
      lastTimeStr: lastTimeStr,
    );
  }
}
