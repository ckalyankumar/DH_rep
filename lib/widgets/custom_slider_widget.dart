import 'package:flutter/material.dart';

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
                    color: Color(0xFF2c3e50),
                  ),
                ),
                if (widget.sublabel != null)
                  Text(
                    widget.sublabel!,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF6c757d),
                      fontWeight: FontWeight.w400,
                    ),
                  ),
              ],
            ),
            Text(
              currentValue.toString(),
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFF3498db),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: widget.activeTrackColor ?? const Color(0xFF3498DB),
            inactiveTrackColor: const Color(0xFFF8F9FA),
            thumbColor: widget.activeTrackColor ?? const Color(0xFF3498DB),
            overlayColor: (widget.activeTrackColor ?? const Color(0xFF3498DB))
                .withValues(alpha:0.2),
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
                color: Color(0xFF6c757d),
              ),
            ),
            Text(
              widget.maxLabel ?? '${widget.max}',
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF6c757d),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
