import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../services/api_service.dart';

class BookingPage extends StatefulWidget {
  final int customerId;
  final int workerId;
  final String workerName;
  final String skill;
  final double hourlyRate;
  final double rating;
  final double customerLat;
  final double customerLon;
  final String date;
  final String time;

  const BookingPage({
    super.key,
    required this.customerId,
    required this.workerId,
    required this.workerName,
    required this.skill,
    required this.hourlyRate,
    required this.rating,
    required this.customerLat,
    required this.customerLon,
    required this.date,
    required this.time,
  });

  @override
  State<BookingPage> createState() => _BookingPageState();
}

class _BookingPageState extends State<BookingPage> {
  final TextEditingController _jobTitleController = TextEditingController();
  String customerAddress = 'Fetching address...';

  @override
  void initState() {
    super.initState();
    fetchAddressFromCoords();
  }

  Future<void> fetchAddressFromCoords() async {
    final url = Uri.parse(
        "https://nominatim.openstreetmap.org/reverse?format=json&lat=${widget.customerLat}&lon=${widget.customerLon}");

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          customerAddress = data['display_name'] ?? 'Unknown address';
        });
      } else {
        setState(() {
          customerAddress = 'Unknown address';
        });
      }
    } catch (e) {
      setState(() {
        customerAddress = 'Error retrieving address';
      });
    }
  }

  void _submitBooking() async {
    final jobTitle = _jobTitleController.text.trim();
    if (jobTitle.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter job title")),
      );
    }

    final response = await ApiService.createBooking(
      customerId: widget.customerId,
      workerId: widget.workerId,
      jobTitle: jobTitle,
      address: customerAddress,
      date: widget.date,
      time: widget.time,
    );

    if (response['success'] == true) {
      Navigator.pushNamedAndRemoveUntil(
        context,
        '/customerHome',
        (route) => false,
        arguments: widget.customerId
        );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed: ${response['error'] ?? 'Unknown error'}")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final commission = widget.hourlyRate * 0.1;
    final total = widget.hourlyRate + commission;

    return Scaffold(
      appBar: AppBar(title: const Text("Confirm Booking")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.workerName,
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                    Text("Skill: ${widget.skill}"),
                    Text("Hourly Rate: ₹${widget.hourlyRate.toStringAsFixed(0)}"),
                    Text("Rating: ${widget.rating} ⭐"),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _jobTitleController,
              decoration: const InputDecoration(
                labelText: "Job Title",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),

            ListTile(
              leading: const Icon(Icons.calendar_today),
              title: const Text("Scheduled Date"),
              subtitle: Text(widget.date),
            ),
            ListTile(
              leading: const Icon(Icons.access_time),
              title: const Text("Scheduled Time"),
              subtitle: Text(widget.time),
            ),

            const Divider(),

            const Text("Estimated Receipt", style: TextStyle(fontWeight: FontWeight.bold)),
            Text("Service Cost: ₹${widget.hourlyRate.toStringAsFixed(0)} /h"),
            Text("Commission (10%): ₹${commission.toStringAsFixed(0)}/h"),
            Text("Total: ₹${total.toStringAsFixed(0)}/h", style: const TextStyle(fontWeight: FontWeight.bold)),

            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: _submitBooking,
              child: const Text("Confirm Booking"),
            ),
          ],
        ),
      ),
    );
  }
}
