import 'package:flutter/material.dart';

import '../../core/services/app_haptics.dart';
import '../../shared/theme/app_icons.dart';

/// Developer-only: feel every haptic pattern side by side while tuning them.
class HapticsLabScreen extends StatefulWidget {
  const HapticsLabScreen({super.key});

  @override
  State<HapticsLabScreen> createState() => _HapticsLabScreenState();
}

class _HapticsLabScreenState extends State<HapticsLabScreen> {
  double _intensity = 1;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Haptics lab')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          Text(
            'Intensity ${(_intensity * 100).round()}%',
            style: tt.labelLarge,
          ),
          Slider(
            value: _intensity,
            divisions: 10,
            onChanged: (v) => setState(() => _intensity = v),
          ),
          const SizedBox(height: 8),
          for (final pattern in AppHaptics.all)
            Card.filled(
              color: cs.surfaceContainerLow,
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                title: Text(pattern.name),
                subtitle: Text(
                  [
                    for (final step in pattern.steps)
                      '${step.delayMs > 0 ? '+${step.delayMs}ms ' : ''}'
                          '${step.primitive.name} ${step.scale}',
                  ].join('  ·  '),
                  style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                ),
                trailing: const AppIcon(AppIcons.play),
                onTap: () => AppHaptics.play(pattern, intensity: _intensity),
              ),
            ),
        ],
      ),
    );
  }
}
