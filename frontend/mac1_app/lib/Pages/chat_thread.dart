import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import '../services/auth_http.dart';
import '../config/api_config.dart';

/// 1:1 chat between the customer and worker of a booking.
///
/// Poll-based (the backend has no WebSocket layer): while the screen is open we
/// fetch new messages every few seconds via `GET /chat/{id}/messages?after_id=`.
/// Reads are pure; we mark the other party's messages read with an explicit
/// `POST /chat/{id}/read`. Chat closes 7 days after the booking is completed.
class ChatThreadPage extends StatefulWidget {
  final int bookingId;
  final String otherName;
  final bool chatOpen;

  const ChatThreadPage({
    super.key,
    required this.bookingId,
    required this.otherName,
    this.chatOpen = true,
  });

  @override
  State<ChatThreadPage> createState() => _ChatThreadPageState();
}

class _ChatThreadPageState extends State<ChatThreadPage> {
  static const int _maxLen = 2000;
  static const Duration _pollInterval = Duration(seconds: 3);

  final _controller = TextEditingController();
  final _scroll = ScrollController();

  final List<Map<String, dynamic>> _messages = [];
  int _lastId = 0;
  late bool _chatOpen;
  bool _busy = false;
  bool _loading = true;
  String? _error;
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    _chatOpen = widget.chatOpen;
    _loadInitial();
  }

  @override
  void dispose() {
    _poll?.cancel();
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<Uri> _api(String path) async {
    final baseUrl = await ApiConfig.getBaseUrl();
    return Uri.parse("$baseUrl$path");
  }

  Future<void> _loadInitial() async {
    await _fetch();
    if (!mounted) return;
    setState(() => _loading = false);
    _poll = Timer.periodic(_pollInterval, (_) => _fetch());
  }

  Future<void> _fetch() async {
    try {
      final url = await _api(
        "/chat/${widget.bookingId}/messages${_lastId > 0 ? '?after_id=$_lastId' : ''}",
      );
      final res = await AuthHttp.get(url);
      if (res.statusCode != 200) {
        if (mounted && _loading) setState(() => _error = "Couldn't load messages (${res.statusCode})");
        return;
      }
      final body = json.decode(res.body) as Map<String, dynamic>;
      final open = body["chat_open"] == true;
      final incoming = (body["messages"] as List?) ?? [];
      if (incoming.isEmpty && open == _chatOpen) return;

      if (mounted) {
        setState(() {
          _chatOpen = open;
          for (final m in incoming) {
            final msg = Map<String, dynamic>.from(m as Map);
            _messages.add(msg);
            final id = (msg["id"] as num).toInt();
            if (id > _lastId) _lastId = id;
          }
        });
      }
      if (incoming.isNotEmpty) {
        _scrollToEnd();
        _markRead();
      }
    } catch (_) {
      // Transient network blip during polling; keep the last good state.
    }
  }

  /// Mark the other party's messages read up to the latest one we've seen.
  Future<void> _markRead() async {
    if (_lastId <= 0) return;
    final hasTheirs = _messages.any((m) => m["is_mine"] != true && m["read_at"] == null);
    if (!hasTheirs) return;
    try {
      final url = await _api("/chat/${widget.bookingId}/read");
      await AuthHttp.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: json.encode({"up_to_id": _lastId}),
      );
    } catch (_) {}
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _busy || !_chatOpen) return;
    if (text.length > _maxLen) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Message too long (max $_maxLen characters).")),
      );
      return;
    }

    setState(() => _busy = true);
    try {
      final url = await _api("/chat/${widget.bookingId}/messages");
      final res = await AuthHttp.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: json.encode({"body": text}),
      );
      if (res.statusCode == 200) {
        final msg = Map<String, dynamic>.from(json.decode(res.body) as Map);
        setState(() {
          _messages.add(msg);
          final id = (msg["id"] as num).toInt();
          if (id > _lastId) _lastId = id;
          _controller.clear();
        });
        _scrollToEnd();
      } else if (res.statusCode == 403) {
        setState(() => _chatOpen = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Messaging is closed for this booking.")),
          );
        }
      } else if (res.statusCode == 429) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("You're sending messages too fast.")),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Couldn't send (${res.statusCode}).")),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Network error: $e")),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
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

  /// Index of the latest message I sent (read receipt is shown only there).
  int get _lastMineIndex {
    for (int i = _messages.length - 1; i >= 0; i--) {
      if (_messages[i]["is_mine"] == true) return i;
    }
    return -1;
  }

  @override
  Widget build(BuildContext context) {
    final lastMine = _lastMineIndex;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(widget.otherName, style: const TextStyle(fontWeight: FontWeight.w600)),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black87,
      ),
      body: Column(
        children: [
          if (!_chatOpen)
            Container(
              width: double.infinity,
              color: Colors.grey.shade100,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Text(
                "Messaging is no longer available for this booking.",
                style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                textAlign: TextAlign.center,
              ),
            ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(
                        child: Text(_error!, style: TextStyle(color: Colors.grey.shade600)),
                      )
                    : _messages.isEmpty
                        ? Center(
                            child: Text(
                              "No messages yet. Say hello 👋",
                              style: TextStyle(color: Colors.grey.shade500),
                            ),
                          )
                        : ListView.builder(
                            controller: _scroll,
                            padding: const EdgeInsets.all(12),
                            itemCount: _messages.length,
                            itemBuilder: (context, i) {
                              final m = _messages[i];
                              final isMine = m["is_mine"] == true;
                              final showReceipt = isMine && i == lastMine;
                              return Column(
                                crossAxisAlignment:
                                    isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                                children: [
                                  Align(
                                    alignment:
                                        isMine ? Alignment.centerRight : Alignment.centerLeft,
                                    child: Container(
                                      margin: const EdgeInsets.symmetric(vertical: 6),
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 10, horizontal: 12),
                                      decoration: BoxDecoration(
                                        color: isMine ? Colors.black87 : Colors.grey.shade100,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        (m["body"] ?? "").toString(),
                                        style: TextStyle(
                                          color: isMine ? Colors.white : Colors.black87,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ),
                                  ),
                                  if (showReceipt)
                                    Padding(
                                      padding: const EdgeInsets.only(right: 4, bottom: 4),
                                      child: Text(
                                        m["read_at"] != null ? "✓✓ Read" : "✓ Sent",
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: m["read_at"] != null
                                              ? const Color(0xFFFF4D00)
                                              : Colors.grey.shade500,
                                        ),
                                      ),
                                    ),
                                ],
                              );
                            },
                          ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      onSubmitted: (_) => _send(),
                      enabled: _chatOpen && !_busy,
                      maxLength: _maxLen,
                      maxLines: null,
                      decoration: InputDecoration(
                        hintText: _chatOpen ? "Type a message…" : "Messaging closed",
                        hintStyle: TextStyle(color: Colors.grey.shade500),
                        counterText: "",
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.grey.shade400, width: 1),
                        ),
                        contentPadding:
                            const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        isDense: true,
                      ),
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: _chatOpen ? Colors.black87 : Colors.grey.shade400,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: IconButton(
                      icon: _busy
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Icon(Icons.send, color: Colors.white, size: 20),
                      onPressed: (_busy || !_chatOpen) ? null : _send,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
