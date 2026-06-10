import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../services/auth_http.dart';
import 'dart:convert';
import '../config/api_config.dart';

class Finalpayslip extends StatefulWidget {
  final int booking_id;

  const Finalpayslip({
    super.key,
    required this.booking_id,
  });

  @override
  State<Finalpayslip> createState() => _finalPaySlipState();
}

class _finalPaySlipState extends State<Finalpayslip> {
  Map<String, dynamic>? payslip;

  @override
  void initState() {
    super.initState();
    fetchPayslip();
  }

  Future<void> fetchPayslip() async {
    final baseUrl = await ApiConfig.getBaseUrl();
    final url = Uri.parse("$baseUrl/booking/${widget.booking_id}/summary");

    final response = await AuthHttp.get(url);
    if (response.statusCode == 200) {
      setState(() {
        payslip = json.decode(response.body);
      });
    } else {
      print("Failed to fetch payslip");
    }
  }

  @override
  Widget build(BuildContext context) {
    if (payslip == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()),);
    }

    if (payslip?['time_taken'] == 0) {
      return Scaffold(
        appBar: AppBar(
          title: const Text("Invoice"),
          elevation: 0,
        ),
        body: const Center(child: Text("Waiting for Details",style: TextStyle(fontSize: 16),),),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("Invoice"),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),
              Text(
                payslip!['job_title'] ?? 'N/A',
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                payslip!['worker_name'] ?? 'N/A',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 40),
              _buildRow("Duration", "${payslip!['time_taken']} hours"),
              _buildRow("Service Cost", "\$${payslip!['service_cost']}"),
              _buildRow("Commission (10%)", "\$${payslip!['commission']}"),
              _buildRow("Extra Charges", "\$${payslip!['extra_cost']}"),
              
              if (payslip!['extra_reason'] != null &&
                  payslip!['extra_reason'].toString().isNotEmpty) ...[
                const SizedBox(height: 4),
                Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Text(
                    payslip!['extra_reason'],
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ],
              
              const SizedBox(height: 32),
              Container(
                height: 1,
                color: Colors.grey.shade300,
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  const Text(
                    "Total",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  Text(
                    "\$${payslip!['total_cost']}",
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                      letterSpacing: -1,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey.shade700,
            ),
          ),
          Text(value,style: const TextStyle(fontSize: 16,fontWeight: FontWeight.w500,color: Colors.black87,)),
        ],
      ),
    );
  }
}
