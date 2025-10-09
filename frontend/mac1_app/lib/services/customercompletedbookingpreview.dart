import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class CustomerCompletedBookingPreview extends StatefulWidget {
  final int userId;

  const CustomerCompletedBookingPreview({
    super.key,
    required this.userId,
  });

  @override
  State<CustomerCompletedBookingPreview> createState() => _CustomerCompletedBookingPreviewState();
}

class _CustomerCompletedBookingPreviewState extends State<CustomerCompletedBookingPreview> {
  late Future<List<Map<String, dynamic>>> _completedJobs;

  @override
  void initState() {
    super.initState();
    _completedJobs = fetchCompletedJobs(widget.userId);
  }

  Future<List<Map<String, dynamic>>> fetchCompletedJobs(int userId) async {
    final url = Uri.parse("http://10.121.172.237:8000/customer/$userId/completed-jobs");

    final response = await http.get(url);
    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      return data.cast<Map<String, dynamic>>();
    } else {
      throw Exception("Failed to load completed jobs");
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _completedJobs,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        } else if (snapshot.hasError) {
          return const Padding(
            padding: EdgeInsets.all(12),
            child: Text("Error loading completed jobs."),
          );
        } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(12),
            child: Text("No completed jobs yet."),
          );
        }

        final jobs = snapshot.data!;
        final previewJobs = jobs.take(2).toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Completed Jobs",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            ...previewJobs.map((job) {
              return Card(
                margin: const EdgeInsets.symmetric(vertical: 6),
                elevation: 2,
                child: ListTile(
                  title: Text(job['job-title'] ?? 'No title'),
                  subtitle: Text(" ${job['date']} |  ${job['time']}"),
                  trailing: ElevatedButton(
                    onPressed: () {
                      Navigator.pushNamed(
                        context,
                        '/payslip',
                        arguments: job['booking_id'],
                      );
                    },
                    child: const Text("View Payslip"),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
              );
            }),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () {
                  Navigator.pushNamed(
                    context,
                    '/completedJobList',
                    arguments: widget.userId,
                  );
                },
                child: const Text("View All"),
              ),
            )
          ],
        );
      },
    );
  }
}
