import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class RateWorkerPage extends StatefulWidget {
  final int customerId;
  final int workerId;

  const RateWorkerPage({
    super.key,
    required this.customerId,
    required this.workerId,
  });

  @override
  State<RateWorkerPage> createState() => _RateWorkerPageState();
}

class _RateWorkerPageState extends State<RateWorkerPage> {
  int _rating = 0;
  final TextEditingController _reviewController = TextEditingController();
  bool _isSubmitting = false;

  Future<void> submitRating() async {
    if (_rating == 0) return;

    setState(() => _isSubmitting = true);

    final response = await http.post(
      Uri.parse("http://192.168.1.12:8000/rate"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "customer_id": widget.customerId,
        "worker_id": widget.workerId,
        "rating": _rating,
        "review": _reviewController.text.trim(),
      }),
    );

    setState(() => _isSubmitting = false);

    if (response.statusCode == 200) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Rating submitted successfully")),
      );
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to submit rating: ${response.body}")),
      );
    }
  }

  Widget buildStar(int index) {
    return IconButton(
      icon: Icon(
        Icons.star,
        color: index < _rating ? Colors.orange : Colors.grey,
      ),
      onPressed: () => setState(() => _rating = index + 1),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Rate Worker")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Rate your experience", style: TextStyle(fontSize: 18)),
            Row(children: List.generate(5, (index) => buildStar(index))),
            const SizedBox(height: 20),
            const Text("Leave a review (optional)"),
            const SizedBox(height: 8),
            TextField(
              controller: _reviewController,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: "Write your review here...",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _isSubmitting ? null : submitRating,
              child: _isSubmitting
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text("Submit Rating"),
            )
          ],
        ),
      ),
    );
  }
}
