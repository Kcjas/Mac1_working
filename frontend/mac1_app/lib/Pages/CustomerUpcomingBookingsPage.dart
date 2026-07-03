import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'widgets/chat_message_button.dart';

class CustomerUpcomingBookingsPage extends StatefulWidget {
  final int userId;

  const CustomerUpcomingBookingsPage({super.key, required this.userId});

  @override
  State<CustomerUpcomingBookingsPage> createState() => _CustomerUpcomingBookingsPageState();
}

class _CustomerUpcomingBookingsPageState extends State<CustomerUpcomingBookingsPage> {
  late Future<List<Map<String, dynamic>>> _upcomingJobs;

  @override
  void initState() {
    super.initState();
    _upcomingJobs = fetchUpcomingJobs(widget.userId);
  }

  Future<List<Map<String, dynamic>>> fetchUpcomingJobs(int userId) async {
    return ApiService.fetchCustomerUpcomingJobs(userId);
  }

  void _refresh() => setState(() => _upcomingJobs = fetchUpcomingJobs(widget.userId));

  /// Per-card section that reflects where the booking is in the completion flow:
  /// shows the start code while pending, a button into the live timer while
  /// in progress, and a "Review bill" button once the worker submits the bill.
  Widget _statusSection(Map<String, dynamic> job) {
    final status = job['status']?.toString() ?? 'pending';
    switch (status) {
      case 'in_progress':
        return Padding(
          padding: const EdgeInsets.only(top: 16),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.timer),
              label: const Text("View live job"),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF4D00),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              onPressed: () {
                final startedAt = job['started_at']?.toString();
                if (startedAt == null) return;
                Navigator.pushNamed(context, '/jobInProgress', arguments: {
                  'bookingId': job['booking_id'],
                  'userId': widget.userId,
                  'isWorker': false,
                  'startedAt': startedAt,
                  'jobTitle': job['job-title'] ?? 'Job',
                  'otherName': job['worker_name'] ?? 'Worker',
                  'completePin': job['complete_pin'],
                }).then((_) => _refresh());
              },
            ),
          ),
        );
      case 'awaiting_costs':
        return Padding(
          padding: const EdgeInsets.only(top: 16),
          child: Text(
            "Worker is adding the final costs…",
            style: TextStyle(color: Colors.grey.shade600, fontStyle: FontStyle.italic),
          ),
        );
      case 'awaiting_confirmation':
        return Padding(
          padding: const EdgeInsets.only(top: 16),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.receipt_long),
              label: const Text("Review bill"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black87,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              onPressed: () => Navigator.pushNamed(context, '/confirmBill', arguments: {
                'bookingId': job['booking_id'],
                'userId': widget.userId,
              }).then((_) => _refresh()),
            ),
          ),
        );
      case 'pending':
      default:
        final startPin = job['start_pin']?.toString();
        if (startPin == null) return const SizedBox.shrink();
        return _pinCard("Give this start code to the worker", startPin);
    }
  }

  Widget _pinCard(String label, String pin) {
    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFF4D00).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFF4D00).withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Expanded(child: Text(label, style: TextStyle(color: Colors.grey.shade800, fontSize: 13))),
          Text(
            pin,
            style: const TextStyle(
              color: Color(0xFFFF4D00),
              fontSize: 24,
              fontWeight: FontWeight.w900,
              letterSpacing: 4,
            ),
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
        title: const Text(
          "Upcoming Bookings",
          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 24),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black,
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _upcomingJobs,
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
                  Text("Error: ${snapshot.error}", style: TextStyle(color: Colors.grey.shade600)),
                ],
              ),
            );
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.event_busy,
                    size: 64,
                    color: Colors.grey.shade300,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    "No upcoming bookings",
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w500,
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
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFF4D00),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Icon(
                              Icons.event,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  job['job-title'] ?? 'No title',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.black87,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.person,
                                      size: 14,
                                      color: Colors.grey.shade600,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      job['worker_name'] ?? 'Worker',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey.shade700,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          if (job['booking_id'] != null)
                            MessageButton(
                              unread: (job['unread_count'] as num?)?.toInt() ?? 0,
                              onPressed: () => Navigator.pushNamed(
                                context,
                                '/chat',
                                arguments: {
                                  'bookingId': job['booking_id'],
                                  'otherName': job['worker_name'] ?? 'Worker',
                                  'chatOpen': true,
                                },
                              ).then((_) => setState(
                                  () => _upcomingJobs = fetchUpcomingJobs(widget.userId))),
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const Divider(height: 1),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                Icon(
                                  Icons.calendar_today,
                                  size: 16,
                                  color: Colors.grey.shade600,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  job['date'] ?? 'N/A',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            child: Row(
                              children: [
                                Icon(
                                  Icons.access_time,
                                  size: 16,
                                  color: Colors.grey.shade600,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  job['time'] ?? 'N/A',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                          Row(
                            children: [
                              Icon(Icons.location_on, size: 16, color: Colors.red.shade400),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  job['address'] ?? 'No address',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey.shade800,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                      _statusSection(job),
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
