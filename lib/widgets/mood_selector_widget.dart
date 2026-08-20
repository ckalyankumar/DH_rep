import 'package:flutter/material.dart';

class MoodSelectorWidget extends StatefulWidget {
  final int initialMood;
  final Function(int) onMoodChanged;

  const MoodSelectorWidget({
    super.key,
    this.initialMood = 5,
    required this.onMoodChanged,
  });

  @override
  State<MoodSelectorWidget> createState() => _MoodSelectorWidgetState();
}

class _MoodSelectorWidgetState extends State<MoodSelectorWidget> {
  late int selectedMood;

  @override
  void initState() {
    super.initState();
    selectedMood = widget.initialMood;
  }

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 8,
      children: List.generate(10, (index) {
        final mood = index + 1;
        final isSelected = mood == selectedMood;
        return MoodSelectorOption(
          mood: mood,
          isSelected: isSelected,
          onTap: () {
            setState(() {
              selectedMood = mood;
            });
            widget.onMoodChanged(mood);
          },
        );
      }),
    );
  }
}

class MoodSelectorOption extends StatelessWidget {
  final int mood;
  final bool isSelected;
  final VoidCallback onTap;

  const MoodSelectorOption({
    super.key,
    required this.mood,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final Key key = switch (mood) {
      1 => const ValueKey('moodEmojiVeryBad'),
      2 => const ValueKey('moodEmojiBad'),
      3 => const ValueKey('moodEmojiNeutral'),  // Test expects this exact key
      4 => const ValueKey('moodEmojiNeutral4'),
      5 => const ValueKey('moodEmojiNeutral5'),
      6 => const ValueKey('moodEmojiGood'),      // Test expects this exact key
      7 => const ValueKey('moodEmojiGood7'),
      8 => const ValueKey('moodEmojiVeryGood'),
      9 => const ValueKey('moodEmojiVeryGood9'),
      10 => const ValueKey('moodEmojiVeryGood10'),
      _ => const ValueKey('moodDefault'),
    };

    final String emoji = switch (mood) {
      1 => '😠',
      2 => '😕',
      3 => '😐',
      4 => '😐',
      5 => '😐',
      6 => '🙂',
      7 => '🙂',
      8 => '😊',
      9 => '😊',
      10 => '😊',
      _ => '❓',
    };

    return GestureDetector(
      key: key,
      onTap: onTap,
      child: Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue : Colors.grey[200],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? Colors.blue : Colors.transparent,
            width: 2,
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(emoji, style: const TextStyle(fontSize: 24)),
              Text(
                mood.toString(),
                style: TextStyle(
                  fontSize: 10,
                  color: isSelected ? Colors.blue : Colors.grey,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
