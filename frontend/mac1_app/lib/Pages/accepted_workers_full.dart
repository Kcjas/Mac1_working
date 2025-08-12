import 'package:flutter/material.dart';
import '../models/acceptedworker.dart';
import '../services/api_service.dart';
import 'booking.dart';

class AcceptedWorkersFullPage extends StatefulWidget {
  final int userId;
  const AcceptedWorkersFullPage({Key? key, required this.userId}) : super(key: key);

  @override
  State<AcceptedWorkersFullPage> createState() => _AcceptedWorkersFullPageState();
}

class _AcceptedWorkersFullPageState extends State<AcceptedWorkersFullPage> {
  late Future<List<AcceptedWorker>> _futureWorkers;

  @override
  void initState() {
    super.initState();
    _futureWorkers = ApiService().fetchAcceptedWorkers(widget.userId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('All Accepted Workers')),
      body: FutureBuilder<List<AcceptedWorker>>(
        future: _futureWorkers,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          final workers = snapshot.data ?? [];
          if (workers.isEmpty) {
            return const Center(child: Text('No accepted workers yet.'));
          }

          return ListView.builder(
            itemCount: workers.length,
            itemBuilder: (context, i) {
              final w = workers[i];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(w.name,
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text('Skill: ${w.skill}'),
                      Text('Rate: ₹${w.hourlyRate}/hr'),
                      Text('Rating: ${w.rating}'),
                      Text('Distance: ${w.distance} km'),
                      const SizedBox(height: 8),
                      ElevatedButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => BookingPage(
                                customerId: widget.userId,
                                workerId: w.workerId,
                                workerName: w.name,
                                skill: w.skill,
                                hourlyRate: w.hourlyRate.toDouble(),
                                rating: w.rating.toDouble(),
                                customerLat: w.customerLat,
                                customerLon: w.customerLon,
                                date: w.date,
                                time: w.time
                              ),
                            ),
                          );
                        },
                        child: const Text("Book Now"),
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
