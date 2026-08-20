import 'package:flutter/material.dart';

/// A single shimmer block. Animates opacity 1.0 → 0.4 → 1.0 in a 1.4s loop.
class SkeletonBox extends StatefulWidget {
  final double width;
  final double height;
  final double borderRadius;

  const SkeletonBox({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius = 8,
  });

  @override
  State<SkeletonBox> createState() => _SkeletonBoxState();
}

class _SkeletonBoxState extends State<SkeletonBox>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  static const _baseColor = Color(0xFFE8EDEB);
  static const _highlightColor = Color(0xFFF0F4F2);

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1400),
      vsync: this,
    )..repeat(reverse: true);

    _animation = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        final t = _animation.value;
        final color = Color.lerp(_baseColor, _highlightColor, t)!;
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(widget.borderRadius),
          ),
        );
      },
    );
  }
}

/// Pre-built card skeleton matching DailyLog card height.
class SkeletonLogCard extends StatelessWidget {
  const SkeletonLogCard({super.key});

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : screenWidth;
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                SkeletonBox(width: 120, height: 12),
                const SizedBox(height: 12),
                SkeletonBox(
                  width: maxWidth > 0 ? maxWidth - 32 : 200,
                  height: 10,
                ),
                const SizedBox(height: 8),
                SkeletonBox(
                  width: maxWidth > 0 ? maxWidth - 32 : 200,
                  height: 10,
                ),
                const SizedBox(height: 8),
                SkeletonBox(
                  width: maxWidth > 0 ? maxWidth - 32 : 200,
                  height: 10,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    SkeletonBox(width: 60, height: 10),
                    const SizedBox(width: 8),
                    SkeletonBox(width: 60, height: 10),
                    const SizedBox(width: 8),
                    SkeletonBox(width: 60, height: 10),
                    const SizedBox(width: 8),
                    SkeletonBox(width: 60, height: 10),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Pre-built stats row skeleton: two SkeletonBox cards side by side.
class SkeletonStatsRow extends StatelessWidget {
  const SkeletonStatsRow({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  SkeletonBox(width: 80, height: 12),
                  const SizedBox(height: 8),
                  SkeletonBox(width: 60, height: 20),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  SkeletonBox(width: 80, height: 12),
                  const SizedBox(height: 8),
                  SkeletonBox(width: 60, height: 20),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
