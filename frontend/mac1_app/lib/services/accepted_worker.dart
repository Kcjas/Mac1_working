import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'auth_http.dart';
import 'dart:convert';
import '../config/api_config.dart';

class AcceptedWorkerPage extends StatefulWidget {
  final int customerId;
  final double customerLat;
  final double customerLon;
  const AcceptedWorkerPage({
    super.key,
    required this.customerId,
    required this.customerLat,
    required this.customerLon,
  });

  @override
  State<AcceptedWorkerPage> createState() => _AcceptedWorkerPageState();
}

class _AcceptedWorkerPageState extends State<AcceptedWorkerPage> {
  List<dynamic> workers = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadWorkers();
  }

  Future<void> _loadWorkers() async {
    try {
      final baseUrl = await ApiConfig.getBaseUrl();
      final res = await AuthHttp.get(
        Uri.parse('$baseUrl/customer/${widget.customerId}/accepted-workers'),
      );
      if (mounted) {
        setState(() {
          workers = res.statusCode == 200
              ? List<Map<String, dynamic>>.from(jsonDecode(res.body))
              : [];
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('Fetch error: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (workers.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 32),
          child: Column(
            children: [
              Icon(
                Icons.people_outline,
                size: 48,
                color: Colors.grey.shade400,
              ),
              const SizedBox(height: 12),
              Text(
                'No accepted workers yet',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        SizedBox(
          height: 240,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: workers.length,
            itemBuilder: (_, idx) {
              final w = workers[idx];
              return Container(
                width: 300,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                child: Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
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
                                gradient: LinearGradient(
                                  colors: [Colors.purple.shade400, Colors.purple.shade600],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.person,
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
                                    w['name'],
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.black87,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    w['skill'],
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            _buildInfoChip(
                              Icons.star,
                              '${w['rating']}',
                              Colors.amber.shade700,
                            ),
                            const SizedBox(width: 8),
                            _buildInfoChip(
                              Icons.attach_money,
                              '${w['hourly_rate']}/hr',
                              Colors.green.shade600,
                            ),
                            const SizedBox(width: 8),
                            _buildInfoChip(
                              Icons.location_on,
                              '${w['distance']} km',
                              Colors.blue.shade600,
                            ),
                          ],
                        ),
                        const Spacer(),
                        Row(
                          children: [
                            const SizedBox(width: 8),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () => Navigator.pushNamed(
                                  context,
                                  '/book',
                                  arguments: {
                                    'customerId': widget.customerId,
                                    'workerId': w['worker_id'],
                                    'workerName': w['name'],
                                    'skill': w['skill'],
                                    'hourlyRate': w['hourly_rate'],
                                    'rating': w['rating'],
                                    // Use the location the job request was made at
                                    // (per-offer), not the customer's current GPS.
                                    'customerLat': w['customer_lat'] ?? widget.customerLat,
                                    'customerLon': w['customer_lon'] ?? widget.customerLon,
                                    'date': w['date'],
                                    'time': w['time'],
                                  },
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.purple.shade600,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  elevation: 0,
                                ),
                                child: const Text('Book'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: () {
            Navigator.pushNamed(
              context,
              '/acceptedWorkers',
              arguments: {
              'userId': widget.customerId,
              'customerLat': widget.customerLat,
              'customerLon': widget.customerLon,
              }
            );
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  "View All Workers",
                  style: TextStyle(
                    color: Colors.purple.shade600,
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  Icons.arrow_forward_ios,
                  size: 14,
                  color: Colors.purple.shade600,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoChip(IconData icon, String label, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
