import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/brand.dart';
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
    (
      null,
      'Узнайте любое растение',
      'Сфотографируйте цветок, лист или дерево — Leafy подскажет, что это за вид.',
    ),
    (
      Icons.healing,
      'Поймите, что с ним не так',
      'Пятна, жёлтые листья, вредители — фото поможет найти причину и способ лечения.',
    ),
    (
      Icons.water_drop,
      'Не забывайте ухаживать',
      'Полив, подкормка, пересадка — напоминания для каждого растения в вашем саду.',
    ),
  ];

  Future<void> _finish(String route) async {
    await ref
        .read(settingsProvider.notifier)
        .update((s) => s.copyWith(onboardingDone: true));
    if (!mounted) return;
    context.go('/');
    if (route != '/') context.push(route);
  }

  @override
  Widget build(BuildContext context) {
    final last = _index == _slides.length - 1;
    final p = context.palette;
    return Scaffold(
      backgroundColor: p.bg,
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => _finish('/'),
                child: Text(
                  'Пропустить',
                  style: TextStyle(color: p.inkSecondary),
                ),
              ),
            ),
            Expanded(
              child: PageView(
                controller: _pages,
                onPageChanged: (i) => setState(() => _index = i),
                children: [
                  for (final (icon, title, text) in _slides)
                    LayoutBuilder(
                      builder: (context, c) => SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        child: ConstrainedBox(
                          constraints: BoxConstraints(minHeight: c.maxHeight),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              icon == null
                                  ? const LeafyMark(size: 112)
                                  : Icon(icon, size: 96, color: p.accent),
                              const SizedBox(height: 40),
                              Text(
                                title,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 30,
                                  height: 1.1,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.8,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                text,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: p.inkSecondary,
                                  fontSize: 17,
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ),
                        ),
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
                      color: i == _index ? p.ink : p.surfaceHigh,
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
                  onPressed: last
                      ? () => _finish('/settings')
                      : () => _pages.nextPage(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeOut,
                        ),
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
