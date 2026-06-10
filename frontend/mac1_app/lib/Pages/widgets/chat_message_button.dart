import 'dart:convert';
import 'package:flutter/material.dart';
import '../../services/auth_http.dart';
import '../../config/api_config.dart';

/// AppBar action that opens the Messages inbox (`/chats`) and shows a badge
/// with the user's total unread count. Refetches the count when the widget
/// (re)builds and after returning from the inbox.
class ChatInboxIcon extends StatefulWidget {
  final int userId;
  const ChatInboxIcon({super.key, required this.userId});

  @override
  State<ChatInboxIcon> createState() => _ChatInboxIconState();
}

class _ChatInboxIconState extends State<ChatInboxIcon> {
  int _unread = 0;

  @override
  void initState() {
    super.initState();
    _loadUnread();
  }

  Future<void> _loadUnread() async {
    try {
      final baseUrl = await ApiConfig.getBaseUrl();
      final res = await AuthHttp.get(Uri.parse("$baseUrl/chat/threads"));
      if (res.statusCode == 200 && mounted) {
        final body = json.decode(res.body) as Map<String, dynamic>;
        setState(() => _unread = (body["total_unread"] as num?)?.toInt() ?? 0);
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          icon: const Icon(Icons.chat_bubble_outline),
          tooltip: "Messages",
          onPressed: () => Navigator.pushNamed(
            context,
            '/chats',
            arguments: widget.userId,
          ).then((_) => _loadUnread()),
        ),
        if (_unread > 0)
          Positioned(
            right: 6,
            top: 6,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              constraints: const BoxConstraints(minWidth: 18),
              decoration: BoxDecoration(
                color: const Color(0xFFFF4D00),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                _unread > 99 ? "99+" : "$_unread",
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Outlined "message" icon button with an unread-count badge.
/// Used on booking cards (worker pending jobs, customer upcoming bookings)
/// to open the chat thread for that booking.
class MessageButton extends StatelessWidget {
  final int unread;
  final VoidCallback onPressed;

  const MessageButton({super.key, required this.unread, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        OutlinedButton(
          onPressed: onPressed,
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.black87,
            side: BorderSide(color: Colors.grey.shade300),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          child: const Icon(Icons.chat_bubble_outline, size: 20),
        ),
        if (unread > 0)
          Positioned(
            right: -4,
            top: -4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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
          ),
      ],
    );
  }
}
