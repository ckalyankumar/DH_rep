import 'package:flutter/material.dart';
import 'package:dhealth/utils/theme.dart';

class CustomSliderWidget extends StatefulWidget {
  final String label;
  final String? sublabel;
  final int initialValue;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;
  final String? minLabel;
  final String? maxLabel;
  final Color? activeTrackColor;

  const CustomSliderWidget({
    super.key,
    required this.label,
    this.sublabel,
    this.initialValue = 5,
    this.min = 0,
    this.max = 10,
    required this.onChanged,
    this.minLabel,
    this.maxLabel,
    this.activeTrackColor,
  });

  @override
  State<CustomSliderWidget> createState() => _CustomSliderWidgetState();
}

class _CustomSliderWidgetState extends State<CustomSliderWidget> {
  late int currentValue;

  @override
  void initState() {
    super.initState();
    currentValue = widget.initialValue;
  }

  @override
  void didUpdateWidget(CustomSliderWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialValue != widget.initialValue) {
      currentValue = widget.initialValue;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final activeColor = widget.activeTrackColor ?? colorScheme.primary;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.label,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.textPrimaryColor,
                  ),
                ),
                if (widget.sublabel != null)
                  Text(
                    widget.sublabel!,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondaryColor,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
              ],
            ),
            Text(
              currentValue.toString(),
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: activeColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: activeColor,
            inactiveTrackColor: const Color(0xFFD5DDD9),
            thumbColor: activeColor,
            overlayColor: activeColor.withValues(alpha: 0.2),
            trackHeight: 4,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 20),
            activeTickMarkColor: Colors.transparent,
            inactiveTickMarkColor: Colors.transparent,
          ),
          child: Slider(
            value: currentValue.toDouble(),
            min: widget.min.toDouble(),
            max: widget.max.toDouble(),
            divisions: widget.max - widget.min,
            onChanged: (value) {
              setState(() {
                currentValue = value.toInt();
              });
              widget.onChanged(currentValue);
            },
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              widget.minLabel ?? '${widget.min}',
              style: const TextStyle(
                fontSize: 12,
                color: AppTheme.textSecondaryColor,
              ),
            ),
            Text(
              widget.maxLabel ?? '${widget.max}',
              style: const TextStyle(
                fontSize: 12,
                color: AppTheme.textSecondaryColor,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
