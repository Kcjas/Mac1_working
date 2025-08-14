import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class ChatScreen extends StatefulWidget {
  final int? userId;
  final double? userLat;
  final double? userLon;
  const ChatScreen({super.key, this.userId, this.userLat, this.userLon});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  static const base = "http://192.168.1.2:8000";
  final _controller = TextEditingController();
  final _scroll = ScrollController();

  final String _sessionId = DateTime.now().millisecondsSinceEpoch.toString();
  final List<_Msg> _messages = []; // role: 'user' | 'bot'
  List<dynamic> _suggestions = [];

  @override
  void initState() {
    super.initState();
    // greet
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _send("hi");
    });
  }

  Future<void> _send(String text) async {
    if (text.trim().isEmpty) return;
    setState(() {
      _messages.add(_Msg(role: "user", text: text));
      _controller.clear();
    });

    final uri = Uri.parse("$base/convai/message");
    final res = await http.post(
      uri,
      headers: {"Content-Type": "application/json"},
      body: json.encode({
        "session_id": _sessionId,
        "message": text,
        "user_id": widget.userId,
        "user_lat": widget.userLat,
        "user_lon": widget.userLon,
      }),
    );

    if (res.statusCode == 200) {
      final body = json.decode(res.body);
      setState(() {
        _messages.add(_Msg(role: "bot", text: body["reply"] ?? ""));
        _suggestions = body["suggestions"] ?? [];
      });
      _scrollToEnd();
    } else {
      setState(() {
        _messages.add(_Msg(role: "bot", text: "Oops, something went wrong."));
      });
      _scrollToEnd();
    }
  }

  void _scrollToEnd() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent + 80,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Assistant")),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scroll,
              padding: const EdgeInsets.all(12),
              itemCount: _messages.length + (_suggestions.isNotEmpty ? 1 : 0),
              itemBuilder: (context, i) {
                if (i < _messages.length) {
                  final m = _messages[i];
                  final align = m.role == "user" ? Alignment.centerRight : Alignment.centerLeft;
                  final color  = m.role == "user" ? Theme.of(context).colorScheme.primary : Colors.grey.shade200;
                  final txtCol = m.role == "user" ? Colors.white : Colors.black87;
                  return Align(
                    alignment: align,
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(m.text, style: TextStyle(color: txtCol)),
                    ),
                  );
                } else {
                  // suggestions card list
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 8),
                      ..._suggestions.asMap().entries.map((e) {
                        final idx = e.key; final s = e.value;
                        return Card(
                          child: ListTile(
                            leading: const Icon(Icons.build),
                            title: Text(s["name"] ?? "—"),
                            subtitle: Text("⭐ ${s["rating"] ?? 0} • ${s["distance"]} km • \$${s["hourly_rate"]}/hr"),
                            trailing: TextButton(
                              onPressed: () {
                                _send("request #${idx + 1}");
                              },
                              child: const Text("Request"),
                            ),
                            onTap: () { _send("book #${idx + 1}"); },
                          ),
                        );
                      }),
                    ],
                  );
                }
              },
            ),
          ),
          SafeArea(
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    onSubmitted: _send,
                    decoration: const InputDecoration(
                      hintText: "Type a message…",
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: () => _send(_controller.text),
                )
              ],
            ),
          )
        ],
      ),
    );
  }
}

class _Msg {
  final String role;
  final String text;
  _Msg({required this.role, required this.text});
}
