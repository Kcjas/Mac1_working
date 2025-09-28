import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../services/address.dart';

class JobRequestPage extends StatefulWidget {
  final int customerId;
  final int workerId;
  final String workerName;
  final String workerSkill;
  final double hourlyRate;
  final double distance;
  final double customerLat;         
  final double customerLon;      
  final String customerAddress;

  const JobRequestPage({
    super.key,
    required this.customerId,
    required this.workerId,
    required this.workerName,
    required this.workerSkill,
    required this.hourlyRate,
    required this.distance, 
     required this.customerLat,
    required this.customerLon,
    required this.customerAddress,
  });

  @override
  State<JobRequestPage> createState() => _JobRequestPageState();
}

class _JobRequestPageState extends State<JobRequestPage> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  DateTime? _selectedDateTime;

  Future<void> _submitRequest() async {
    if (!_formKey.currentState!.validate() || _selectedDateTime == null) return;

    final url = Uri.parse('http://192.168.1.12:8000/request_job/');
    final response = await http.post(
      url,
      headers: {"Content-Type": "application/json"},
      body: json.encode({
        "customer_id": widget.customerId,
        "worker_id": widget.workerId,
        "description": _descriptionController.text,
        "preferred_datetime": _selectedDateTime!.toIso8601String(),
        "customer_lat": widget.customerLat,              
        "customer_lon": widget.customerLon,              
      }),
    );

    if (response.statusCode == 200) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Job request sent successfully!")),
      );
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed: ${response.body}")),
      );
    }
  }

  Future<void> _pickDateTime() async {
    final date = await showDatePicker(
      context: context,
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
      initialDate: DateTime.now(),
    );

    if (date == null) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: 10, minute: 0),
    );

    if (time == null) return;

    setState(() {
      _selectedDateTime = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Job Request")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Card(
          elevation: 6,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.person, size: 36),
                  title: Text(widget.workerName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  subtitle: Text("${widget.workerSkill} | ₹${widget.hourlyRate}/hr | 📍 ${widget.distance} km"),
                ),
                const Divider(),
                Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      TextFormField(
                        controller: _descriptionController,
                        decoration: const InputDecoration(
                          labelText: "Describe the job",
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.description),
                        ),
                        maxLines: 3,
                        validator: (value) =>
                            value == null || value.isEmpty ? "Please enter a job description" : null,
                      ),
                      const SizedBox(height: 20),
                      ListTile(
                        leading: const Icon(Icons.calendar_today),
                        title: Text(
                          _selectedDateTime != null
                              ? DateFormat('yyyy-MM-dd – HH:mm').format(_selectedDateTime!)
                              : "Select preferred date & time",
                          style: const TextStyle(fontSize: 16),
                        ),
                        trailing: ElevatedButton(
                          onPressed: _pickDateTime,
                          child: const Text("Pick"),
                        ),
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _submitRequest,
                          icon: const Icon(Icons.send),
                          label: const Text("Send Request"),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            textStyle: const TextStyle(fontSize: 16),
                          ),
                        ),
                      )
                    ],
                  ),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }
}
