import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class AdminDashboard extends StatefulWidget {
  @override
  _AdminDashboardState createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  List<dynamic> users = [];
  List<dynamic> workers = [];
  List<dynamic> bookings = [];
  double revenue = 0.0;

  @override
  void initState() {
    super.initState();
    fetchAllData();
  }

  Future<void> fetchAllData() async {
    await fetchUsers();
    await fetchWorkers();
    await fetchBookings();
    await fetchRevenue();
  }

  Future<void> fetchUsers() async {
    final res = await http.get(Uri.parse("http://192.168.1.2:8000/admin/users"));
    if (res.statusCode == 200) {
      setState(() {
        users = json.decode(res.body);
      });
    }
  }

  Future<void> fetchWorkers() async {
    final res = await http.get(Uri.parse("http://192.168.1.2:8000/admin/workers"));
    if (res.statusCode == 200) {
      setState(() {
        workers = json.decode(res.body);
      });
    }
  }

  Future<void> fetchBookings() async {
    final res = await http.get(Uri.parse("http://192.168.1.2:8000/admin/bookings"));
    if (res.statusCode == 200) {
      setState(() {
        bookings = json.decode(res.body);
      });
    }
  }

  Future<void> fetchRevenue() async {
    final res = await http.get(Uri.parse("http://192.168.1.2:8000/admin/revenue"));
    if (res.statusCode == 200) {
      setState(() {
        revenue = json.decode(res.body)["total_revenue"];
      });
    }
  }

  Widget buildSection(String title, Widget child) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            child
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Admin Dashboard")),
      body: SingleChildScrollView(
        child: Column(
          children: [
            buildSection("Total Revenue", Text("\$${revenue.toStringAsFixed(2)}")),
            buildSection("Users", 
              Column(
                children: users.map((u) => ListTile(
                  title: Text(u['name']),
                  subtitle: Text(u['email']),
                  trailing: Text(u['role']),
                )).toList(),
              )
            ),
            buildSection("Workers", 
              Column(
                children: workers.map((w) => ListTile(
                  title: Text(w['name']),
                  subtitle: Text(w['skill']),
                  trailing: Text("Rating: ${w['rating']}"),
                )).toList(),
              )
            ),
            buildSection("Bookings", 
              Column(
                children: bookings.map((b) => ListTile(
                  title: Text(b['job_title']),
                  subtitle: Text("Date: ${b['date']} ${b['time']}"),
                  trailing: Text(b['status']),
                )).toList(),
              )
            ),
          ],
        ),
      ),
    );
  }
}
