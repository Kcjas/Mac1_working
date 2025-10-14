import 'dart:convert';
import 'package:flutter/material.dart';
import '../models/acceptedworker.dart';
import '../services/api_service.dart';
import 'booking.dart';
import 'package:http/http.dart' as http;

class AcceptedWorkersFull extends StatefulWidget {
  final int userId;
  const AcceptedWorkersFull({super.key, required this.userId});

  @override
  State<AcceptedWorkersFull> createState() => _AcceptedWorkersFullState();
}

class _AcceptedWorkersFullState extends State<AcceptedWorkersFull> {
  late Future<List<dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _future = fetchAccepted(widget.userId);
  }

  Future<List<dynamic>> fetchAccepted(int userId) async {
    final url = Uri.parse('http://192.168.1.12:8000/customer/$userId/accepted-workers');
    print('Hitting: $url');
    final res = await http.get(url);
    print('Status: ${res.statusCode}');
    print('Body: ${res.body}');
    if (res.statusCode == 200) {
      return json.decode(res.body) as List<dynamic>;
    } else {
      throw Exception('Failed: ${res.statusCode} ${res.body}');
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<dynamic>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));
        final items = snapshot.data!;
        if (items.isEmpty) return const Center(child: Text('No accepted offers yet.'));
        return ListView.builder(
          itemCount: items.length,
          itemBuilder: (_, i) {
            final w = items[i] as Map<String, dynamic>;
            return ListTile(
              title: Text('${w["name"]} • ${w["skill"]}'),
              subtitle: Text('⭐ ${w["rating"]}  ${w["distance"] ?? "-"} km  ${w["date"]} ${w["time"]}'),
              trailing: Text('\$${w["hourly_rate"]}/hr'),
            );
          },
        );
      },
    );
  }
}
