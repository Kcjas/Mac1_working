import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class BookingPreview extends StatefulWidget{
  final int userId;
  final String type;

  const BookingPreview({
    super.key,
    required this.userId,
    required this.type,
  });

  @override
  State<BookingPreview> createState() => _bookingPreviewState();
}

class _bookingPreviewState extends State<BookingPreview>{
  late Future<List<Map<String, dynamic>>> _previewJobs;

  @override
  void initState(){
    super.initState();
    _previewJobs = fetchPreviewJobs();
  }

  Future<List<Map<String, dynamic>>> fetchPreviewJobs() async {
    final url = Uri.parse("http://192.168.1.2:8000/worker/${widget.userId}/${widget.type}-jobs");

    final response = await http.get(url);
    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      return data.cast<Map<String, dynamic>>();
    } else {
      throw Exception("Failed to load jobs");
    }
  }

  @override
  Widget build(BuildContext context){
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _previewJobs,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(padding: EdgeInsets.all(16),child: CircularProgressIndicator(),);
        } else if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
          return const Padding(padding: EdgeInsets.all(16),child: Text('No jobs found'),);
        }

        final jobs = snapshot.data!;
        final previewJobs = jobs.take(3).toList();

        return Card(
          margin: const EdgeInsets.all(16),
          elevation: 4,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                Text(
                  widget.type == "pending"?"Pending Jobs":"Completed Jobs",
                  style: const TextStyle(fontSize: 18,fontWeight: FontWeight.bold)
                ),
                const SizedBox(height: 10,),
                ...previewJobs.map((job) => ListTile(
                  title: Text(job['job_title']?.toString() ?? 'No title'),
                  subtitle: Text("Customer: ${job['customer_name'] ?? 'Unknown'}\n"
                  "Address: ${job['address'] ?? 'Unknown'}\n"
                  "Date: ${job['date'] ?? 'N/A'}  Time: ${job['time'] ?? 'N/A'}",
                  ),
                  dense: true
                )),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: (){
                      Navigator.pushNamed(context, widget.type == "pending"?'/pendingJobs' : '/completedJobs', arguments: widget.userId);
                    }, 
                    child: const Text("View All")
                  )
                )
              ],
            )
          )
        );
      }
    );
  }
}