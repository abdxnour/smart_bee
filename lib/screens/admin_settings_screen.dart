import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import '../core/app_colors.dart';
import '../core/lang.dart';

class AdminSettingsScreen extends StatefulWidget {
  const AdminSettingsScreen({super.key});

  @override
  State<AdminSettingsScreen> createState() => _AdminSettingsScreenState();
}

class _AdminSettingsScreenState extends State<AdminSettingsScreen> {
  final _database = FirebaseDatabase.instance.ref();
  
  final _tempMaxController = TextEditingController();
  final _tempMinController = TextEditingController();
  final _humMaxController = TextEditingController();
  final _humMinController = TextEditingController();

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCurrentSettings();
  }

  void _loadCurrentSettings() async {
    try {
      final snapshot = await _database.child('settings').get();
      final value = snapshot.value;
      if (!mounted) return;
      if (snapshot.exists && value is Map) {
        setState(() {
          _tempMaxController.text = (value['temp_max'] ?? "").toString();
          _tempMinController.text = (value['temp_min'] ?? "").toString();
          _humMaxController.text = (value['hum_max'] ?? "").toString();
          _humMinController.text = (value['hum_min'] ?? "").toString();
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(Lang.t(context, 'load_error'))),
        );
      }
    }
  }

  void _saveSettings() async {
    final tMin = double.tryParse(_tempMinController.text);
    final tMax = double.tryParse(_tempMaxController.text);
    final hMin = double.tryParse(_humMinController.text);
    final hMax = double.tryParse(_humMaxController.text);

    if (tMin == null || tMax == null || hMin == null || hMax == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(Lang.t(context, 'invalid_input'))),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      await _database.child('settings').update({
        "temp_max": tMax,
        "temp_min": tMin,
        "hum_max": hMax,
        "hum_min": hMin,
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(Lang.t(context, 'save_success')),
            backgroundColor: AppColors.online,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(Lang.t(context, 'save_error')),
            backgroundColor: AppColors.offline,
          ),
        );
      }
    }
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(Lang.t(context, 'admin_settings_title'), style: const TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
        : Container(
            color: isDark ? null : AppColors.backgroundLight,
            child: ListView(
              padding: const EdgeInsets.all(16.0),
              children: [
                _buildCardSection(
                  title: Lang.t(context, 'temp_limits'),
                  icon: Icons.thermostat_rounded,
                  iconColor: AppColors.temp,
                  children: [
                    Row(
                      children: [
                        Expanded(child: _buildTextField(_tempMinController, Lang.t(context, 'min_val'))),
                        const SizedBox(width: 16),
                        Expanded(child: _buildTextField(_tempMaxController, Lang.t(context, 'max_val'))),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildCardSection(
                  title: Lang.t(context, 'hum_limits'),
                  icon: Icons.water_drop_rounded,
                  iconColor: AppColors.hum,
                  children: [
                    Row(
                      children: [
                        Expanded(child: _buildTextField(_humMinController, Lang.t(context, 'min_val'))),
                        const SizedBox(width: 16),
                        Expanded(child: _buildTextField(_humMaxController, Lang.t(context, 'max_val'))),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: ElevatedButton.icon(
                    onPressed: _saveSettings,
                    icon: const Icon(Icons.cloud_upload_rounded, color: Colors.black),
                    label: Text(
                      Lang.t(context, 'save_btn'), 
                      style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 16)
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 4,
                      shadowColor: AppColors.primary.withOpacity(0.4),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
    );
  }

  Widget _buildCardSection({required String title, required IconData icon, required Color iconColor, required List<Widget> children}) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: iconColor, size: 28),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Divider(),
            ),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label) {
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      textAlign: TextAlign.center,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(fontSize: 14),
        floatingLabelBehavior: FloatingLabelBehavior.always,
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        filled: true,
        fillColor: Theme.of(context).brightness == Brightness.light ? Colors.grey.shade50 : Colors.white.withOpacity(0.05),
      ),
    );
  }

  @override
  void dispose() {
    _tempMaxController.dispose();
    _tempMinController.dispose();
    _humMaxController.dispose();
    _humMinController.dispose();
    super.dispose();
  }
}
