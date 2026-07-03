import 'dart:async';
import 'package:flutter/material.dart';
import '../services/api_service.dart';

/// Customer's bill-review screen. While the worker is still entering costs
/// (`awaiting_costs`) it shows a waiting loader and polls the summary; once the
/// worker submits (`awaiting_confirmation`) it renders the full bill with an
/// **OK** button that confirms the booking and credits the worker.
class ConfirmBillPage extends StatefulWidget {
  final int bookingId;
  final int userId;

  const ConfirmBillPage({super.key, required this.bookingId, required this.userId});

  @override
  State<ConfirmBillPage> createState() => _ConfirmBillPageState();
}

class _ConfirmBillPageState extends State<ConfirmBillPage> {
  Timer? _poller;
  Map<String, dynamic>? _summary;
  String? _error;
  bool _confirming = false;

  @override
  void initState() {
    super.initState();
    _load();
    _poller = Timer.periodic(const Duration(seconds: 5), (_) => _load());
  }

  Future<void> _load() async {
    try {
      final s = await ApiService.fetchBookingSummary(widget.bookingId);
      if (!mounted) return;
      setState(() {
        _summary = s;
        _error = null;
      });
      // Stop polling once there's nothing left to wait for.
      final status = s['status']?.toString();
      if (status == 'awaiting_confirmation' || status == 'completed') {
        _poller?.cancel();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = "$e".replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _confirm() async {
    setState(() => _confirming = true);
    try {
      await ApiService.confirmBooking(widget.bookingId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text("Job confirmed. Thank you!"),
        backgroundColor: Colors.green,
      ));
      Navigator.pushReplacementNamed(context, '/payslip', arguments: widget.bookingId);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text("$e".replaceFirst('Exception: ', '')),
        backgroundColor: Colors.red,
      ));
    } finally {
      if (mounted) setState(() => _confirming = false);
    }
  }

  @override
  void dispose() {
    _poller?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final status = _summary?['status']?.toString();
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text("Review Bill"),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black87,
      ),
      body: _error != null && _summary == null
          ? _centered(Icons.error_outline, Colors.red.shade300, "Error: $_error")
          : status == 'awaiting_confirmation' || status == 'completed'
              ? _billView()
              : _waiting(),
    );
  }

  Widget _waiting() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(color: Color(0xFFFF4D00)),
          const SizedBox(height: 24),
          Text(
            "Waiting for the worker to\nstate any additional costs…",
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, color: Colors.grey.shade700),
          ),
        ],
      ),
    );
  }

  Widget _billView() {
    final s = _summary!;
    final extras = (s['extras'] as List?) ?? const [];
    final timeTaken = (s['time_taken'] as num?)?.toDouble() ?? 0.0;
    final serviceCost = (s['service_cost'] as num?)?.toDouble() ?? 0.0;
    final commission = (s['commission'] as num?)?.toDouble() ?? 0.0;
    final extraCost = (s['extra_cost'] as num?)?.toDouble() ?? 0.0;
    final total = (s['total_cost'] as num?)?.toDouble() ?? 0.0;
    final done = s['status']?.toString() == 'completed';

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _card([
          _line("Job", s['job_title']?.toString() ?? '-'),
          _line("Worker", s['worker_name']?.toString() ?? '-'),
          _line("Time taken", "${timeTaken.toStringAsFixed(2)} h"),
        ]),
        const SizedBox(height: 12),
        _card([
          _line("Service cost", "₹${serviceCost.toStringAsFixed(2)}"),
          _line("Commission (10%)", "₹${commission.toStringAsFixed(2)}"),
          if (extras.isNotEmpty) ...[
            const Divider(),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 4),
              child: Text("Additional costs", style: TextStyle(fontWeight: FontWeight.w600)),
            ),
            ...extras.map((e) => _line(
                  e['reason']?.toString() ?? '-',
                  "₹${((e['cost'] as num?)?.toDouble() ?? 0).toStringAsFixed(2)}",
                )),
          ] else
            _line("Additional costs", "₹${extraCost.toStringAsFixed(2)}"),
        ]),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Total", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600)),
              Text("₹${total.toStringAsFixed(2)}",
                  style: const TextStyle(color: Color(0xFFFF4D00), fontSize: 22, fontWeight: FontWeight.w900)),
            ],
          ),
        ),
        const SizedBox(height: 24),
        if (done)
          Center(child: Text("Confirmed", style: TextStyle(color: Colors.green.shade700, fontWeight: FontWeight.w600)))
        else
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _confirming ? null : _confirm,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF4D00),
                foregroundColor: Colors.white,
                disabledBackgroundColor: Colors.grey.shade400,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                elevation: 0,
              ),
              child: _confirming
                  ? const SizedBox(
                      height: 20, width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(Colors.white)),
                    )
                  : const Text("OK, Confirm & Pay",
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            ),
          ),
      ],
    );
  }

  Widget _card(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Padding(padding: const EdgeInsets.all(16), child: Column(children: children)),
    );
  }

  Widget _line(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(child: Text(label, style: TextStyle(color: Colors.grey.shade700))),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _centered(IconData icon, Color color, String text) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: color),
          const SizedBox(height: 16),
          Padding(padding: const EdgeInsets.all(16), child: Text(text, textAlign: TextAlign.center)),
        ],
      ),
    );
  }
}
