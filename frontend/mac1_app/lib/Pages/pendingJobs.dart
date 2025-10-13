import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

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
    final url = Uri.parse("http://10.130.27.237:8000/worker/${widget.userId}/pending-jobs");

    final response = await http.get(url);

    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      return data.cast<Map<String, dynamic>>();
    } else {
      throw Exception("Failed to load jobs");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Pending Jobs")),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _jobsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text("Error: ${snapshot.error}"));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text("No pending jobs"));
          }

          final jobs = snapshot.data!;
          return ListView.builder(
            itemCount: jobs.length,
            itemBuilder: (context, index) {
              final job = jobs[index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListTile(
                  title: Text("${job["job_title"]}"),
                  subtitle: Text(
                    "Customer: ${job["customer_name"]}\n"
                    "Address: ${job["address"]}\n"
                    "Date: ${job["date"]}  Time: ${job["time"]}",
                  ),
                  isThreeLine: true,
                  trailing: ElevatedButton(
                    onPressed: (){
                      Navigator.pushNamed(
                        context, 
                        '/completedJobs',
                        arguments: {
                          'booking_id': job['booking_id'],
                          'userId': widget.userId
                        }
                      );
                    }, 
                    child: const Text("Job Done?")
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
