import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:geolocator/geolocator.dart';

class ChatbotPage extends StatefulWidget {
  final int userId;
  const ChatbotPage({super.key, required this.userId});

  @override
  State<ChatbotPage> createState() => _ChatbotPageState();
}

class _ChatbotPageState extends State<ChatbotPage> {
  final TextEditingController _messageController = TextEditingController();
  List<Map<String, dynamic>> workers = [];
  String? intent;
  bool isLoading = false;

  Future<void> _sendMessage() async {
    final message = _messageController.text.trim();
    if (message.isEmpty) return;

    setState(() {
      isLoading = true;
    });

    Position position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );

    final url = Uri.parse("http://10.0.2.2:8000/chatbot/");
    final response = await http.post(
      url,
      headers: {"Content-Type": "application/json"},
      body: json.encode({
        "message": message,
        "lat": position.latitude,
        "lon": position.longitude,
      }),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      setState(() {
        intent = data['intent'];
        workers = List<Map<String, dynamic>>.from(data['workers']);
        isLoading = false;
      });
    } else {
      setState(() {
        isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Error contacting chatbot.")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Chatbot")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _messageController,
              decoration: const InputDecoration(
                labelText: "Describe your problem",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: isLoading ? null : _sendMessage,
              child: const Text("Send"),
            ),
            const SizedBox(height: 20),
            if (intent != null) Text("Detected service: $intent", style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            if (isLoading) const CircularProgressIndicator(),
            if (workers.isNotEmpty) const Text("Nearby Workers:"),
            Expanded(
              child: ListView.builder(
                itemCount: workers.length,
                itemBuilder: (context, index) {
                  final worker = workers[index];
                  return Card(
                    child: ListTile(
                      title: Text(worker['name']),
                      subtitle: Text("Rating: ${worker['rating']}, Distance: ${worker['distance']} km"),
                      trailing: Text("\$${worker['hourly_rate']}/hr"),
                    ),
                  );
                },
              ),
            )
          ],
        ),
      ),
    );
  }
}
