import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../services/auth_http.dart';
import 'dart:convert';
import '../config/api_config.dart';

class RateWorkerPage extends StatefulWidget {
  final int customerId;
  final int workerId;
  final int bookingId;

  const RateWorkerPage({
    super.key,
    required this.customerId,
    required this.workerId,
    required this.bookingId,
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
      final baseUrl = await ApiConfig.getBaseUrl();
      final response = await AuthHttp.post(
        Uri.parse("$baseUrl/rate"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "customer_id": widget.customerId,
          "worker_id": widget.workerId,
          "booking_id": widget.bookingId,
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
      appBar: AppBar(
        title: const Text(
          "Rate Worker",
          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 24),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black,
      ),
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
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(20),borderSide: BorderSide(color: Colors.grey.shade300),),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(20),borderSide: BorderSide(color: Colors.grey.shade300),),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(20),borderSide: const BorderSide(color: Color(0xFFFF4D00), width: 2),),
                contentPadding: const EdgeInsets.all(16),
                isDense: true,
              ),
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : submitRating,
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF4D00),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                  elevation: 0,
                ),
                child: _isSubmitting ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2,valueColor: AlwaysStoppedAnimation<Color>(Colors.white),), ) 
                  : const Text("Submit", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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
