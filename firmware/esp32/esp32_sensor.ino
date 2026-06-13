#include <WiFi.h>
#include <WiFiClientSecure.h>
#include <HTTPClient.h>
#include <DHT.h>
#include <LittleFS.h>
#include <time.h>
#include <cstring>
#include <esp_pm.h>
#include <esp_sleep.h>

// ================================================================
// 0. User Configuration (Sensitive Data)
// ================================================================
// WiFi Credentials
const char* ssid     = "YOUR_WIFI_SSID";         // Replace with your WiFi Name
const char* password = "YOUR_WIFI_PASSWORD";     // Replace with your WiFi Password

// Firebase Configuration
const String FIREBASE_HOST = "your-project.firebasedatabase.app";
const String FIREBASE_AUTH = "your-firebase-database-secret";

// Google Sheets / Apps Script Configuration
const String GOOGLE_SCRIPT_URL = "https://script.google.com/macros/s/your-script-id/exec";

// ================================================================
// 1. Fixed Settings
// ================================================================
#define DHTPIN  4
#define DHTTYPE DHT22
DHT dht(DHTPIN, DHTTYPE);

const String STATION_ID = "HIVE_01";

#define DEFAULT_SLEEP_SEC 300
#define uS_TO_S_FACTOR 1000000ULL
#define TIME_SYNC_TIMEOUT_SEC 10

// ================================================================
// 2. Global Variables (Normal) - No RTC storage
// ================================================================
float rtc_t_max = 35.0, rtc_t_min = 15.0;
float rtc_h_max = 80.0, rtc_h_min = 30.0;
bool rtc_alerts_enabled = true;

// ================================================================
// 3. Helper Functions
// ================================================================
String getFormattedTime(time_t rawtime) {
  struct tm* ti = localtime(&rawtime);
  char buf[25];
  strftime(buf, sizeof(buf), "%Y-%m-%d %H:%M:%S", ti);
  return String(buf);
}

float extractFloat(const String& json, const char* key) {
  String search = "\"" + String(key) + "\":";
  int pos = json.indexOf(search);
  if (pos == -1) return 0;
  pos += search.length();
  int end = json.indexOf(",", pos);
  if (end == -1) end = json.indexOf("}", pos);
  if (end == -1) end = json.length();
  return json.substring(pos, end).toFloat();
}

bool extractBool(const String& json, const char* key) {
  String search = "\"" + String(key) + "\":";
  int pos = json.indexOf(search);
  if (pos == -1) return false;
  pos += search.length();
  while (json[pos] == ' ') pos++;
  if (json.substring(pos, pos+4) == "true") return true;
  if (json.substring(pos, pos+5) == "false") return false;
  int val = json.substring(pos).toInt();
  return (val == 1);
}

// ================================================================
// 4. Calculate Sleep Time until Next 5-Minute Interval
// ================================================================
unsigned long calculateSleepSeconds() {
  time_t now = time(nullptr);
  struct tm* tm_info = localtime(&now);
  int current_minute = tm_info->tm_min;
  int target_minute = ((current_minute / 5) + 1) * 5;
  int target_hour = tm_info->tm_hour;
  if (target_minute == 60) {
    target_minute = 0;
    target_hour = (target_hour + 1) % 24;
  }
  struct tm target_tm = *tm_info;
  target_tm.tm_min = target_minute;
  target_tm.tm_sec = 0;
  target_tm.tm_hour = target_hour;
  time_t target_time = mktime(&target_tm);
  long remaining = difftime(target_time, now);
  if (remaining <= 0) remaining = DEFAULT_SLEEP_SEC;
  Serial.printf("⏰ Next target: %02d:%02d:00, Sleeping %ld sec\n", target_hour, target_minute, remaining);
  return (unsigned long)remaining;
}

// ================================================================
// 5. Time Sync and Firebase Settings Fetching
// ================================================================
bool waitForTimeSync() {
  configTime(3600, 0, "pool.ntp.org");
  Serial.print("⏳ Syncing Time");
  unsigned long start = millis();
  time_t now = time(nullptr);
  while (now < 1600000000 && (millis() - start) < (TIME_SYNC_TIMEOUT_SEC * 1000)) {
    delay(200);
    Serial.print(".");
    now = time(nullptr);
  }
  if (now > 1600000000) {
    Serial.println(" ✅");
    return true;
  } else {
    Serial.println(" ❌ Failed");
    return false;
  }
}

