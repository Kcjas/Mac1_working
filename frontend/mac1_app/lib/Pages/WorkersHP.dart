import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import '../models/WorkerProfile.dart';
import '../services/api_service.dart';
import '../services/Booking_preview.dart';
import '../services/profilerow.dart';
import 'widgets/chat_message_button.dart';

class Workershp extends StatefulWidget {
  final int userId;
  const Workershp({super.key, required this.userId});

  @override
  State<Workershp> createState() => _WorkershpState();
}

class _WorkershpState extends State<Workershp> {
  late Future<Workerprofile> workerFuture;
  late Future<double> ratingFuture;

  Future<List<dynamic>> leaderboardFuture = Future.value([]);

  @override
  void initState() {
    super.initState();
    workerFuture = ApiService.fetchWorkerdata(widget.userId);
    ratingFuture = ApiService.fetchWorkerRating(widget.userId);
    leaderboardFuture = ApiService.fetchLeaderboard();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Workers Dashboard"),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [ChatInboxIcon(userId: widget.userId)],
      ),
      backgroundColor: Colors.grey[50],
      body: FutureBuilder<Workerprofile>(
        future: workerFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text("Error: ${snapshot.error}"));
          }
          if (!snapshot.hasData) {
            return const Center(child: Text("No Data Found"));
          }

          final worker = snapshot.data!;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: const [
                      BoxShadow(color: Colors.grey, blurRadius: 6, offset: Offset(0, 3)),
                    ],
                  ),
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      const CircleAvatar(
                        radius: 30,
                        backgroundColor: Colors.blue,
                        child: Icon(Icons.person, size: 40, color: Colors.white),
                      ),
                      const SizedBox(width: 20),
                      Container(height: 180, width: 2, color: Colors.grey.shade300),
                      const SizedBox(width: 20),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              worker.name,
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            ProfileRow(label: "Age", value: "${worker.age}"),
                            ProfileRow(label: "Gender", value: worker.gender),
                            ProfileRow(label: "Skill", value: worker.skill),
                            ProfileRow(
                              label: "Experience",
                              value: "${worker.experience} years",
                            ),
                            ProfileRow(
                              label: "Hourly Rate",
                              value: "₹${worker.hourlyRate.toStringAsFixed(2)}",
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pushNamed(
                            context,
                            '/incomingRequests',
                            arguments: widget.userId,
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text(
                          "Incoming Requests",
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pushNamed(
                            context,
                            '/wallet',
                            arguments: widget.userId,
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text(
                          "Wallet",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),
                BookingPreview(userId: widget.userId, type: 'pending'),
                BookingPreview(userId: widget.userId, type: 'completed'),

                const SizedBox(height: 30),
                FutureBuilder<double>(
                  future: ratingFuture,
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const CircularProgressIndicator();
                    }
                    final rating = snapshot.data!;
                    return Column(
                      children: [
                        const Text(
                          "Your Rating",
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        RatingBarIndicator(
                          rating: rating,
                          itemBuilder: (_, __) =>
                              const Icon(Icons.star, color: Colors.amber),
                          itemCount: 5,
                          itemSize: 30,
                        ),
                        const SizedBox(height: 6),
                        Text("$rating / 5"),
                      ],
                    );
                  },
                ),

                const SizedBox(height: 30),
                FutureBuilder<List<dynamic>>(
                  future: leaderboardFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const CircularProgressIndicator();
                    }
                    if (snapshot.hasError) {
                      return const Text("Failed to load leaderboard");
                    }

                    final leaderboard = snapshot.data ?? [];

                    return Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: const [
                          BoxShadow(color: Colors.grey, blurRadius: 6, offset: Offset(0, 3)),
                        ],
                      ),
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                "Top Rated Workers",
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.refresh),
                                onPressed: () {
                                  setState(() {
                                    leaderboardFuture =
                                        ApiService.fetchLeaderboard();
                                  });
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          if (leaderboard.isEmpty)
                            const Text("No leaderboard data yet"),
                          ...leaderboard.map((w) {
                            return Card(
                              child: ListTile(
                                leading: const Icon(
                                  Icons.star,
                                  color: Colors.amber,
                                ),
                                title: Text(w['name']),
                                trailing: Text(
                                  "${w['avg_rating']}",
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.amber,
                                  ),
                                ),
                              ),
                            );
                          }),
                        ],
                      ),
                    );
                  },
                ),
                const SizedBox(height: 20),
              ],
            ),
          );
        },
      ),
    );
  }
}
