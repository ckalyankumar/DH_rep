import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import 'package:dhealth/models/clinical_message.dart';
import 'package:dhealth/models/daily_log.dart';
import 'package:dhealth/models/doctor_session.dart';
import 'package:dhealth/services/clinical_messaging_service.dart';

/// Doctor view of the clinical messaging thread with a patient.
class DoctorClinicalThreadScreen extends StatefulWidget {
  final String patientId;
  final String? patientDisplayName;
  final String doctorEmail;
  final List<DailyLog> logs;

  const DoctorClinicalThreadScreen({
    super.key,
    required this.patientId,
    required this.patientDisplayName,
    required this.doctorEmail,
    required this.logs,
  });

  @override
  State<DoctorClinicalThreadScreen> createState() =>
      _DoctorClinicalThreadScreenState();
}

class _DoctorClinicalThreadScreenState extends State<DoctorClinicalThreadScreen> {
  final ClinicalMessagingService _messagingService = ClinicalMessagingService();
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isSending = false;
  DoctorSession? _lastView;

  @override
  void initState() {
    super.initState();
    _loadLastView();
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadLastView() async {
    final session = await _messagingService.getLastDoctorView(
      patientId: widget.patientId,
      doctorEmail: widget.doctorEmail,
    );
    if (mounted) setState(() => _lastView = session);
  }

  String get _dataRangeReviewed {
    if (widget.logs.isEmpty) return '';
    final sorted = List<DailyLog>.from(widget.logs)..sort((a, b) => a.date.compareTo(b.date));
    final start = DateFormat('yyyy-MM-dd').format(sorted.first.date);
    final end = DateFormat('yyyy-MM-dd').format(sorted.last.date);
    return '$start to $end';
  }

  Future<void> _sendMessage() async {
    final content = _controller.text.trim();
    if (content.isEmpty || _isSending) return;

    setState(() => _isSending = true);
    _controller.clear();

    try {
      await _messagingService.sendMessage(
        patientId: widget.patientId,
        doctorEmail: widget.doctorEmail,
        sender: 'doctor',
        content: content,
        dataRangeReviewed: _dataRangeReviewed.isNotEmpty ? _dataRangeReviewed : null,
      );
      if (mounted) {
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.patientDisplayName ?? 'Patient',
              style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            Text(
              'Clinical thread',
              style: GoogleFonts.inter(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          _buildDisclaimer(),
          if (_lastView != null) _buildLastViewed(),
          Expanded(
            child: StreamBuilder<List<ClinicalMessage>>(
              stream: _messagingService.streamMessages(
                patientId: widget.patientId,
                doctorEmail: widget.doctorEmail,
              ),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                final messages = snapshot.data ?? [];
                if (messages.isEmpty) {
                  return Center(
                    child: Text(
                      'No messages yet. Start the conversation.',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  );
                }
                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final msg = messages[index];
                    return _buildMessageBubble(msg);
                  },
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(
              'Read-only. This data belongs to your patient.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.grey[700]),
            ),
          ),
          _buildComposer(),
        ],
      ),
    );
  }

  Widget _buildDisclaimer() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange[50],
        border: Border.all(color: Colors.orange),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, color: Colors.orange[700], size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'For care coordination only. Not for emergencies.',
              style: TextStyle(fontSize: 12, color: Colors.orange[900]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLastViewed() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(Icons.visibility, size: 16, color: Colors.grey[600]),
          const SizedBox(width: 8),
          Text(
            'Last viewed data: ${DateFormat('MMM d, yyyy').format(_lastView!.viewedAt)}',
            style: TextStyle(fontSize: 12, color: Colors.grey[700]),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(ClinicalMessage msg) {
    final isDoctor = msg.isFromDoctor;
    return Align(
      alignment: isDoctor ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        decoration: BoxDecoration(
          color: isDoctor ? Theme.of(context).primaryColor.withValues(alpha:0.15) : Colors.grey[200],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              msg.content,
              style: const TextStyle(fontSize: 14),
            ),
            if (msg.dataRangeReviewed != null) ...[
              const SizedBox(height: 4),
              Text(
                'Based on data: ${msg.dataRangeReviewed}',
                style: TextStyle(fontSize: 11, color: Colors.grey[600]),
              ),
            ],
            const SizedBox(height: 4),
            Text(
              DateFormat('MMM d, HH:mm').format(msg.sentAt),
              style: TextStyle(fontSize: 11, color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildComposer() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha:0.05),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              decoration: const InputDecoration(
                hintText: 'Type a message...',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              maxLines: 3,
              minLines: 1,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _sendMessage(),
            ),
          ),
          const SizedBox(width: 12),
          IconButton.filled(
            onPressed: _isSending ? null : _sendMessage,
            icon: _isSending
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.send),
            tooltip: 'Send',
          ),
        ],
      ),
    );
  }
}
