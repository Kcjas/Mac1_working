import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class IncomingRequestsPage extends StatefulWidget {
  final int workerId;

  const IncomingRequestsPage({super.key, required this.workerId});

  @override
  State<IncomingRequestsPage> createState() => _IncomingRequestsPageState();
}

class _IncomingRequestsPageState extends State<IncomingRequestsPage> {
  late Future<List<Map<String, dynamic>>> _jobRequests;

  @override
  void initState() {
    super.initState();
    _jobRequests = fetchIncomingRequests();
  }

  Future<List<Map<String, dynamic>>> fetchIncomingRequests() async {
    final url = Uri.parse("http://192.168.1.12:8000/worker/${widget.workerId}/incoming-requests");
    final response = await http.get(url);

    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      return data.cast<Map<String, dynamic>>();
    } else {
      throw Exception("Failed to fetch job requests");
    }
  }

  Future<void> _respondToRequest(int requestId, String action) async {
    final url = Uri.parse("http://192.168.1.12:8000/job-request/$requestId/respond?decision=$action");
    final response = await http.post(
    url,
    headers: {"Content-Type": "application/json"},
    );

    if (response.statusCode == 200) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Request ${action == 'accepted' ? 'accepted' : 'rejected'}")),
      );
      setState(() {
        _jobRequests = fetchIncomingRequests();  
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to respond: ${response.body}")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Incoming Requests")),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _jobRequests,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text("No incoming job requests"));
          }

          final requests = snapshot.data!;
          return ListView.builder(
            itemCount: requests.length,
            itemBuilder: (context, index) {
              final req = requests[index];
              return Card(
                margin: const EdgeInsets.all(12),
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("🧑 Customer: ${req['customer_name']}", style: const TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text("📋 Job: ${req['description']}"),
                      Text("📅 Time: ${req['preferred_datetime']}"),
                      Text("📍 Address: ${req['customer_address']}"),
                      Text("📏 Distance: ${req['distance']} km"),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => _respondToRequest(req['job_id'], 'rejected'),
                            child: const Text("Reject", style: TextStyle(color: Colors.red)),
                          ),
                          const SizedBox(width: 10),
                          ElevatedButton(
                            onPressed: () => _respondToRequest(req['job_id'], 'accepted'),
                            child: const Text("Accept"),
                          ),
                        ],
                      )
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
