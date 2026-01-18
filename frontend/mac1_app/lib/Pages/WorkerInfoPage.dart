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
  final _formKey = GlobalKey<FormState>();
  final _skillController = TextEditingController();
  final _experienceController = TextEditingController();
  final _hourlyrateController = TextEditingController();
  bool _isSubmitting = false;

  final List<String> allowedSkills = ['plumber', 'hvac', 'electrician', 'cleaning'];

  Future<void> _submitWorkerInfo() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    final skill = _skillController.text.toLowerCase().trim();
    final experience = int.tryParse(_experienceController.text) ?? 0;
    final hourlyRate = double.tryParse(_hourlyrateController.text) ?? 0.0;

    try {
      final pos = await LocationService.getCurrentLocation();

      final res = await http.post(
        Uri.parse('http://192.168.1.12:8000/worker_info'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'user_id': widget.userId,
          'skill': skill,
          'experience': experience,
          'hourly_rate': hourlyRate,
          'latitude': pos.latitude,
          'longitude': pos.longitude,
        }),
      );

      if (!mounted) return;

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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Connection error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  void dispose() {
    _skillController.dispose();
    _experienceController.dispose();
    _hourlyrateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Worker Info'),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 20),
                TextFormField(
                  controller: _skillController,
                  enabled: !_isSubmitting,
                  decoration: InputDecoration(
                    labelText: 'Skill',
                    hintText: 'plumber, electrician, cleaning, hvac',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: Colors.grey.shade400),
                    ),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Please enter your skill';
                    if (!allowedSkills.contains(v.toLowerCase().trim())) {
                      return 'Skill must be plumber, electrician, cleaning or hvac';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _experienceController,
                  enabled: !_isSubmitting,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Experience (years)',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: Colors.grey.shade400),
                    ),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Enter experience';
                    final exp = int.tryParse(v);
                    if (exp == null || exp < 0) return 'Enter a valid number';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _hourlyrateController,
                  enabled: !_isSubmitting,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: 'Hourly Rate',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: Colors.grey.shade400),
                    ),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Enter hourly rate';
                    final rate = double.tryParse(v);
                    if (rate == null) return 'Enter a valid rate';
                    return null;
                  },
                ),
                const SizedBox(height: 28),
                ElevatedButton(
                  onPressed: _isSubmitting ? null : _submitWorkerInfo,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black87,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    elevation: 0,
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text('Submit', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}