import 'package:flutter/material.dart';
import '../services/api_service.dart';

/// Worker's itemized additional-cost form, shown after the completion PIN stops
/// the timer. Each line is a reason + amount; submitting sends the bill to the
/// customer for approval (`/booking/{id}/finalize`). Duration is no longer
/// entered here — it is measured by the server timer.
class CompletedJobPage extends StatefulWidget {
  final int booking_id;
  final int userId;

  const CompletedJobPage({super.key, required this.booking_id, required this.userId});

  @override
  State<CompletedJobPage> createState() => _CompletedJobPageState();
}

class _CostRow {
  final TextEditingController reason = TextEditingController();
  final TextEditingController cost = TextEditingController();
  void dispose() {
    reason.dispose();
    cost.dispose();
  }
}

class _CompletedJobPageState extends State<CompletedJobPage> {
  final List<_CostRow> _rows = [];
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _rows.add(_CostRow()); // start with one (optional) line
  }

  void _addRow() => setState(() => _rows.add(_CostRow()));

  void _removeRow(int i) {
    setState(() {
      _rows[i].dispose();
      _rows.removeAt(i);
    });
  }

  Future<void> _submit() async {
    // Build the extras list. A row counts only if a reason was entered; each such
    // row must have a valid non-negative cost.
    final extras = <Map<String, dynamic>>[];
    for (final r in _rows) {
      final reason = r.reason.text.trim();
      final costText = r.cost.text.trim();
      if (reason.isEmpty && costText.isEmpty) continue;
      if (reason.isEmpty) {
        _snack("Every cost needs a reason", Colors.red);
        return;
      }
      final cost = double.tryParse(costText);
      if (cost == null || cost < 0) {
        _snack("Enter a valid amount for '$reason'", Colors.red);
        return;
      }
      extras.add({"reason": reason, "cost": cost});
    }

    setState(() => _isSubmitting = true);
    try {
      await ApiService.finalizeJob(widget.booking_id, extras);
      if (!mounted) return;
      _snack("Bill sent to the customer for approval", Colors.green);
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      _snack("$e".replaceFirst('Exception: ', ''), Colors.red);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _snack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: color));
  }

  @override
  void dispose() {
    for (final r in _rows) {
      r.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text("Additional Costs"),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black87,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            "Add any extra costs (materials, parts). Leave empty if there are none. "
            "The customer reviews the full bill before it's confirmed.",
            style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 16),
          ...List.generate(_rows.length, (i) => _costRowCard(i)),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _addRow,
            icon: const Icon(Icons.add),
            label: const Text("Add another cost"),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.black87,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isSubmitting ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF4D00),
                foregroundColor: Colors.white,
                disabledBackgroundColor: Colors.grey.shade400,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                elevation: 0,
              ),
              child: _isSubmitting
                  ? const SizedBox(
                      height: 20, width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(Colors.white)),
                    )
                  : const Text("Send Bill to Customer",
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _costRowCard(int i) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 3,
              child: TextField(
                controller: _rows[i].reason,
                decoration: const InputDecoration(
                  labelText: "Reason",
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 2,
              child: TextField(
                controller: _rows[i].cost,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: "Amount (₹)",
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ),
            if (_rows.length > 1)
              IconButton(
                onPressed: () => _removeRow(i),
                icon: Icon(Icons.close, color: Colors.grey.shade500),
              ),
          ],
        ),
      ),
    );
  }
}
