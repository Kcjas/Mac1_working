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

  Widget _buildServiceButton(String service, IconData icon, Color color) {
    return Material(
      elevation: 2,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: _currentPosition == null
            ? null
            : () {
                Navigator.pushNamed(context, '/service_workers', arguments: {
                  'skill': service.toLowerCase(),
                  'customerLat': _currentPosition!.latitude ?? "N/A",
                  'customerLon': _currentPosition!.longitude ?? "N/A",
                  'customerId': widget.userId,
                  'customerAddress': _address ?? "Unknown",
                });
              },
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: _currentPosition == null
                  ? [Colors.grey.shade300, Colors.grey.shade400]
                  : [color.withOpacity(0.8), color],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 40, color: Colors.white),
              const SizedBox(height: 12),
              Text(
                service,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text("Dashboard", style: TextStyle(fontWeight: FontWeight.w600)),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black87,
      ),
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

            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Profile Card
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.blue.shade400, Colors.blue.shade600],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.blue.shade200,
                          blurRadius: 12,
                          offset: const Offset(0, 6),
                        )
                      ],
                    ),
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.1),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  )
                                ],
                              ),
                              child: const CircleAvatar(
                                radius: 35,
                                backgroundColor: Colors.blue,
                                child: Icon(Icons.person, size: 40, color: Colors.white),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    customer.name,
                                    style: const TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      _buildInfoChip("${customer.age} yrs"),
                                      const SizedBox(width: 8),
                                      _buildInfoChip(customer.gender),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.location_on, color: Colors.white, size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _address ?? "Fetching location...",
                                  style: const TextStyle(color: Colors.white, fontSize: 14),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              IconButton(
                                onPressed: _fetchLocation,
                                icon: const Icon(Icons.refresh, color: Colors.white),
                                tooltip: "Refresh",
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Help Button
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.deepPurple.shade400, Colors.deepPurple.shade600],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.deepPurple.shade200,
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        )
                      ],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => Navigator.pushNamed(context, '/chatbot', arguments: {
                          'userId': widget.userId,
                          'customerLat': _currentPosition?.latitude ?? "N/A",
                          'customerLon': _currentPosition?.longitude ?? "N/A",
                          'customerAddress': _address ?? "Unknown",
                        }),
                        borderRadius: BorderRadius.circular(16),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.question_answer, color: Colors.white, size: 28),
                              ),
                              const SizedBox(width: 16),
                              const Expanded(
                                child: Text(
                                  "Need help identifying the problem?",
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              const Icon(Icons.arrow_forward_ios, color: Colors.white, size: 18),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Services Section
                  const Text(
                    "Select a Service",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 16),
                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 2,
                    mainAxisSpacing: 16,
                    crossAxisSpacing: 16,
                    childAspectRatio: 1.1,
                    children: [
                      _buildServiceButton("Plumbing", Icons.plumbing, Colors.orange.shade600),
                      _buildServiceButton("Cleaning", Icons.cleaning_services, Colors.teal.shade600),
                      _buildServiceButton("HVAC", Icons.ac_unit, Colors.indigo.shade600),
                      _buildServiceButton("Electrician", Icons.electrical_services, Colors.amber.shade700),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Accepted Worker Section
                  if (_currentPosition != null) ...[
                    _buildSectionCard(
                      title: "Accepted Workers",
                      icon: Icons.engineering,
                      child: AcceptedWorkerPage(
                        customerId: widget.userId,
                        customerLat: _currentPosition!.latitude,
                        customerLon: _currentPosition!.longitude,
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Pending Bookings
                  _buildSectionCard(
                    title: "Upcoming Bookings",
                    icon: Icons.pending_actions,
                    child: CustomerBookingPreview(userId: widget.userId),
                  ),
                  const SizedBox(height: 16),

                  // Completed Bookings
                  _buildSectionCard(
                    title: "Completed Services",
                    icon: Icons.check_circle_outline,
                    child: CustomerCompletedBookingPreview(userId: widget.userId),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildInfoChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.3),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade200,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(icon, color: Colors.blue.shade600, size: 24),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(12),
            child: child,
          ),
        ],
      ),
    );
  }
}