void fetchSettingsFromFirebase() {
  WiFiClientSecure client;
  client.setInsecure();
  HTTPClient http;
  String url = "https://" + FIREBASE_HOST + "/settings.json?auth=" + FIREBASE_AUTH;
  http.begin(client, url);
  int code = http.GET();
  if (code == 200) {
    String payload = http.getString();
    rtc_t_max = extractFloat(payload, "temp_max");
    rtc_t_min = extractFloat(payload, "temp_min");
    rtc_h_max = extractFloat(payload, "hum_max");
    rtc_h_min = extractFloat(payload, "hum_min");
    rtc_alerts_enabled = extractBool(payload, "notifications_enabled");
    Serial.printf("📢 Settings: t_max=%.1f t_min=%.1f h_max=%.1f h_min=%.1f alerts=%s\n",
                  rtc_t_max, rtc_t_min, rtc_h_max, rtc_h_min, rtc_alerts_enabled ? "ON" : "OFF");
  } else {
    Serial.printf("⚠️ Failed to fetch settings, HTTP %d\n", code);
  }
  http.end();
}

// ================================================================
// 6. Data Sending Functions
// ================================================================
bool sendToSheets(String mode, float t, float h, String datePart, String timePart,
                  String t_stat = "", String h_stat = "") {
  WiFiClientSecure client;
  client.setInsecure();
  HTTPClient http;
  String url = GOOGLE_SCRIPT_URL + "?mode=" + mode + "&hive=" + STATION_ID +
               "&temp=" + String(t, 1) + "&hum=" + String(h, 1) +
               "&date=" + datePart + "&time=" + timePart;
  if (mode == "alert") {
    url += "&t_stat=" + t_stat + "&h_stat=" + h_stat;
  }
  http.begin(client, url);
  http.setFollowRedirects(HTTPC_STRICT_FOLLOW_REDIRECTS);
  http.setTimeout(10000);
  int code = http.GET();
  http.end();

  if (code == 200 || code == 302) {
    Serial.println("📤 Data sent to Google Sheets (" + mode + ")");
    return true;
  } else if (code == -11) {
    Serial.println("⚠️ HTTP -11 but data likely reached Sheets, considering success.");
    return true;
  } else {
    Serial.printf("❌ Failed to send to Google Sheets, HTTP %d\n", code);
    return false;
  }
}

void updateFirebaseLatest(float t, float h, String datePart, String timePart) {
  WiFiClientSecure client;
  client.setInsecure();
  HTTPClient http;
  String payload = "{\"temp\":" + String(t, 1) +
                   ",\"hum\":" + String(h, 1) +
                   ",\"date\":\"" + datePart +
                   "\",\"time\":\"" + timePart + "\"}";
  String url = "https://" + FIREBASE_HOST + "/hives/" + STATION_ID + "/latest.json?auth=" + FIREBASE_AUTH;
  http.begin(client, url);
  int code = http.PUT(payload);
  if (code == 200) Serial.println("🔥 Firebase updated");
  else Serial.println("❌ Firebase update failed");
  http.end();
}

// ================================================================
// 7. Alert Checks
// ================================================================
void checkAndNotify(float t, float h, String datePart, String timePart) {
  if (!rtc_alerts_enabled) {
    Serial.println("🔕 Alerts disabled by settings");
    return;
  }
  String t_stat = "", h_stat = "";
  if (t > rtc_t_max) t_stat = "high";
  else if (t < rtc_t_min) t_stat = "low";
  if (h > rtc_h_max) h_stat = "high";
  else if (h < rtc_h_min) h_stat = "low";
  if (t_stat == "" && h_stat == "") {
    Serial.println("✅ Within thresholds, no alert");
    return;
  }
  Serial.printf("⚠️ Threshold exceeded! t_stat=%s h_stat=%s\n", t_stat.c_str(), h_stat.c_str());
  if (sendToSheets("alert", t, h, datePart, timePart, t_stat, h_stat))
    Serial.println("🚨 Alert sent!");
  else
    Serial.println("❌ Alert sending failed");
}

// ================================================================
// 8. Backlog
// ================================================================
void appendToBacklog(float t, float h, String timestamp) {
  File f = LittleFS.open("/backlog.csv", FILE_APPEND);
  if (f) {
    f.printf("%s,%.1f,%.1f\n", timestamp.c_str(), t, h);
    f.close();
    Serial.println("💾 Saved to backlog");
  } else {
    Serial.println("❌ Failed to open backlog for writing");
  }
}

