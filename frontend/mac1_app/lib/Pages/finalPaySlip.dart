import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class Finalpayslip extends StatefulWidget{
  final int booking_id;

  const Finalpayslip({
    super.key,
    required this.booking_id
  });

  @override
  State<Finalpayslip> createState() => _finalPaySlipState();
}

class _finalPaySlipState extends State<Finalpayslip>{
  Map<String, dynamic>? payslip;

  @override
  void initState(){
    super.initState();
    fetchPayslip();
  }

  Future<void> fetchPayslip() async{
    final url = Uri.parse("http://192.168.1.2:8000/booking/${widget.booking_id}/summary");

    final response = await http.get(url);
    if(response.statusCode == 200){
      setState(() {
        payslip = json.decode(response.body);
      });
    }else{
      print("Failed to fetch payslip");
    }
  }

  @override
  Widget build(BuildContext context){
    if(payslip == null){
      return const Scaffold(
        body: Center(child: CircularProgressIndicator())
      );
    }
    
    if(payslip?['time_taken'] == 0){
      return const Scaffold(
        body: Center(child: Text("Waiting for Details"))
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text("Mac 1")),
      body: Padding(
        padding:  const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Final invoice:", style: const TextStyle(fontSize: 30, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20,),
            Text("Job: ${payslip!['job_title']}", style: const TextStyle(fontSize: 20,fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Text("Worker: ${payslip!['worker_name']}"),
            const Divider(height:30),
            Text("Duration: ${payslip!['time_taken']} hrs"),
            const SizedBox(height: 10),
            Text("Service Cost: \$${payslip!['service_cost']}"),
            Text("Commission (10%): \$${payslip!['commission']}"),
            const SizedBox(height: 10),
            Text("Extra Charges: \$${payslip!['extra_cost']}"),
            if (payslip!['extra_reason'] != null && payslip!['extra_reason'].toString().isNotEmpty)
              Text("Reason: ${payslip!['extra_reason']}"),
            const Divider(height: 30),
            Text("Total Amount: \$${payslip!['total_cost']}", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 100),
  
          ],
        )
      )
    );
  }
}