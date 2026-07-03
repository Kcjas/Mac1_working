import 'dart:async';
import 'package:flutter/material.dart';
import '../services/api_service.dart';

/// Full-screen, back-blocked "Job In Progress" view shown to both the worker
/// and the customer while a booking is `in_progress`.
///
/// The live timer counts up from the server's [startedAt] (so both devices
/// agree and it survives an app restart — elapsed is recomputed from
/// [startedAt], never a local stopwatch).
///
/// Worker variant: a "Job Complete" button that asks for the customer's
/// completion PIN, then routes to the itemized-cost form.
/// Customer variant: view-only; shows the completion PIN to read aloud and
/// polls until the worker stops the timer, then leaves this screen.
class JobInProgressPage extends StatefulWidget {
  final int bookingId;
  final int userId;
  final bool isWorker;
  final DateTime startedAt;
  final String jobTitle;
  final String otherName;
  final String? completePin; // customer only

  const JobInProgressPage({
    super.key,
    required this.bookingId,
    required this.userId,
    required this.isWorker,
    required this.startedAt,
    required this.jobTitle,
    required this.otherName,
    this.completePin,
  });

  @override
  State<JobInProgressPage> createState() => _JobInProgressPageState();
}

class _JobInProgressPageState extends State<JobInProgressPage> {
  Timer? _ticker;
  Timer? _poller;
  Duration _elapsed = Duration.zero;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _recompute();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _recompute());
    // The customer waits here until the worker stops the timer.
    if (!widget.isWorker) {
      _poller = Timer.periodic(const Duration(seconds: 5), (_) => _pollStatus());
    }
  }

  void _recompute() {
    final e = DateTime.now().difference(widget.startedAt);
    setState(() => _elapsed = e.isNegative ? Duration.zero : e);
  }

  Future<void> _pollStatus() async {
    try {
      final summary = await ApiService.fetchBookingSummary(widget.bookingId);
      final status = summary['status']?.toString();
      if (status != null && status != 'in_progress' && mounted) {
        // Worker has stopped the timer — head to the bill review screen.
        _poller?.cancel();
        Navigator.pushReplacementNamed(
          context,
          '/confirmBill',
          arguments: {'bookingId': widget.bookingId, 'userId': widget.userId},
        );
      }
    } catch (_) {
      // Transient errors are fine; the next tick retries.
    }
  }

  String _fmt(Duration d) {
    String two(int n) => n.toString().padLeft(2, '0');
    return "${two(d.inHours)}:${two(d.inMinutes % 60)}:${two(d.inSeconds % 60)}";
  }

  Future<void> _completeJob() async {
    final pin = await _askPin();
    if (pin == null || pin.isEmpty) return;
    setState(() => _busy = true);
    try {
      await ApiService.completeJob(widget.bookingId, pin);
      if (!mounted) return;
      // Timer stopped — go to the itemized cost form.
      Navigator.pushReplacementNamed(
        context,
        '/completedJobs',
        arguments: {'booking_id': widget.bookingId, 'userId': widget.userId},
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("$e".replaceFirst('Exception: ', '')), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<String?> _askPin() {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Completion code"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Ask the customer for their completion code and enter it below."),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              maxLength: 6,
              decoration: const InputDecoration(
                hintText: "6-digit code",
                border: OutlineInputBorder(),
                counterText: "",
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text("Stop timer"),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _poller?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Block back navigation: the job must run to completion from this screen.
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: const Color(0xFF1A1A1A),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 24),
                const Text(
                  "JOB IN PROGRESS",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(0xFFFF4D00),
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  widget.jobTitle,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w600),
                ),
                Text(
                  widget.isWorker ? "for ${widget.otherName}" : "with ${widget.otherName}",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey.shade400, fontSize: 14),
                ),
                const Spacer(),
                // Live timer
                Column(
                  children: [
                    Text("CURRENT", style: TextStyle(color: Colors.grey.shade500, fontSize: 12, letterSpacing: 2)),
                    const SizedBox(height: 8),
                    Text(
                      _fmt(_elapsed),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 56,
                        fontWeight: FontWeight.w700,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                if (!widget.isWorker && widget.completePin != null) _customerPinCard(),
                if (widget.isWorker) _workerCompleteButton(),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _customerPinCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Column(
        children: [
          Text(
            "When the job is done, read this completion code to the worker",
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade300, fontSize: 13),
          ),
          const SizedBox(height: 12),
          Text(
            widget.completePin!,
            style: const TextStyle(
              color: Color(0xFFFF4D00),
              fontSize: 40,
              fontWeight: FontWeight.w900,
              letterSpacing: 8,
            ),
          ),
        ],
      ),
    );
  }

  Widget _workerCompleteButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _busy ? null : _completeJob,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFFF4D00),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 18),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          elevation: 0,
        ),
        child: _busy
            ? const SizedBox(
                height: 22, width: 22,
                child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(Colors.white)),
              )
            : const Text("Job Complete", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
      ),
    );
  }
}
