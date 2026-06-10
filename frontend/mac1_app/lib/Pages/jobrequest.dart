import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:geocoding/geocoding.dart';
import '../services/auth_http.dart';
import 'dart:async';
import 'dart:convert';
import '../config/api_config.dart';

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
  final String problem;

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
    required this.problem,
  });

  @override
  State<JobRequestPage> createState() => _JobRequestPageState();
}

class _JobRequestPageState extends State<JobRequestPage> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  final _addressController = TextEditingController();
  DateTime? _selectedDateTime;
  bool _isSubmitting = false;

  late double _lat;
  late double _lon;

  // Address autocomplete (Photon — free, no API key). Each suggestion already
  // carries its own coordinates, so picking one needs no extra geocode call.
  List<Map<String, dynamic>> _addressSuggestions = [];
  Timer? _addrDebounce;
  bool _searchingAddr = false;
  // True when the address in the field corresponds to known coordinates:
  // either the pre-filled current location, or a suggestion the user tapped.
  bool _addressChosen = true;

  @override
  void initState() {
    super.initState();
    if (widget.problem.isNotEmpty) {
      _descriptionController.text = widget.problem;
    }
    _addressController.text = widget.customerAddress;
    _lat = widget.customerLat;
    _lon = widget.customerLon;
  }

  Future<void> _submitRequest() async {
    if (!_formKey.currentState!.validate() || _selectedDateTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please fill in all fields")),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    final typedAddress = _addressController.text.trim();
    // _lat/_lon already match the address when it's the pre-filled location or a
    // tapped suggestion. If the customer typed free text without picking one,
    // fall back to geocoding it so the request still uses the right location.
    if (!_addressChosen) {
      try {
        final locations = await locationFromAddress(typedAddress);
        if (locations.isEmpty) throw Exception('No match');
        _lat = locations.first.latitude;
        _lon = locations.first.longitude;
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Pick a location from the suggestions, or refine your search"),
            ),
          );
          setState(() => _isSubmitting = false);
        }
        return;
      }
    }

    final baseUrl = await ApiConfig.getBaseUrl();
    final url = Uri.parse('$baseUrl/request_job/');
    try {
      final response = await AuthHttp.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: json.encode({
          "customer_id": widget.customerId,
          "worker_id": widget.workerId,
          "description": _descriptionController.text,
          "preferred_datetime": _selectedDateTime!.toIso8601String(),
          "customer_lat": _lat,
          "customer_lon": _lon,
          "customer_address": typedAddress,
        }),
      );

      if (!mounted) return;

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
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e")),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _onAddressChanged(String value) {
    // The text no longer matches known coordinates until a suggestion is picked.
    _addressChosen = false;
    _addrDebounce?.cancel();
    final query = value.trim();
    if (query.length < 3) {
      setState(() => _addressSuggestions = []);
      return;
    }
    _addrDebounce = Timer(const Duration(milliseconds: 350), () {
      _searchAddress(query);
    });
  }

  Future<void> _searchAddress(String query) async {
    setState(() => _searchingAddr = true);
    // Photon autocomplete, biased toward the customer's current location so
    // nearby places rank first. Plain http (no auth header) — never send our
    // JWT to a third-party service.
    final url = Uri.parse(
      'https://photon.komoot.io/api/'
      '?q=${Uri.encodeQueryComponent(query)}'
      '&limit=5&lang=en'
      '&lat=${widget.customerLat}&lon=${widget.customerLon}',
    );
    try {
      final res = await http.get(url);
      if (!mounted) return;
      if (res.statusCode != 200) {
        setState(() {
          _searchingAddr = false;
          _addressSuggestions = [];
        });
        return;
      }
      final features = (jsonDecode(res.body)['features'] as List?) ?? [];
      final suggestions = <Map<String, dynamic>>[];
      for (final f in features) {
        final coords = (f['geometry']?['coordinates'] as List?); // [lon, lat]
        final props = (f['properties'] as Map?)?.cast<String, dynamic>() ?? {};
        if (coords == null || coords.length < 2) continue;
        suggestions.add({
          'label': _formatPhotonLabel(props),
          'lon': (coords[0] as num).toDouble(),
          'lat': (coords[1] as num).toDouble(),
        });
      }
      setState(() {
        _searchingAddr = false;
        _addressSuggestions = suggestions;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _searchingAddr = false;
          _addressSuggestions = [];
        });
      }
    }
  }

  String _formatPhotonLabel(Map<String, dynamic> p) {
    String? s(String k) {
      final v = p[k];
      return (v == null || v.toString().trim().isEmpty) ? null : v.toString();
    }

    final primary = s('name') ??
        [s('street'), s('housenumber')].where((e) => e != null).join(' ');
    final locality = s('city') ?? s('town') ?? s('village') ?? s('county');
    final parts = <String>[
      if (primary.isNotEmpty) primary,
      if (locality != null) locality,
      if (s('state') != null) s('state')!,
      if (s('postcode') != null) s('postcode')!,
      if (s('country') != null) s('country')!,
    ];
    final seen = <String>{};
    return parts.where(seen.add).join(', ');
  }

  void _pickSuggestion(Map<String, dynamic> suggestion) {
    _addrDebounce?.cancel();
    setState(() {
      _addressController.text = suggestion['label'] as String;
      _lat = suggestion['lat'] as double;
      _lon = suggestion['lon'] as double;
      _addressChosen = true;
      _addressSuggestions = [];
    });
    FocusScope.of(context).unfocus();
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
      initialTime: const TimeOfDay(hour: 10, minute: 0),
    );

    if (time == null) return;

    setState(() {
      _selectedDateTime = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  @override
  void dispose() {
    _addrDebounce?.cancel();
    _descriptionController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("Job Request"),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black87,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 8),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.person, color: Colors.blue.shade600, size: 28),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.workerName,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "${widget.workerSkill} • \$${widget.hourlyRate}/hr • ${widget.distance} km",
                          style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              TextFormField(
                controller: _descriptionController,
                enabled: !_isSubmitting,
                maxLines: 4,
                decoration: InputDecoration(
                  labelText: "Job Description",
                  hintText: "Describe the work you need done...",
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
                validator: (value) =>
                    value == null || value.isEmpty ? "Please enter a description" : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _addressController,
                enabled: !_isSubmitting,
                maxLines: 2,
                minLines: 1,
                onChanged: _onAddressChanged,
                decoration: InputDecoration(
                  labelText: "Service Location",
                  hintText: "Start typing an address…",
                  helperText: "Pick a suggestion so we get the exact spot",
                  prefixIcon: Icon(Icons.location_on, color: Colors.grey.shade600),
                  suffixIcon: _searchingAddr
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : (_addressChosen
                          ? Icon(Icons.check_circle, color: Colors.green.shade600)
                          : null),
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
                validator: (value) =>
                    value == null || value.trim().isEmpty ? "Please enter a location" : null,
              ),
              if (_addressSuggestions.isNotEmpty)
                Container(
                  margin: const EdgeInsets.only(top: 4),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    children: [
                      for (var i = 0; i < _addressSuggestions.length; i++) ...[
                        if (i > 0) Divider(height: 1, color: Colors.grey.shade200),
                        InkWell(
                          onTap: () => _pickSuggestion(_addressSuggestions[i]),
                          borderRadius: BorderRadius.circular(10),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            child: Row(
                              children: [
                                Icon(Icons.place_outlined, size: 20, color: Colors.grey.shade500),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    _addressSuggestions[i]['label'] as String,
                                    style: const TextStyle(fontSize: 13),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              const SizedBox(height: 16),
              GestureDetector(
                onTap: _isSubmitting ? null : _pickDateTime,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.calendar_today, color: Colors.grey.shade600, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _selectedDateTime != null
                              ? DateFormat('MMM dd, yyyy – hh:mm a').format(_selectedDateTime!)
                              : "Select date & time",
                          style: TextStyle(
                            fontSize: 14,
                            color: _selectedDateTime != null
                                ? Colors.black87
                                : Colors.grey.shade600,
                          ),
                        ),
                      ),
                      Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey.shade400),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 28),
              ElevatedButton(
                onPressed: _isSubmitting ? null : _submitRequest,
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
                    : const Text(
                        "Send Request",
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
