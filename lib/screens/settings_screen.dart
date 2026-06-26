import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../l10n/app_localizations.dart';
import '../main.dart';
import '../services/auth_service.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final currentLocale = ref.watch(localProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Color(0xFF1F3E6C)),
          onPressed: () => context.pop(),
        ),
        title: Text(
          l10n.settings,
          style: const TextStyle(
            color: Color(0xFF1F3E6C),
            fontWeight: FontWeight.bold,
            fontSize: 22,
          ),
        ),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
        child: Column(
          children: [
            const SizedBox(height: 20),
            // Language Option
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFF1F3E6C).withOpacity(0.5)),
                borderRadius: BorderRadius.circular(16),
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                leading: const Icon(Icons.language, color: Color(0xFF1F3E6C)),
                title: Text(
                  l10n.language,
                  style: const TextStyle(
                    color: Color(0xFF1F3E6C),
                    fontWeight: FontWeight.w500,
                    fontSize: 18,
                  ),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      currentLocale.languageCode == 'en' ? l10n.english : l10n.arabic,
                      style: const TextStyle(color: Colors.grey, fontSize: 16),
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.chevron_right, color: Color(0xFF1F3E6C)),
                  ],
                ),
                onTap: () {
                  _showLanguageDialog(context, ref);
                },
              ),
            ),
            const Spacer(),
            // Logout Button
            SizedBox(
              width: double.infinity,
              height: 60,
              child: ElevatedButton(
                onPressed: () async {
                  await AuthService().logout();
                  if (context.mounted) {
                    context.go('/login');
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFBC4B4B),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  l10n.logout,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  void _showLanguageDialog(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.language),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(l10n.english),
              trailing: ref.watch(localProvider).languageCode == 'en'
                  ? const Icon(Icons.check, color: Color(0xFF1F3E6C))
                  : null,
              onTap: () {
                ref.read(localProvider.notifier).state = const Locale('en');
                Navigator.pop(context);
              },
            ),
            ListTile(
              title: Text(l10n.arabic),
              trailing: ref.watch(localProvider).languageCode == 'ar'
                  ? const Icon(Icons.check, color: Color(0xFF1F3E6C))
                  : null,
              onTap: () {
                ref.read(localProvider.notifier).state = const Locale('ar');
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }
}
