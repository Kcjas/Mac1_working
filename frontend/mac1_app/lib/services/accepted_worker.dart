import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class AcceptedWorkerPage extends StatefulWidget {
  final int customerId;
  final double customerLat;
  final double customerLon;
  const AcceptedWorkerPage({Key? key, required this.customerId,required this.customerLat,required this.customerLon}) : super(key: key);

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
      final res = await http.get(
        Uri.parse('http://10.130.27.237/customer/${widget.customerId}/accepted-workers'),
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
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (workers.isEmpty) return const Center(child: Text('No accepted workers yet.'));

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Accepted Workers',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              TextButton(
                onPressed: () => Navigator.pushNamed(
                  context,
                  '/acceptedWorkerList',      
                  arguments: widget.customerId,
                ),
                child: const Text('View All'),
              )
            ],
          ),
        ),
      
        SizedBox(
          height: 260,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: workers.length,
            itemBuilder: (_, idx) {
              final w = workers[idx];
              return Container(
                width: 285,
                margin: const EdgeInsets.symmetric(horizontal: 8),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(w['name'],
                            style: const TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text('${w['skill']}  •  ⭐ ${w['rating']}'),
                        Text('₹${w['hourly_rate']}/hr'),
                        Text('${w['distance']} km away'),
                        const Spacer(),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            OutlinedButton(
                              onPressed: () => Navigator.pushNamed(
                                context,
                                '/acceptedWorkerList',
                                arguments: widget.customerId,
                              ),
                              child: const Text('View More'),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton(
                              onPressed: () => Navigator.pushNamed(
                                context,
                                '/book',
                                arguments: {
                                  'customerId': widget.customerId,
                                  'workerId':   w['worker_id'],
                                  'workerName': w['name'],
                                  'skill':      w['skill'],
                                  'hourlyRate': w['hourly_rate'],
                                  'rating':     w['rating'],
                                  'customerLat': widget.customerLat,
                                  'customerLon': widget.customerLon,
                                  'date': w['date'],
                                  'time':w['time'],
                                },
                              ),
                              child: const Text('Schedule'),
                            ),
                          ],
                        )
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
