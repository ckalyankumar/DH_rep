import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:dhealth/models/pro_assessment.dart';
import 'package:dhealth/services/firestore_pro_assessment_service.dart';

/// Weekly validated questionnaires (PROs) for eczema/psoriasis.
///
/// - Eczema: POEM (Patient-Oriented Eczema Measure)
/// - Psoriasis: DLQI (Dermatology Life Quality Index)
class ProQuestionnaireScreen extends StatefulWidget {
  final String condition; // 'psoriasis' or 'eczema'

  const ProQuestionnaireScreen({
    super.key,
    required this.condition,
  });

  @override
  State<ProQuestionnaireScreen> createState() => _ProQuestionnaireScreenState();
}

class _ProQuestionnaireScreenState extends State<ProQuestionnaireScreen> {
  late final String _proType;
  late final List<ProQuestionnaireConfig> _questions;
  late final FirestoreProAssessmentService _firestoreService;

  // Selected score per question index; null = unanswered.
  late List<int?> _scores;

  bool _isSaving = false;
  ProAssessment? _latest;

  @override
  void initState() {
    super.initState();
    _proType = widget.condition.toLowerCase() == 'eczema'
        ? ProAssessmentType.poem
        : ProAssessmentType.dlqi;
    _questions = _proType == ProAssessmentType.poem
        ? ProQuestionnaireConfig.poemQuestions()
        : ProQuestionnaireConfig.dlqiQuestions();
    _scores = List<int?>.filled(_questions.length, null);

    final userId = FirebaseAuth.instance.currentUser?.uid ?? 'demo-user';
    _firestoreService = FirestoreProAssessmentService(userId: userId);

    _loadLatest();
  }

  Future<void> _loadLatest() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;
    final latest = await _firestoreService.getLatestForType(
      type: _proType,
      condition: widget.condition,
    );
    if (!mounted) return;
    setState(() {
      _latest = latest;
    });
  }

  bool get _allAnswered => !_scores.any((s) => s == null);

  (int total, String band)? get _currentScore {
    if (!_allAnswered) return null;
    final scores = _scores.map((e) => e ?? 0).toList();
    return _proType == ProAssessmentType.poem
        ? ProQuestionnaireConfig.scorePoem(scores)
        : ProQuestionnaireConfig.scoreDlqi(scores);
  }

  Future<void> _save() async {
    if (!_allAnswered) return;
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sign in to save questionnaire results.')),
        );
      }
      return;
    }

    final score = _currentScore;
    if (score == null) return;

    setState(() => _isSaving = true);
    try {
      final now = DateTime.now();
      final responses = <ProItemResponse>[];
      for (var i = 0; i < _questions.length; i++) {
        final q = _questions[i];
        final s = _scores[i] ?? 0;
        responses.add(
          ProItemResponse(
            itemId: q.id,
            questionText: q.text,
            score: s,
          ),
        );
      }

      final assessment = ProAssessment(
        id: '${_proType}_${now.toIso8601String()}',
        type: _proType,
        condition: widget.condition,
        date: now,
        totalScore: score.$1,
        severityBand: score.$2,
        responses: responses,
      );

      await _firestoreService.saveAssessment(assessment);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _proType == ProAssessmentType.poem
                ? 'POEM saved (score ${score.$1}, ${score.$2}).'
                : 'DLQI saved (score ${score.$1}, ${score.$2}).',
          ),
        ),
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving questionnaire: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEczema = widget.condition.toLowerCase() == 'eczema';
    final title = isEczema ? 'Weekly eczema questionnaire (POEM)' : 'Skin QoL questionnaire (DLQI)';
    final subtitle = isEczema
        ? 'Validated Patient-Oriented Eczema Measure. Reflects the last 7 days.'
        : 'Dermatology Life Quality Index. Reflects the last 7 days.';

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
      ),
      body: Column(
        children: [
          _buildHeader(subtitle),
          const Divider(height: 0),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _questions.length,
              itemBuilder: (context, index) {
                final q = _questions[index];
                return _buildQuestionCard(q, index);
              },
            ),
          ),
          _buildFooter(),
        ],
      ),
    );
  }

  Widget _buildHeader(String subtitle) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            subtitle,
            style: const TextStyle(fontSize: 13, color: Colors.black87),
          ),
          const SizedBox(height: 8),
          Text(
            'Run once per week. Your answers are shared with your doctor in reports.',
            style: TextStyle(fontSize: 12, color: Colors.grey[700]),
          ),
          if (_latest != null) ...[
            const SizedBox(height: 8),
            Text(
              'Last completed: ${_latest!.date.toLocal().toString().split(".").first} '
              '(${_latest!.totalScore}, ${_latest!.severityBand})',
              style: TextStyle(fontSize: 11, color: Colors.grey[600]),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildQuestionCard(ProQuestionnaireConfig q, int index) {
    final current = _scores[index];
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Q${index + 1}',
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey[600],
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              q.text,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            RadioGroup<int>(
              groupValue: current,
              onChanged: (v) {
                if (v == null) return;
                setState(() {
                  _scores[index] = v;
                });
              },
              child: Column(
                children: List.generate(q.options.length, (optIndex) {
                  final label = q.options[optIndex];
                  return RadioListTile<int>(
                    value: optIndex,
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      label,
                      style: const TextStyle(fontSize: 13),
                    ),
                  );
                }),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFooter() {
    final score = _currentScore;
    final disabled = !_allAnswered || _isSaving;
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.grey[50],
          border: Border(
            top: BorderSide(color: Colors.grey[300]!),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    score != null
                        ? 'Total score: ${score.$1}'
                        : 'Answer all questions to see your score.',
                    style: const TextStyle(fontSize: 13),
                  ),
                  if (score != null)
                    Text(
                      score.$2,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            ElevatedButton(
              onPressed: disabled ? null : _save,
              style: ElevatedButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
              child: _isSaving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
}

