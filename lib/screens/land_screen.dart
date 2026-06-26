import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../l10n/app_localizations.dart';

enum DetectionMethod { voice, handwriting, smartPen }

class LandScreen extends ConsumerStatefulWidget {
  const LandScreen({super.key});

  @override
  ConsumerState<LandScreen> createState() => _LandScreenState();
}

class _LandScreenState extends ConsumerState<LandScreen> {
  DetectionMethod? _selectedMethod;

  void _onNext() {
    if (_selectedMethod == null) return;

    switch (_selectedMethod!) {
      case DetectionMethod.voice:
        context.push('/voice');
        break;
      case DetectionMethod.handwriting:
        context.push('/handwriting');
        break;
      case DetectionMethod.smartPen:
        context.push('/pen');
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      color: Colors.white,
      child: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: Column(
                children: [
                  _SelectionCard(
                    title: l10n.voiceTest,
                    imagePath: 'assets/images/voiceIcon.png',
                    isSelected: _selectedMethod == DetectionMethod.voice,
                    onTap: () => setState(() => _selectedMethod = DetectionMethod.voice),
                  ),
                  const SizedBox(height: 20),
                  _SelectionCard(
                    title: l10n.handwrittenTest,
                    imagePath: 'assets/images/imageIcon.png',
                    isSelected: _selectedMethod == DetectionMethod.handwriting,
                    onTap: () => setState(() => _selectedMethod = DetectionMethod.handwriting),
                  ),
                  const SizedBox(height: 20),
                  _SelectionCard(
                    title: l10n.smartPenTest,
                    imagePath: 'assets/images/smartpenIcon.png',
                    isSelected: _selectedMethod == DetectionMethod.smartPen,
                    onTap: () => setState(() => _selectedMethod = DetectionMethod.smartPen),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 40),
            child: Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  height: 60,
                  child: ElevatedButton(
                    onPressed: _selectedMethod != null ? _onNext : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1F3E6C),
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: const Color(0xFF1F3E6C).withOpacity(0.6),
                      disabledForegroundColor: Colors.white.withOpacity(0.6),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      elevation: 0,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.chevron_right, size: 28),
                        const SizedBox(width: 8),
                        Text(
                          l10n.next,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SelectionCard extends StatelessWidget {
  const _SelectionCard({
    required this.title,
    required this.imagePath,
    required this.isSelected,
    required this.onTap,
  });

  final String title;
  final String imagePath;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 32),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isSelected ? const Color(0xFF1F3E6C) : const Color(0xFF1F3E6C).withOpacity(0.2),
            width: isSelected ? 2 : 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Image.asset(
              imagePath,
              height: 70,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) => Icon(
                Icons.image_not_supported,
                size: 70,
                color: Colors.grey[300],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(
                color: Color(0xFF1F3E6C),
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
