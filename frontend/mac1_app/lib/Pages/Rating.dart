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
    if (_rating == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select a rating")),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
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
          const SnackBar(content: Text("Rating submitted")),
        );
        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Failed to submit rating")),
        );
      }
    } catch (e) {
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Error submitting rating")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(title: const Text("Rate Worker"),backgroundColor: Colors.white,elevation: 0,foregroundColor: Colors.black,),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            const Text("How was your experience?",style: TextStyle(fontSize: 20,fontWeight: FontWeight.w600,color: Colors.black87,),),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (index) {
                final isFilled = index < _rating;
                return GestureDetector(
                  onTap: () => setState(() => _rating = index + 1),
                  child: Padding(padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: Icon(
                      isFilled ? Icons.star : Icons.star_outline,
                      size: 44,
                      color: isFilled ? Colors.amber : Colors.grey.shade400,
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: 32),
            const Text("Leave a review (optional)",style: TextStyle(fontSize: 16,fontWeight: FontWeight.w600,color: Colors.black87,),),
            const SizedBox(height: 12),
            TextField(
              controller: _reviewController,
              maxLines: 4,
              enabled: !_isSubmitting,
              decoration: InputDecoration(
                hintText: "Share your feedback...",
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8),borderSide: BorderSide(color: Colors.grey.shade300),),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8),borderSide: BorderSide(color: Colors.grey.shade300),),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8),borderSide: BorderSide(color: Colors.grey.shade400, width: 1),),
                contentPadding: const EdgeInsets.all(12),
                isDense: true,
              ),
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : submitRating,
                style: ElevatedButton.styleFrom(backgroundColor: Colors.black87,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  elevation: 0,
                ),
                child: _isSubmitting ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(strokeWidth: 2,valueColor: AlwaysStoppedAnimation<Color>(Colors.white),), ) 
                  : const Text("Submit"),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _reviewController.dispose();
    super.dispose();
  }
}