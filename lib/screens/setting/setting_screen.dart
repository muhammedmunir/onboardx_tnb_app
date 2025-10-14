import 'package:flutter/material.dart';
import 'package:onboardx_tnb_app/l10n/app_localizations.dart';
import 'package:onboardx_tnb_app/screens/setting/device_permission_screen.dart';
import 'package:onboardx_tnb_app/screens/setting/language_translation_screen.dart';
import 'package:onboardx_tnb_app/screens/setting/manage_your_account_screen.dart';
import 'package:onboardx_tnb_app/services/theme_service.dart';

class SettingScreen extends StatefulWidget {
  const SettingScreen({super.key});

  @override
  State<SettingScreen> createState() => _SettingScreenState();
}

class _SettingScreenState extends State<SettingScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.settings),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
        automaticallyImplyLeading: false,
      ),
      body: ListView(
        children: [
          _buildSectionHeader(AppLocalizations.of(context)!.account),
          _buildListTile(
            title: AppLocalizations.of(context)!.manageYourAccount,
            icon: Icons.account_circle_outlined,
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const ManageAccountScreen(user: {}),
                ),
              );
            },
          ),
          _buildSectionHeader(AppLocalizations.of(context)!.preferences),
          _buildListTile(
            title: AppLocalizations.of(context)!.devicePermission,
            icon: Icons.perm_device_info_outlined,
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const DevicePermissionScreen(),
                ),
              );
            },
          ),
          _buildListTile(
            title: AppLocalizations.of(context)!.languageAndTranslations,
            icon: Icons.language_outlined,
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const LanguageTranslationScreen(),
                ),
              );
            },
          ),

          ValueListenableBuilder<ThemeMode>(
            valueListenable: themeNotifier,
            builder: (context, ThemeMode mode, _) {
              final isDark = mode == ThemeMode.dark;
              return SwitchListTile(
                title: Text(AppLocalizations.of(context)!.darkMode),
                secondary: Icon(
                  isDark ? Icons.dark_mode_outlined : Icons.light_mode_outlined,
                ),
                activeColor: Colors.grey,
                value: isDark,
                onChanged: (value) {
                  themeNotifier.value =
                      value ? ThemeMode.dark : ThemeMode.light;
                },
              );
            },
          ),

          const SizedBox(height: 16),
          _buildSectionHeader(AppLocalizations.of(context)!.about),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: Theme.of(context).iconTheme.color),
                const SizedBox(width: 16),
                Text(AppLocalizations.of(context)!.version),
                const Spacer(),
                Text(
                  '1.0.0',
                  style: TextStyle(
                    color: Theme.of(context).textTheme.bodySmall?.color,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: Color.fromRGBO(224, 124, 124, 1),
        ),
      ),
    );
  }

  Widget _buildListTile({
    required String title,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}