import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Wraps the app in a phone-shaped device frame when it is being viewed on a wide
/// screen — which, for a Flutter *web* build, is how everyone will actually see it.
///
/// Without this the driver app renders edge to edge in a desktop browser and reads as a
/// slightly odd website. The deliverable is a mobile app; the frame is what tells the
/// viewer that in the first half-second, before anyone has read a word.
///
/// On a real phone-sized viewport it gets out of the way entirely and returns the child
/// untouched — the frame is a presentation affordance, not a layout the app depends on.
class PhoneFrame extends StatelessWidget {
  const PhoneFrame({super.key, required this.child});

  final Widget child;

  /// Below this width we are already phone-shaped; drawing a phone inside a phone
  /// would be absurd.
  static const double _breakpoint = 620;

  static const double _screenWidth = 390;
  static const double _screenHeight = 844;
  static const double _bezel = 12;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < _breakpoint) return child;

        // Shrink to fit short windows rather than overflowing.
        final available = constraints.maxHeight - 48;
        final height = math.min(_screenHeight, math.max(480.0, available));
        final width = _screenWidth * (height / _screenHeight).clamp(0.75, 1.0);

        final scheme = Theme.of(context).colorScheme;

        return ColoredBox(
          color: scheme.brightness == Brightness.dark
              ? const Color(0xFF07090F)
              : const Color(0xFFE9EDF5),
          child: Center(
            child: Container(
              padding: const EdgeInsets.all(_bezel),
              decoration: BoxDecoration(
                color: const Color(0xFF0B0D12),
                borderRadius: BorderRadius.circular(48),
                border: Border.all(color: const Color(0xFF2A2F3A), width: 1),
                boxShadow: const [
                  BoxShadow(color: Color(0x66000000), blurRadius: 48, offset: Offset(0, 18)),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(36),
                child: SizedBox(
                  width: width,
                  height: height,
                  child: Stack(
                    children: [
                      // The app believes it is running on a 390-wide phone: MediaQuery is
                      // overridden so AppBar and NavigationBar reserve the status-bar and
                      // home-indicator space instead of sitting under the hardware.
                      MediaQuery(
                        data: MediaQuery.of(context).copyWith(
                          size: Size(width, height),
                          padding: const EdgeInsets.only(top: 40, bottom: 18),
                          viewInsets: EdgeInsets.zero,
                          viewPadding: const EdgeInsets.only(top: 40, bottom: 18),
                        ),
                        child: child,
                      ),
                      const _DynamicIsland(),
                      const _HomeIndicator(),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _DynamicIsland extends StatelessWidget {
  const _DynamicIsland();

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 9,
      left: 0,
      right: 0,
      child: Center(
        child: Container(
          width: 104,
          height: 26,
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(999),
          ),
        ),
      ),
    );
  }
}

class _HomeIndicator extends StatelessWidget {
  const _HomeIndicator();

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 7,
      left: 0,
      right: 0,
      child: Center(
        child: Container(
          width: 128,
          height: 4,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(999),
          ),
        ),
      ),
    );
  }
}
