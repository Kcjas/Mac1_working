import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class CustomerBookingPreview extends StatefulWidget {
  final int userId;

  const CustomerBookingPreview({
    super.key,
    required this.userId,
  });

  @override
  State<CustomerBookingPreview> createState() => _CustomerBookingPreviewState();
}

class _CustomerBookingPreviewState extends State<CustomerBookingPreview> {
  late Future<List<Map<String, dynamic>>> _upcomingJobs;

  @override
  void initState() {
    super.initState();
    _upcomingJobs = fetchUpcomingJobs(widget.userId);

  }

  Future<List<Map<String, dynamic>>> fetchUpcomingJobs(int userId) async {
    final url = Uri.parse("http://192.168.1.2:8000/customer/${widget.userId}/upcoming-jobs");

    final response = await http.get(url);
    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      return data.cast<Map<String, dynamic>>();
    } else {
      throw Exception("Failed to load upcoming jobs");
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _upcomingJobs,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: CircularProgressIndicator(),
          );
        } else if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Text('No upcoming jobs'),
          );
        }

        final jobs = snapshot.data!;
        final previewJobs = jobs.take(3).toList();

        return Card(
          margin: const EdgeInsets.all(16),
          elevation: 4,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                const Text(
                  "Upcoming Jobs",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                ...previewJobs.map((job) => ListTile(
                      title: Text((job['job-title'] ?? 'No title') as String),
                      subtitle: Text("Date: ${(job['date'] ?? 'N/A') as String} | Time: ${(job['time'] ?? 'N/A') as String}"),
                      dense: true
                    )),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () {
                      Navigator.pushNamed(context, '/upcomingJobs', arguments: widget.userId);
                    },
                    child: const Text("View All"),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
