import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/settings.dart';
import '../../core/theme.dart';

/// Короткое знакомство: три карточки и переход к настройке ключа.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _pages = PageController();
  var _index = 0;

  static const _slides = [
    (Icons.center_focus_strong, 'Узнайте любое растение', 'Сфотографируйте цветок, лист или дерево — Leafy подскажет, что это за вид.'),
    (Icons.healing, 'Поймите, что с ним не так', 'Пятна, жёлтые листья, вредители — фото поможет найти причину и способ лечения.'),
    (Icons.water_drop, 'Не забывайте ухаживать', 'Полив, подкормка, пересадка — напоминания для каждого растения в вашем саду.'),
  ];

  Future<void> _finish(String route) async {
    await ref.read(settingsProvider.notifier).update((s) => s.copyWith(onboardingDone: true));
    if (!mounted) return;
    context.go('/');
    if (route != '/') context.push(route);
  }

  @override
  Widget build(BuildContext context) {
    final last = _index == _slides.length - 1;
    return Scaffold(
      backgroundColor: LeafyColors.forest,
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => _finish('/'),
                child: const Text('Пропустить', style: TextStyle(color: Colors.white70)),
              ),
            ),
            Expanded(
              child: PageView(
                controller: _pages,
                onPageChanged: (i) => setState(() => _index = i),
                children: [
                  for (final (icon, title, text) in _slides)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircleAvatar(
                            radius: 72,
                            backgroundColor: Colors.white.withValues(alpha: 0.12),
                            child: Icon(icon, size: 72, color: Colors.white),
                          ),
                          const SizedBox(height: 40),
                          Text(title,
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w800)),
                          const SizedBox(height: 16),
                          Text(text,
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Colors.white70, fontSize: 17, height: 1.4)),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < _slides.length; i++)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.all(4),
                    width: i == _index ? 24 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: i == _index ? Colors.white : Colors.white38,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: Colors.white, foregroundColor: LeafyColors.forest),
                  onPressed: last
                      ? () => _finish('/settings')
                      : () => _pages.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeOut),
                  child: Text(last ? 'Настроить распознавание' : 'Далее'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
