import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../models/CustomerProfile.dart';
import '../services/api_service.dart';
import '../services/location_service.dart';
import '../services/address.dart';
import '../services/profilerow.dart';
import '../services/customer_booking_preview.dart';
import '../services/accepted_worker.dart';
import '../services/customercompletedbookingpreview.dart';

class Customerhp extends StatefulWidget {
  final int userId;
  const Customerhp({super.key, required this.userId});

  @override
  State<Customerhp> createState() => _CustomerhpState();
}

class _CustomerhpState extends State<Customerhp> {
  late Future<Customerprofile> customerFuture;
  Position? _currentPosition;
  String? _address;

  @override
  void initState() {
    super.initState();
    customerFuture = ApiService.fetchCustomerProfile(widget.userId);
    WidgetsBinding.instance.addPostFrameCallback((_) => _fetchLocation());
  }

  void _fetchLocation() async {
    try {
      final pos = await LocationService.getCurrentLocation();
      final resolvedAddress = await LocationHelper.getAddressFromLatLng(pos.latitude, pos.longitude);

      if (mounted) {
        setState(() {
          _currentPosition = pos;
          _address = resolvedAddress;
        });
      }
    } catch (e) {
      print("Location error: $e");
    }
  }

  Widget _buildServiceButton(String service) {
    return ElevatedButton(
      onPressed: _currentPosition == null
          ? null
          : () {
              Navigator.pushNamed(context, '/service_workers', arguments: {
                'skill': service.toLowerCase(),
                'customerLat': _currentPosition!.latitude ?? "N/A",
                'customerLon': _currentPosition!.longitude?? "N/A",
                'customerId': widget.userId,
                'customerAddress': _address ?? "Unknown",
              });
            },
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
      child: Text(service, style: const TextStyle(fontSize: 16)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("User Dashboard")),
      body: SafeArea(
        child: FutureBuilder<Customerprofile>(
          future: customerFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            } else if (snapshot.hasError) {
              return Center(child: Text('Error: ${snapshot.error}'));
            } else if (!snapshot.hasData) {
              return const Center(child: Text('No data found'));
            }

            final customer = snapshot.data!;

            return LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: constraints.maxHeight),
                    child: IntrinsicHeight(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: const [
                                BoxShadow(
                                    color: Colors.grey,
                                    blurRadius: 6,
                                    offset: Offset(0, 3))
                              ],
                            ),
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const CircleAvatar(
                                  radius: 30,
                                  backgroundColor: Colors.blue,
                                  child: Icon(Icons.person, size: 40, color: Colors.white),
                                ),
                                const SizedBox(width: 20),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text("Name: ${customer.name}",
                                          style: const TextStyle(
                                              fontSize: 22, fontWeight: FontWeight.bold)),
                                      ProfileRow(label: "Age", value: "${customer.age}"),
                                      ProfileRow(label: "Gender", value: customer.gender),
                                      const SizedBox(height: 8),
                                      Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text("Location:",
                                              style: TextStyle(fontWeight: FontWeight.bold)),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              _address ?? "Fetching...",
                                              maxLines: 3,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                      TextButton(
                                        onPressed: _fetchLocation,
                                        child: const Text("Refresh Location"),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                          ElevatedButton.icon(
                            onPressed: () => Navigator.pushNamed(context, '/chatbot',arguments: widget.userId),
                            icon: const Icon(Icons.question_answer),
                            label: const Text("Need help identifying the problem?"),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.deepPurple,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                          const SizedBox(height: 20),
                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: [
                              _buildServiceButton("Plumbing"),
                              _buildServiceButton("Cleaning"),
                              _buildServiceButton("HVAC"),
                              _buildServiceButton("Electrician"),
                            ],
                          ),
                          const SizedBox(height: 20),
                           if (_currentPosition != null) ...[
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: const [
                                  BoxShadow(color: Colors.grey, blurRadius: 4, offset: Offset(0, 2)),
                                ],
                              ),
                              padding: const EdgeInsets.all(12),
                              child: AcceptedWorkerPage(
                                customerId: widget.userId,
                                customerLat: _currentPosition!.latitude,
                                customerLon: _currentPosition!.longitude,
                              ),
                            ),
                            const SizedBox(height: 20),
                           ],
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: const [
                                BoxShadow(color: Colors.grey, blurRadius: 4, offset: Offset(0, 2)),
                              ],
                            ),
                            padding: const EdgeInsets.all(12),
                            child: CustomerBookingPreview(userId: widget.userId),
                          ),
                          const SizedBox(height: 20),
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: const [
                                BoxShadow(color: Colors.grey, blurRadius: 4, offset: Offset(0, 2)),
                              ],
                            ),
                            padding: const EdgeInsets.all(12), 
                            child: CustomerCompletedBookingPreview(userId: widget.userId),
                          ),
                          const SizedBox(height: 20),
                        ],
                      )
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
} 