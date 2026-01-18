import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'jobrequest.dart';

class ServiceWorkersPage extends StatefulWidget {
  final String skill;
  final double customerLat;
  final double customerLon;
  final int customerId;
  final String customerAddress;

  const ServiceWorkersPage({
    super.key,
    required this.skill,
    required this.customerLat,
    required this.customerLon,
    required this.customerId,
    required this.customerAddress,
  });

  @override
  State<ServiceWorkersPage> createState() => _ServiceWorkersPageState();
}

class _ServiceWorkersPageState extends State<ServiceWorkersPage> {
  late Future<List<Map<String, dynamic>>> _workers;

  @override
  void initState() {
    super.initState();
    _workers = fetchWorkersBySkill(widget.skill);
  }

  Future<List<Map<String, dynamic>>> fetchWorkersBySkill(String skill) async {
    final url = Uri.parse(
        "http://192.168.1.12:8000/workers/skill/$skill?customer_lat=${widget.customerLat}&customer_lon=${widget.customerLon}");
    final response = await http.get(url);

    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      return data.cast<Map<String, dynamic>>();
    } else {
      throw Exception("Failed to load workers");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Text("${widget.skill[0].toUpperCase()}${widget.skill.substring(1)} Workers"),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black87,
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _workers,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.people_outline, size: 64, color: Colors.grey.shade400),
                  const SizedBox(height: 16),
                  Text(
                    "No workers available",
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

          final workers = snapshot.data!;
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: workers.length,
            itemBuilder: (context, index) {
              final worker = workers[index];
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
                                  worker['name'],
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.black87,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  widget.skill,
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
                          Icon(Icons.star, size: 16, color: Colors.amber),
                          const SizedBox(width: 4),
                          Text(
                            "${worker['rating']}",
                            style: const TextStyle(fontSize: 13),
                          ),
                          const SizedBox(width: 16),
                          Icon(Icons.attach_money, size: 16, color: Colors.green.shade600),
                          const SizedBox(width: 4),
                          Text(
                            "${worker['hourly_rate']}/hr",
                            style: const TextStyle(fontSize: 13),
                          ),
                          const SizedBox(width: 16),
                          Icon(Icons.location_on, size: 16, color: Colors.blue.shade600),
                          const SizedBox(width: 4),
                          Text(
                            "${worker['distance']} km",
                            style: const TextStyle(fontSize: 13),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => JobRequestPage(
                                  customerId: widget.customerId,
                                  workerId: worker['worker_id'],
                                  workerName: worker['name'],
                                  workerSkill: widget.skill,
                                  hourlyRate: worker['hourly_rate'],
                                  distance: worker['distance'],
                                  customerLat: widget.customerLat,
                                  customerLon: widget.customerLon,
                                  customerAddress: widget.customerAddress,
                                  problem: "",
                                ),
                              ),
                            );
                          },
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
                            "Request",
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                          ),
                        ),
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