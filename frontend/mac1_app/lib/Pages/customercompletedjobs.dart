import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class Customercompletedjobs extends StatefulWidget {
  final int userId;

  const Customercompletedjobs({super.key, required this.userId});

  @override
  State<Customercompletedjobs> createState() => _CompletedJobPageState();
}

class _CompletedJobPageState extends State<Customercompletedjobs> {
  late Future<List<Map<String, dynamic>>> _completedJobs;

  @override
  void initState() {
    super.initState();
    _completedJobs = fetchCompletedJobs(widget.userId);
  }

  Future<List<Map<String, dynamic>>> fetchCompletedJobs(int userId) async {
    final url = Uri.parse("http://192.168.1.2:8000/customer/$userId/completed-jobs");

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
    return Scaffold(
      appBar: AppBar(title: const Text("Completed Jobs")),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _completedJobs,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text("No completed jobs found."));
          }

          final jobs = snapshot.data!;

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: jobs.length,
            itemBuilder: (context, index) {
              final job = jobs[index];

              return Card(
                margin: const EdgeInsets.only(bottom: 16),
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        job['job-title'] ?? 'No title',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 6),
                      Text(" ${job['date']} || ${job['time']}"),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          ElevatedButton(
                            onPressed: () {
                              Navigator.pushNamed(
                                context,
                                '/payslip',
                                arguments: job['booking_id'],
                              );
                            },
                            child: const Text("View Payslip"),
                          ),
                          ElevatedButton(
                            onPressed: () {
                              Navigator.pushNamed(
                                context,
                                '/rate',
                                arguments: {
                                  'customer_id': widget.userId,
                                  'worker_id': job['worker_id'],
                                },
                              );
                            },
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                            child: const Text("Rate Job"),
                          ),
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
