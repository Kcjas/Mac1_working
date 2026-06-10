import 'dart:convert';
import 'package:flutter/material.dart';
import '../services/auth_http.dart';
import '../config/api_config.dart';

/// Messages inbox: all of the user's booking conversations that have at least
/// one message, newest first. Works for both customers and workers — the
/// backend resolves "the other party" per booking.
class ChatsListPage extends StatefulWidget {
  final int userId;
  const ChatsListPage({super.key, required this.userId});

  @override
  State<ChatsListPage> createState() => _ChatsListPageState();
}

class _ChatsListPageState extends State<ChatsListPage> {
  late Future<List<Map<String, dynamic>>> _threadsFuture;

  @override
  void initState() {
    super.initState();
    _threadsFuture = _fetchThreads();
  }

  Future<List<Map<String, dynamic>>> _fetchThreads() async {
    final baseUrl = await ApiConfig.getBaseUrl();
    final res = await AuthHttp.get(Uri.parse("$baseUrl/chat/threads"));
    if (res.statusCode != 200) {
      throw Exception("Failed to load chats (${res.statusCode})");
    }
    final body = json.decode(res.body) as Map<String, dynamic>;
    final list = (body["threads"] as List?) ?? [];
    return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  void _refresh() => setState(() => _threadsFuture = _fetchThreads());

  String _formatTime(String? iso) {
    if (iso == null) return "";
    final dt = DateTime.tryParse(iso)?.toLocal();
    if (dt == null) return "";
    final now = DateTime.now();
    final sameDay = dt.year == now.year && dt.month == now.month && dt.day == now.day;
    if (sameDay) {
      final h = dt.hour.toString().padLeft(2, '0');
      final m = dt.minute.toString().padLeft(2, '0');
      return "$h:$m";
    }
    return "${dt.day}/${dt.month}/${dt.year}";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("Messages", style: TextStyle(fontWeight: FontWeight.w600)),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black87,
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _threadsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Text("Error: ${snapshot.error}", style: TextStyle(color: Colors.grey.shade600)),
            );
          }
          final threads = snapshot.data ?? [];
          if (threads.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.forum_outlined, size: 64, color: Colors.grey.shade300),
                  const SizedBox(height: 16),
                  Text(
                    "No conversations yet",
                    style: TextStyle(fontSize: 18, color: Colors.grey.shade600, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    "Message a worker or customer from a booking.",
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async => _refresh(),
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: threads.length,
              separatorBuilder: (_, __) => Divider(height: 1, color: Colors.grey.shade200),
              itemBuilder: (context, i) {
                final t = threads[i];
                final unread = (t["unread_count"] as num?)?.toInt() ?? 0;
                final isMine = t["last_is_mine"] == true;
                final preview = "${isMine ? "You: " : ""}${t["last_body"] ?? ""}";
                final otherName = (t["other_name"] ?? "User").toString();

                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  leading: CircleAvatar(
                    backgroundColor: const Color(0xFFFF4D00),
                    child: Text(
                      otherName.isNotEmpty ? otherName[0].toUpperCase() : "?",
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                    ),
                  ),
                  title: Row(
                    children: [
                      Expanded(
                        child: Text(
                          otherName,
                          style: TextStyle(
                            fontWeight: unread > 0 ? FontWeight.w700 : FontWeight.w600,
                            fontSize: 15,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        _formatTime(t["last_at"]?.toString()),
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                      ),
                    ],
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            preview,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13,
                              color: unread > 0 ? Colors.black87 : Colors.grey.shade600,
                              fontWeight: unread > 0 ? FontWeight.w600 : FontWeight.w400,
                            ),
                          ),
                        ),
                        if (unread > 0)
                          Container(
                            margin: const EdgeInsets.only(left: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            constraints: const BoxConstraints(minWidth: 20),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFF4D00),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              unread > 99 ? "99+" : "$unread",
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  onTap: () => Navigator.pushNamed(
                    context,
                    '/chat',
                    arguments: {
                      'bookingId': t["booking_id"],
                      'otherName': otherName,
                      'chatOpen': t["chat_open"] ?? true,
                    },
                  ).then((_) => _refresh()),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
