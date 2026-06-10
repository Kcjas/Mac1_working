import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../services/auth_http.dart';
import 'dart:convert';
import '../services/address.dart';
import '../config/api_config.dart';

class IncomingRequestsPage extends StatefulWidget {
  final int workerId;

  const IncomingRequestsPage({
    super.key,
    required this.workerId,
  });

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
    final baseUrl = await ApiConfig.getBaseUrl();
    final url = Uri.parse("$baseUrl/worker/${widget.workerId}/incoming-requests");
    final response = await AuthHttp.get(url);

    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      return data.cast<Map<String, dynamic>>();
    } else {
      throw Exception("Failed to fetch job requests: ${response.body}");
    }
  }

  Future<void> _respondToRequest(int requestId, String action) async {
    final baseUrl = await ApiConfig.getBaseUrl();
    final url = Uri.parse("$baseUrl/job-request/$requestId/respond?decision=$action");
    final response = await AuthHttp.post(
      url,
      headers: {"Content-Type": "application/json"},
    );


    if (response.statusCode == 200) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Request ${action == 'accepted' ? 'accepted' : 'rejected'}"),
          backgroundColor: action == 'accepted' ? Colors.green : Colors.red,
        ),
      );
      setState(() {
        _jobRequests = fetchIncomingRequests();
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Failed to respond: ${response.body}"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<String> _getCustomerAddress(Map<String, dynamic> req) async {
    final lat = (req['customer_lat'] as num).toDouble();
    final lon = (req['customer_lon'] as num).toDouble();
    return await LocationHelper.getAddressFromLatLng(lat, lon);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text("Incoming Requests"),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black87,
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _jobRequests,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(
              child: Text(
                "Error: ${snapshot.error}",
                textAlign: TextAlign.center,
              ),
            );
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.inbox_outlined, size: 64, color: Colors.grey.shade400),
                  const SizedBox(height: 16),
                  Text(
                    "No incoming job requests",
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

          final requests = snapshot.data!;
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: requests.length,
            itemBuilder: (context, index) {
              final req = requests[index];
              final distance = req['distance']; 

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
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              Icons.person,
                              color: Colors.blue.shade600,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  req['customer_name'] ?? "Customer",
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.black87,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  req['description'] ?? "",
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey.shade600,
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
                          Icon(Icons.calendar_today, size: 16, color: Colors.grey.shade600),
                          const SizedBox(width: 4),
                          Text(
                            req['preferred_datetime'] ?? "",
                            style: const TextStyle(fontSize: 13),
                          ),
                        ],
                      ),

                      const SizedBox(height: 8),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.location_on, size: 16, color: Colors.blue.shade600),
                          const SizedBox(width: 4),
                          Expanded(
                            child: FutureBuilder<String>(
                              future: _getCustomerAddress(req),
                              builder: (context, snapshot) {
                                if (snapshot.connectionState == ConnectionState.waiting) {
                                  return const Text(
                                    "Resolving address...",
                                    style: TextStyle(fontSize: 13),
                                  );
                                }
                                if (snapshot.hasError) {
                                  return const Text(
                                    "Error retrieving address",
                                    style: TextStyle(fontSize: 13),
                                  );
                                }
                                return Text(
                                  snapshot.data ?? "Unknown location",
                                  style: const TextStyle(fontSize: 13),
                                );
                              },
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const SizedBox(width: 4),
                          Text(
                            distance != null ? "$distance km away" : "Distance unknown",
                            style: const TextStyle(fontSize: 13),
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // Buttons row
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => _respondToRequest(req['job_id'], 'rejected'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.red,
                                side: BorderSide(color: Colors.red.shade300),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: const Text(
                                "Reject",
                                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () => _respondToRequest(req['job_id'], 'accepted'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.black87,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                elevation: 0,
                              ),
                              child: const Text(
                                "Accept",
                                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                              ),
                            ),
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
