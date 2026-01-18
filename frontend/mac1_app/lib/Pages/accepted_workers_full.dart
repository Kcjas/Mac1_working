import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class AcceptedWorkersFull extends StatefulWidget {
  final int userId;
  final double customerLat;
  final double customerLon;

  const AcceptedWorkersFull({
    super.key,
    required this.userId,
    required this.customerLat,
    required this.customerLon,
  });

  @override
  State<AcceptedWorkersFull> createState() => _AcceptedWorkersFullState();
}

class _AcceptedWorkersFullState extends State<AcceptedWorkersFull> {
  late Future<List<dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _future = _fetchAccepted();
  }

  Future<List<dynamic>> _fetchAccepted() async {
    final url = Uri.parse(
      'http://192.168.1.12:8000/customer/${widget.userId}/accepted-workers',
    );

    final res = await http.get(url);

    if (res.statusCode == 200) {
      final decoded = jsonDecode(res.body);
      return decoded is List ? decoded : <dynamic>[];
    }
    throw Exception('Failed: ${res.statusCode} ${res.body}');
  }

  Future<void> _refresh() async {
    setState(() => _future = _fetchAccepted());
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text("Accepted Workers"),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black87,
      ),
      body: FutureBuilder<List<dynamic>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      "Couldn’t load accepted workers.",
                      style: TextStyle(
                        color: Colors.grey.shade800,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      snapshot.error.toString(),
                      style: TextStyle(color: Colors.grey.shade600),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: _refresh,
                      child: const Text("Retry"),
                    ),
                  ],
                ),
              ),
            );
          }

          final items = (snapshot.data ?? []).cast<dynamic>();

          if (items.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.people_outline, size: 52, color: Colors.grey.shade400),
                    const SizedBox(height: 12),
                    Text(
                      "No accepted workers yet",
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
                    ),
                  ],
                ),
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, i) {
                final w = items[i] as Map<String, dynamic>;

                final name = (w['name'] ?? 'Unknown').toString();
                final skill = (w['skill'] ?? '-').toString();
                final rating = (w['rating'] ?? '-').toString();
                final hourly = (w['hourly_rate'] ?? '-').toString();
                final distance = (w['distance'] ?? '-').toString();
                final date = (w['date'] ?? '').toString();
                final time = (w['time'] ?? '').toString();

                return Card(
                  elevation: 0.5,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Top row
                        Row(
                          children: [
                            const CircleAvatar(
                              radius: 18,
                              backgroundColor: Color(0xFFEDE7F6), // light purple tint
                              child: Icon(Icons.person, color: Color(0xFF5E35B1)),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    name,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    skill,
                                    style: TextStyle(color: Colors.grey.shade600),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              "\$$hourly/hr",
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 12),

                        // Info row (minimal chips)
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _miniChip(Icons.star, rating),
                            _miniChip(Icons.location_on, "$distance km"),
                            if (date.isNotEmpty || time.isNotEmpty) _miniChip(Icons.schedule, "$date $time".trim()),
                          ],
                        ),

                        const SizedBox(height: 12),

                        // Action row
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () => Navigator.pushNamed(
                              context,
                              '/book',
                              arguments: {
                                'customerId': widget.userId,
                                'workerId': w['worker_id'],
                                'workerName': name,
                                'skill': skill,
                                'hourlyRate': w['hourly_rate'],
                                'rating': w['rating'],
                                'customerLat': widget.customerLat,
                                'customerLon': widget.customerLon,
                                'date': w['date'],
                                'time': w['time'],
                              },
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.purple.shade600,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            child: const Text("Book"),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }

  Widget _miniChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.grey.shade700),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade800,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
