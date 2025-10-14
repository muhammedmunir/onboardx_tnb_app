import 'package:flutter/material.dart';
import 'package:onboardx_tnb_app/l10n/app_localizations.dart';
import 'package:onboardx_tnb_app/providers/locale_provider.dart';
import 'package:provider/provider.dart';

class LanguageTranslationScreen extends StatefulWidget {
  const LanguageTranslationScreen({super.key});

  @override
  State<LanguageTranslationScreen> createState() => _LanguageTranslationScreenState();
}

class _LanguageTranslationScreenState extends State<LanguageTranslationScreen> {
  @override
  Widget build(BuildContext context) {
    final localeProvider = Provider.of<LocaleProvider>(context);
    final currentLocale = localeProvider.locale ?? const Locale('en');

    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.languageAndTranslations),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: ListView(
        children: [
          _buildSectionHeader(AppLocalizations.of(context)!.selectLanguage),
          _buildLanguageOption(
            title: AppLocalizations.of(context)!.english,
            subtitle: 'Application language will be changed to English',
            isSelected: currentLocale.languageCode == 'en',
            onTap: () {
              localeProvider.setLocale(const Locale('en'));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(AppLocalizations.of(context)!.languageChangedToEnglish),
                  duration: const Duration(seconds: 2),
                ),
              );
            },
          ),
          _buildLanguageOption(
            title: AppLocalizations.of(context)!.bahasaMelayu,
            subtitle: 'Bahasa aplikasi akan ditukar kepada Bahasa Melayu',
            isSelected: currentLocale.languageCode == 'ms',
            onTap: () {
              localeProvider.setLocale(const Locale('ms'));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(AppLocalizations.of(context)!.languageChangedToMalay),
                  duration: const Duration(seconds: 2),
                ),
              );
            },
          ),
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              AppLocalizations.of(context)!.languageChangeNote,
              style: TextStyle(
                fontSize: 14,
                color: Theme.of(context).textTheme.bodySmall?.color,
                fontStyle: FontStyle.italic,
              ),
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

  Widget _buildLanguageOption({
    required String title,
    required String subtitle,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return ListTile(
      title: Text(title),
      subtitle: Text(subtitle),
      leading: Icon(
        Icons.language,
        color: Theme.of(context).iconTheme.color,
      ),
      trailing: isSelected
          ? Icon(Icons.check_circle, color: Theme.of(context).colorScheme.primary)
          : null,
      onTap: onTap,
    );
  }
}