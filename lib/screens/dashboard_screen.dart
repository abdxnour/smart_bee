import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../core/app_colors.dart';
import '../core/lang.dart';
import '../widgets/app_logo.dart';
import '../widgets/hive_card.dart';
import '../widgets/summary_item.dart';
import '../main.dart';
import 'admin_settings_screen.dart';
import 'faq_page.dart';

class MainDashboard extends StatefulWidget {
  const MainDashboard({super.key});

  @override
  State<MainDashboard> createState() => _MainDashboardState();
}

class _MainDashboardState extends State<MainDashboard> with WidgetsBindingObserver {
  List<String> allowedHives = [];
  List<String> _allDiscoveredHives = [];
  bool _isLoadingAllHives = true;
  bool _isAdmin = false;
  bool _notificationsEnabled = false;
  bool _isOnline = true;
  bool _showOnlineGreen = false;
  Timer? _onlineTimer;

  bool _isNotifPermissionGranted = false;
  bool _isBatteryOptimizationIgnored = false;
  bool _isSetupDialogOpen = false;

  StreamSubscription? _connectionSubscription;
  StreamSubscription? _notificationsSubscription;
  StreamSubscription? _permissionsSubscription;

  static const platform = MethodChannel('com.example.hive/settings');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeData();
    _fetchNotificationSettings();
    _listenToConnection();
    _checkPermissionsAndShowDialog();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _onlineTimer?.cancel();
    _connectionSubscription?.cancel();
    _notificationsSubscription?.cancel();
    _permissionsSubscription?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkPermissionsAndShowDialog();
    }
  }

  Future<void> _checkPermissionsAndShowDialog() async {
    try {
      final bool notifs = await platform.invokeMethod('areNotificationsEnabled');
      final bool battery = await platform.invokeMethod('isBatteryOptimizationIgnored');

      if (mounted) {
        setState(() {
          _isNotifPermissionGranted = notifs;
          _isBatteryOptimizationIgnored = battery;
        });

        if ((!notifs || !battery) && !_isSetupDialogOpen) {
          _showSetupDialog();
        } else if (notifs && battery && _isSetupDialogOpen) {
          Navigator.of(context, rootNavigator: true).pop();
        }
      }
    } on PlatformException catch (e) {
      debugPrint("Permission check failed: ${e.message}");
    }
  }

  void _showSetupDialog() {
    _isSetupDialogOpen = true;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          // Listen to parent state changes or poll
          Timer.periodic(const Duration(seconds: 1), (timer) async {
            if (!context.mounted) {
              timer.cancel();
              return;
            }
            final bool n = await platform.invokeMethod('areNotificationsEnabled');
            final bool b = await platform.invokeMethod('isBatteryOptimizationIgnored');
            
            if (n != _isNotifPermissionGranted || b != _isBatteryOptimizationIgnored) {
              if (mounted) {
                setState(() {
                  _isNotifPermissionGranted = n;
                  _isBatteryOptimizationIgnored = b;
                });
              }
              setDialogState(() {});
              if (n && b) {
                timer.cancel();
                if (ctx.mounted) Navigator.pop(ctx);
              }
            }
          });

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
            title: Row(
              children: [
                const Icon(Icons.security, color: AppColors.primary),
                const SizedBox(width: 10),
                Text(Lang.t(context, 'setup_title'), style: const TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(Lang.t(context, 'setup_desc')),
                const SizedBox(height: 25),
                _buildPermissionItem(
                  icon: Icons.notifications_active,
                  label: Lang.t(context, 'enable_notif'),
                  isGranted: _isNotifPermissionGranted,
                  onTap: () async {
                    await FirebaseMessaging.instance.requestPermission();
                    _checkPermissionsAndShowDialog();
                  },
                ),
                const SizedBox(height: 15),
                _buildPermissionItem(
                  icon: Icons.battery_charging_full,
                  label: Lang.t(context, 'allow_background'),
                  isGranted: _isBatteryOptimizationIgnored,
                  onTap: () async {
                    try {
                      await platform.invokeMethod('openBatterySettings');
                    } catch (e) {
                      debugPrint(e.toString());
                    }
                  },
                ),
              ],
            ),
          );
        },
      ),
    ).then((_) => _isSetupDialogOpen = false);
  }

  Widget _buildPermissionItem({
    required IconData icon,
    required String label,
    required bool isGranted,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: isGranted ? null : onTap,
      borderRadius: BorderRadius.circular(15),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 15),
        decoration: BoxDecoration(
          color: isGranted ? Colors.green.withOpacity(0.1) : AppColors.primary.withOpacity(0.05),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: isGranted ? Colors.green : AppColors.primary.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Icon(icon, color: isGranted ? Colors.green : AppColors.primary),
            const SizedBox(width: 12),
            Expanded(child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold))),
            Icon(
              isGranted ? Icons.check_circle : Icons.arrow_forward_ios,
              color: isGranted ? Colors.green : Colors.grey,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  void _listenToConnection() {
    try {
      _connectionSubscription = FirebaseDatabase.instance.ref(".info/connected").onValue.listen((event) {
        final connected = event.snapshot.value as bool? ?? false;
        if (mounted) {
          if (!_isOnline && connected) {
            setState(() {
              _isOnline = true;
              _showOnlineGreen = true;
            });
            _onlineTimer?.cancel();
            _onlineTimer = Timer(const Duration(seconds: 3), () {
              if (mounted) setState(() => _showOnlineGreen = false);
            });
          } else {
            setState(() => _isOnline = connected);
          }
        }
      });
    } catch (e) {
      debugPrint("Firebase connection error: $e");
    }
  }

  void _fetchNotificationSettings() {
    _notificationsSubscription = FirebaseDatabase.instance.ref("settings/notifications_enabled").onValue.listen((event) {
      if (mounted) {
        final value = event.snapshot.value;
        setState(() {
          if (value is bool) {
            _notificationsEnabled = value;
          } else if (value is int) {
            _notificationsEnabled = value == 1;
          } else if (value is String) {
            _notificationsEnabled = value.toLowerCase() == 'true';
          }
        });
      }
    });
  }

  void _initializeData() {
    _listenToPermissions();
    _discoverAllHives();
  }

  void _listenToPermissions() {
    _permissionsSubscription = FirebaseDatabase.instance.ref("permissions").onValue.listen((event) {
      if (mounted) {
        final data = event.snapshot.value;
        if (data is Map) {
          setState(() => allowedHives = data.keys.map((e) => e.toString()).toList()..sort());
        } else {
          setState(() => allowedHives = []);
        }
      }
    });
  }

  Future<void> _discoverAllHives() async {
    if (mounted) setState(() => _isLoadingAllHives = true);
    try {
      final snapshot = await FirebaseDatabase.instance.ref("hives").get();
      if (mounted && snapshot.exists && snapshot.value is Map) {
        final data = snapshot.value as Map;
        setState(() => _allDiscoveredHives = data.keys.map((e) => e.toString()).toList()..sort());
      }
    } finally {
      if (mounted) setState(() => _isLoadingAllHives = false);
    }
  }

  void _showAdminLogin() async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const AdminLoginDialog(),
    );

    if (result == true && mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _isAdmin = true);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final listToDisplay = _isAdmin ? _allDiscoveredHives : allowedHives;

    return Scaffold(
      appBar: AppBar(
        title: const AppLogo(size: 28),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          if (_isAdmin)
            IconButton(
              icon: const Icon(Icons.tune, color: AppColors.primary),
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (c) => const AdminSettingsScreen())),
              tooltip: "Threshold Settings",
            ),
        ],
      ),
      drawer: _buildAppDrawer(),
      body: Column(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 600),
            height: (!_isOnline || _showOnlineGreen) ? 32 : 0,
            width: double.infinity,
            color: _isOnline ? Colors.green : Colors.redAccent,
            alignment: Alignment.center,
            child: (!_isOnline || _showOnlineGreen)
                ? Text(
                    _isOnline ? Lang.t(context, 'online_mode') : Lang.t(context, 'offline_mode'),
                    style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                  )
                : const SizedBox.shrink(),
          ),
          Expanded(
            child: _isLoadingAllHives
                ? _buildShimmerLoading()
                : RefreshIndicator(
                    onRefresh: _discoverAllHives,
                    color: AppColors.primary,
                    child: CustomScrollView(
                      slivers: [
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(Lang.t(context, 'welcome'), style: TextStyle(fontSize: 16, color: Theme.of(context).brightness == Brightness.dark ? Colors.grey[400] : Colors.grey[600])),
                                const Text("Smart Bee", style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
                                const SizedBox(height: 15),
                                _buildSummaryStats(listToDisplay.length),
                              ],
                            ),
                          ),
                        ),
                        SliverPadding(
                          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
                          sliver: SliverGrid(
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2, crossAxisSpacing: 15, mainAxisSpacing: 15, childAspectRatio: 0.8,
                            ),
                            delegate: SliverChildBuilderDelegate(
                              (context, index) => HiveCard(key: ValueKey("card_${listToDisplay[index]}"), hiveId: listToDisplay[index]),
                              childCount: listToDisplay.length,
                            ),
                          ),
                        ),
                        if (_isAdmin) SliverToBoxAdapter(child: _buildAdminSection()),
                        const SliverToBoxAdapter(child: SizedBox(height: 50)),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildShimmerLoading() {
    return GridView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: 15, mainAxisSpacing: 15, childAspectRatio: 0.8),
      itemCount: 4,
      itemBuilder: (context, index) => Container(
        decoration: BoxDecoration(
          color: Colors.grey.withOpacity(0.1),
          borderRadius: BorderRadius.circular(25),
        ),
      ),
    );
  }

  Widget _buildSummaryStats(int totalHives) {
    return Row(
      children: [
        SummaryItem(label: Lang.t(context, 'total'), value: totalHives.toString(), color: AppColors.primary),
        const SizedBox(width: 10),
        SummaryItem(label: Lang.t(context, 'region'), value: Lang.t(context, 'algeria'), color: AppColors.accent),
      ],
    );
  }

  Drawer _buildAppDrawer() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          const DrawerHeader(
            decoration: BoxDecoration(gradient: LinearGradient(colors: [AppColors.primary, Color(0xFFFFB300)])),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.hive, size: 60, color: Colors.white),
              SizedBox(height: 10),
              Text('SMART BEE ALGERIA', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
            ]),
          ),
          ListTile(
            leading: Icon(isDarkMode ? Icons.light_mode : Icons.dark_mode, color: AppColors.primary),
            title: Text(isDarkMode ? Lang.t(context, 'switch_light') : Lang.t(context, 'switch_dark')),
            onTap: () {
              final app = SmartBeeApp.of(context);
              Navigator.pop(context);
              WidgetsBinding.instance.addPostFrameCallback((_) {
                app?.changeTheme(isDarkMode ? ThemeMode.light : ThemeMode.dark);
              });
            },
          ),
          ListTile(
            leading: const Icon(Icons.language, color: AppColors.primary),
            title: Text(Lang.t(context, 'change_lang')),
            trailing: Text(Localizations.localeOf(context).languageCode == 'ar' ? 'العربية' : 'English', style: const TextStyle(color: Colors.grey)),
            onTap: () {
              final app = SmartBeeApp.of(context);
              final newLocale = Localizations.localeOf(context).languageCode == 'ar' ? const Locale('en') : const Locale('ar');
              Navigator.pop(context);
              WidgetsBinding.instance.addPostFrameCallback((_) {
                app?.changeLocale(newLocale);
              });
            },
          ),
          ListTile(
            leading: const Icon(Icons.help_center_outlined, color: AppColors.primary),
            title: Text(Lang.t(context, 'faq')),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (c) => const FaqPage()));
            },
          ),
          const Divider(),
          _isAdmin
              ? ListTile(
                  leading: const Icon(Icons.power_settings_new, color: Colors.red),
                  title: Text(Lang.t(context, 'logout_admin')),
                  onTap: () {
                    Navigator.pop(context);
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted) setState(() => _isAdmin = false);
                    });
                  },
                )
              : ListTile(
                  leading: const Icon(Icons.admin_panel_settings, color: AppColors.primary),
                  title: Text(Lang.t(context, 'admin_panel')),
                  onTap: () {
                    Navigator.pop(context);
                    _showAdminLogin();
                  },
                ),
        ],
      ),
    );
  }

  Widget _buildAdminSection() {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Divider(height: 60),
          Text(Lang.t(context, 'admin_settings'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppColors.primary)),
          const SizedBox(height: 15),
          Card(
            child: SwitchListTile(
              title: Text(Lang.t(context, 'push_alerts'), style: const TextStyle(fontWeight: FontWeight.bold)),
              secondary: const Icon(Icons.notifications_active, color: AppColors.primary),
              value: _notificationsEnabled,
              onChanged: (bool value) async => await FirebaseDatabase.instance.ref("settings/notifications_enabled").set(value),
            ),
          ),
          const SizedBox(height: 20),
          Text(Lang.t(context, 'management'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.grey)),
          ..._allDiscoveredHives.map((hiveId) {
            final isVisible = allowedHives.contains(hiveId);
            return Card(
              key: ValueKey("admin_card_$hiveId"),
              margin: const EdgeInsets.only(top: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              child: CheckboxListTile(
                title: Text(hiveId, style: const TextStyle(fontWeight: FontWeight.bold)),
                secondary: Icon(isVisible ? Icons.visibility : Icons.visibility_off, color: isVisible ? AppColors.primary : Colors.grey),
                value: isVisible,
                onChanged: (bool? value) async {
                  if (value == true) {
                    await FirebaseDatabase.instance.ref("permissions/$hiveId").set(true);
                  } else {
                    await FirebaseDatabase.instance.ref("permissions/$hiveId").remove();
                  }
                },
              ),
            );
          }),
        ],
      ),
    );
  }
}

class AdminLoginDialog extends StatefulWidget {
  const AdminLoginDialog({super.key});

  @override
  State<AdminLoginDialog> createState() => _AdminLoginDialogState();
}

class _AdminLoginDialogState extends State<AdminLoginDialog> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const AppLogo(size: 30),
      content: TextField(
        controller: _controller,
        obscureText: true,
        decoration: InputDecoration(
          hintText: Lang.t(context, 'admin_code_hint'),
          border: const OutlineInputBorder(),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: Text(Lang.t(context, 'cancel'))),
        ElevatedButton(
          onPressed: () {
            if (_controller.text == "2026") {
              Navigator.pop(context, true);
            }
          },
          child: Text(Lang.t(context, 'access')),
        ),
      ],
    );
  }
}
