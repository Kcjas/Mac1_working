import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class CompletedJobPage extends StatefulWidget{
  final int booking_id;
  final int userId;
  const CompletedJobPage({super.key,required this.booking_id,required this.userId});

  @override
  State<CompletedJobPage> createState() => _CompletedJobPageState();
}

class _CompletedJobPageState extends State<CompletedJobPage> {
  final _formKey = GlobalKey<FormState>();
  final _durationController = TextEditingController();
  final _costController = TextEditingController();
  final _reasonController = TextEditingController();



  Future <void> _submit() async{
    if(_formKey.currentState!.validate()){
      final url = Uri.parse("http://10.121.172.237:8000/booking/complete");

      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "booking_id": widget.booking_id,
          "duration_hours": double.parse(_durationController.text),
          "additional_cost": double.parse(_costController.text),
          "reason": _reasonController.text,
        })
      );

     if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Job marked as completed!")),
        );
        Navigator.pop(context); 
      } else {
        final resData = jsonDecode(response.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: ${resData["detail"]}")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context){
    return Scaffold(
      appBar: AppBar(title: const Text("Complete Job")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _durationController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: "Duration (hours)"),
                validator: (value){
                  if(value == null|| value.isEmpty) return "Enter Duration";
                  final duration = double.tryParse(value);
                  if(duration == null || duration <=0) return "Enter Valid Number";
                  return null;
                }
              ),
              TextFormField(
                controller: _costController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: "Total Additional Cost (₹)"),
                validator: (value) {
                  if (value == null || value.isEmpty) return "Enter cost";
                  final number = double.tryParse(value);
                  if (number == null || number < 0) return "Enter valid number";
                  return null;
                },
              ),
              TextFormField(
                controller: _reasonController,
                decoration: const InputDecoration(labelText: "Reason for cost(If multiple give cost for each reason)"),
                validator: (value) {
                  if (value == null || value.isEmpty) return "Enter reason";
                  return null;
                },
              ),
              const SizedBox(height: 20,),
              ElevatedButton(
                onPressed: _submit, 
                child: const Text("Submit")
              )
            ],
          )
        )
      )
    );
  }
}