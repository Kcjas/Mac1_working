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
    final url = Uri.parse("http://192.168.1.2:8000/workers/skill/$skill?customer_lat=${widget.customerLat}&customer_lon=${widget.customerLon}");
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
      appBar: AppBar(title: Text("${widget.skill[0].toUpperCase()}${widget.skill.substring(1)} Workers")),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _workers,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text("No workers available for this service."));
          }

          final workers = snapshot.data!;
          return ListView.builder(
            itemCount: workers.length,
            itemBuilder: (context, index) {
              final worker = workers[index];
              return Card(
                margin: const EdgeInsets.all(12),
                child: ListTile(
                  title: Text(worker['name']),
                  subtitle: Text("Rate: ₹${worker['hourly_rate']} | ⭐ ${worker['rating']}| 📍 ${worker['distance']} km away"),
                  trailing: ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context)=> JobRequestPage(
                          customerId: widget.customerId, 
                          workerId: worker['worker_id'],
                          workerName: worker['name'],
                          workerSkill: widget.skill,
                          hourlyRate: worker['hourly_rate'],
                          distance: worker['distance'],
                          customerLat: widget.customerLat,             
                          customerLon: widget.customerLon,              
                          customerAddress: widget.customerAddress
                        ))
                      );
                    },
                    child: const Text("Request Now"),
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