void replayBacklog() {
  if (!LittleFS.exists("/backlog.csv")) return;
  File f = LittleFS.open("/backlog.csv", FILE_READ);
  if (!f) return;
  String remainingLines;
  int sentCount = 0;
  while (f.available() && sentCount < 5) {
    String line = f.readStringUntil('\n');
    if (line.length() == 0) continue;
    int firstComma = line.indexOf(',');
    int secondComma = line.indexOf(',', firstComma + 1);
    if (firstComma == -1 || secondComma == -1) continue;
    String timestamp = line.substring(0, firstComma);
    float bt = line.substring(firstComma + 1, secondComma).toFloat();
    float bh = line.substring(secondComma + 1).toFloat();
    String datePart = timestamp.substring(0, 10);
    String timePart = timestamp.substring(11, 19);
    if (sendToSheets("direct", bt, bh, datePart, timePart)) {
      sentCount++;
      updateFirebaseLatest(bt, bh, datePart, timePart);
      Serial.println("📤 Backlog entry sent");
    } else {
      remainingLines += line + "\n";
    }
  }
  while (f.available()) {
    remainingLines += f.readStringUntil('\n') + "\n";
  }
  f.close();
  LittleFS.remove("/backlog.csv");
  if (remainingLines.length() > 0) {
    File f2 = LittleFS.open("/backlog.csv", FILE_WRITE);
    if (f2) {
      f2.print(remainingLines);
      f2.close();
    }
  }
}

// ================================================================
// 9. Sensor Reading
// ================================================================
bool readDHT22(float &t, float &h) {
  delay(200);
  t = dht.readTemperature();
  h = dht.readHumidity();
  if (isnan(t) || isnan(h)) {
    Serial.println("❌ DHT22 read error!");
    return false;
  }
  Serial.printf("🌡️ Temp: %.1f°C  💧 Hum: %.1f%%\n", t, h);
  return true;
}

// ================================================================
// 10. Power Saving Enhancements
// ================================================================
void configurePowerSaving() {
  setCpuFrequencyMhz(80);
  WiFi.setSleep(true);
  WiFi.setTxPower( WIFI_POWER_8_5dBm);  // Balance between power and range
  delay(500);
  Serial.println("🔋 Power saving ENABLED (CPU 80MHz, WiFi sleep ON, TX power 8.5dBm)");
}
// ================================================================
// 11. Deep Sleep
// ================================================================
void goToDeepSleep() {
  WiFi.disconnect(true);
  WiFi.mode(WIFI_OFF);
  delay(100);
  unsigned long sleepSec = DEFAULT_SLEEP_SEC;
  time_t now = time(nullptr);
  if (now > 1600000000) {
    sleepSec = calculateSleepSeconds();
  } else {
    Serial.println("⚠️ Time not synced, using fixed sleep interval");
  }
  Serial.printf("😴 Sleeping for %lu seconds\n", sleepSec);
  esp_sleep_enable_timer_wakeup(sleepSec * uS_TO_S_FACTOR);
  esp_deep_sleep_start();
}

// ================================================================
// 12. Main Setup
// ================================================================
void setup() {
  Serial.begin(115200);
  configurePowerSaving();
  delay(1000);
  Serial.println("\n🚀 Hive Sensor Starting (Simplified, No RTC)");

  dht.begin();
  if (!LittleFS.begin(true)) Serial.println("⚠️ LittleFS mount failed, formatting...");

  float temperature, humidity;
  if (!readDHT22(temperature, humidity)) goToDeepSleep();

  WiFi.begin(ssid, password);
  Serial.print("📡 Connecting to WiFi");
  int retry = 0;
  while (WiFi.status() != WL_CONNECTED && retry < 20) {
    delay(500);
    Serial.print(".");
    retry++;
  }
  Serial.println();

  if (WiFi.status() == WL_CONNECTED) {
    Serial.println("✅ WiFi connected");
    bool timeOk = waitForTimeSync();
    String datePart, timePart;
    time_t now = time(nullptr);
    if (timeOk) {
      String fullTS = getFormattedTime(now);
      datePart = fullTS.substring(0, 10);
      timePart = fullTS.substring(11, 19);
    } else {
      datePart = "1970-01-01";
      timePart = "00:00:00";
      Serial.println("⚠️ Using dummy timestamp");
    }

    // Always fetch settings from Firebase
    fetchSettingsFromFirebase();

    replayBacklog();
    updateFirebaseLatest(temperature, humidity, datePart, timePart);
    bool sent = sendToSheets("direct", temperature, humidity, datePart, timePart);
    if (!sent) appendToBacklog(temperature, humidity, datePart + " " + timePart);
    checkAndNotify(temperature, humidity, datePart, timePart);
  } else {
    Serial.println("❌ WiFi not connected");
    appendToBacklog(temperature, humidity, "1970-01-01 00:00:00");
  }
  goToDeepSleep();
}

void loop() {}
