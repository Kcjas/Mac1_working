import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:geolocator/geolocator.dart';
import '../services/location_service.dart';

class WorkerInfoPage extends StatefulWidget {
  final int userId;                           
  const WorkerInfoPage({Key? key, required this.userId}) : super(key: key);

  @override
  State<WorkerInfoPage> createState() => _WorkerInfoPageState();
}

class _WorkerInfoPageState extends State<WorkerInfoPage> {
  final _formKey             = GlobalKey<FormState>();
  final _skillController      = TextEditingController();
  final _experienceController = TextEditingController();
  final _hourlyrateController = TextEditingController();

  final List<String> allowedSkills = ['plumber', 'hvac', 'electrician', 'cleaning'];

  Future<void> _submitWorkerInfo() async {
    if (!_formKey.currentState!.validate()) return;

    final skill       = _skillController.text.toLowerCase().trim();
    final experience  = int.tryParse(_experienceController.text) ?? 0;
    final hourlyRate  = double.tryParse(_hourlyrateController.text)??0.0;          

    try {
      final pos = await LocationService.getCurrentLocation();

      final res = await http.post(
        Uri.parse('http://192.168.1.2:8000/worker_info'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'user_id'    : widget.userId,        
          'skill'      : skill,
          'experience' : experience,
          'hourly_rate': hourlyRate,
          'latitude'   : pos.latitude,
          'longitude'  : pos.longitude,
        }),
      );

      if (res.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Worker info saved!')),
        );
        Navigator.pushReplacementNamed(context, '/');
      } else {
        final err = jsonDecode(res.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${err['detail']}')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Connection error: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Complete Worker Info')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                TextFormField(
                  controller: _skillController,
                  decoration: const InputDecoration(
                    labelText: 'Skill (plumber, electrician, cleaning, hvac)',
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Please enter your skill';
                    if (!allowedSkills.contains(v.toLowerCase().trim())) {
                      return 'Skill must be plumber, electrician, cleaning or hvac';
                    }
                    return null;
                  },
                ),
                TextFormField(
                  controller: _experienceController,
                  decoration: const InputDecoration(labelText: 'Experience (years)'),
                  keyboardType: TextInputType.number,
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Enter experience';
                    final exp = int.tryParse(v);
                    if (exp == null || exp < 0) return 'Enter a valid number';
                    return null;
                  },
                ),
                TextFormField(
                  controller: _hourlyrateController,
                  decoration: const InputDecoration(labelText: "Hourly Rate"),
                  validator: (v){
                    if(v == null || v.isEmpty) return 'Enter Hourly rate';
                    final rate = double.tryParse(v);
                    if(v == null)return "Enter valid rate";
                    return null;
                  },
                ),
                const SizedBox(height: 30),
                ElevatedButton(onPressed: _submitWorkerInfo, child: const Text('Submit')),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
