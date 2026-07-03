import 'package:flutter/material.dart';
import '../services/auth_http.dart';
import '../services/api_service.dart';
import 'dart:convert';
import '../config/api_config.dart';
import 'widgets/chat_message_button.dart';

class PendingJobsPage extends StatefulWidget {
  final int userId;

  const PendingJobsPage({super.key, required this.userId});

  @override
  State<PendingJobsPage> createState() => _PendingJobsPageState();
}

class _PendingJobsPageState extends State<PendingJobsPage> {
  late Future<List<Map<String, dynamic>>> _jobsFuture;

  @override
  void initState() {
    super.initState();
    _jobsFuture = fetchPendingJobs();
  }

  Future<List<Map<String, dynamic>>> fetchPendingJobs() async {
    final baseUrl = await ApiConfig.getBaseUrl();
    final url = Uri.parse("$baseUrl/worker/${widget.userId}/pending-jobs");
    final response = await AuthHttp.get(url);
    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      return data.cast<Map<String, dynamic>>();
    } else {
      throw Exception("Failed to load jobs");
    }
  }

  void _refresh() => setState(() => _jobsFuture = fetchPendingJobs());

  /// The per-card primary action depends on where the booking is in the flow.
  Widget _buildAction(Map<String, dynamic> job) {
    final status = job['status']?.toString() ?? 'pending';
    final bookingId = job['booking_id'] as int?;
    switch (status) {
      case 'in_progress':
        return _filledButton("Resume Job", const Color(0xFFFF4D00),
            () => _openInProgress(job));
      case 'awaiting_costs':
        return _filledButton("Enter Costs", Colors.black87, () {
          Navigator.pushNamed(context, '/completedJobs',
              arguments: {'booking_id': bookingId, 'userId': widget.userId}).then((_) => _refresh());
        });
      case 'awaiting_confirmation':
        return _filledButton("Waiting for customer", Colors.grey.shade400, null);
      case 'pending':
      default:
        return _filledButton("Start Job", Colors.black87, () => _startJob(job));
    }
  }

  Widget _filledButton(String label, Color color, VoidCallback? onPressed) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        disabledBackgroundColor: Colors.grey.shade300,
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        elevation: 0,
      ),
      child: Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
    );
  }

  Future<void> _startJob(Map<String, dynamic> job) async {
    final bookingId = job['booking_id'] as int?;
    if (bookingId == null) return;
    final pin = await _askStartPin();
    if (pin == null || pin.isEmpty) return;
    try {
      final res = await ApiService.startJob(bookingId, pin);
      if (!mounted) return;
      _gotoInProgress(job, res['started_at']?.toString());
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text("$e".replaceFirst('Exception: ', '')),
        backgroundColor: Colors.red,
      ));
    }
  }

  void _openInProgress(Map<String, dynamic> job) =>
      _gotoInProgress(job, job['started_at']?.toString());

  void _gotoInProgress(Map<String, dynamic> job, String? startedAt) {
    if (startedAt == null) {
      _refresh();
      return;
    }
    Navigator.pushNamed(context, '/jobInProgress', arguments: {
      'bookingId': job['booking_id'],
      'userId': widget.userId,
      'isWorker': true,
      'startedAt': startedAt,
      'jobTitle': job['job_title'] ?? 'Job',
      'otherName': job['customer_name'] ?? 'Customer',
    }).then((_) => _refresh());
  }

  Future<String?> _askStartPin() {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Start code"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Ask the customer for their start code and enter it below."),
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
            child: const Text("Start"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text("Pending Jobs"),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black87,
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _jobsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 64, color: Colors.red.shade300),
                  const SizedBox(height: 16),
                  Text(
                    "Error: ${snapshot.error}",
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey.shade600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.schedule, size: 64, color: Colors.grey.shade400),
                  const SizedBox(height: 16),
                  Text(
                    "No pending jobs",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            );
          }

          final jobs = snapshot.data!;
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: jobs.length,
            itemBuilder: (context, index) {
              final job = jobs[index];
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        job["job_title"]?.toString() ?? "No title",
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Icon(Icons.person, size: 16, color: Colors.grey.shade600),
                          const SizedBox(width: 6),
                          Text(
                            job["customer_name"]?.toString() ?? "Unknown",
                            style: const TextStyle(fontSize: 14),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.location_on, size: 16, color: Colors.blue.shade600),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              job["address"]?.toString() ?? "No address",
                              style: const TextStyle(fontSize: 14),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.calendar_today, size: 16, color: Colors.grey.shade600),
                          const SizedBox(width: 6),
                          Text(
                            job["date"]?.toString() ?? "N/A",
                            style: const TextStyle(fontSize: 14),
                          ),
                          const SizedBox(width: 16),
                          Icon(Icons.access_time, size: 16, color: Colors.grey.shade600),
                          const SizedBox(width: 6),
                          Text(
                            job["time"]?.toString() ?? "N/A",
                            style: const TextStyle(fontSize: 14),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          MessageButton(
                            unread: (job['unread_count'] as num?)?.toInt() ?? 0,
                            onPressed: () => Navigator.pushNamed(
                              context,
                              '/chat',
                              arguments: {
                                'bookingId': job['booking_id'],
                                'otherName': job['customer_name'] ?? 'Customer',
                                'chatOpen': true,
                              },
                            ).then((_) => setState(() => _jobsFuture = fetchPendingJobs())),
                          ),
                          const SizedBox(width: 8),
                          Expanded(child: _buildAction(job)),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
