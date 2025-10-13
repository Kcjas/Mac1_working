import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

class ChatScreen extends StatefulWidget {
  final int? userId;
  final double? userLat;
  final double? userLon;
  final String? userAddress;

  const ChatScreen({
    super.key,
    this.userId,
    this.userLat,
    this.userLon,
    this.userAddress,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  static const String base = "10.130.27.237";

  final _controller = TextEditingController();
  final _scroll = ScrollController();
  final String _sessionId = DateTime.now().millisecondsSinceEpoch.toString();

  final List<_Msg> _messages = []; // role: 'user' | 'bot'
  List<dynamic> _suggestions = [];


  double? _lat, _lon;
  String? _address;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _lat = widget.userLat;
    _lon = widget.userLon;
    _address = widget.userAddress;
    // greet
    WidgetsBinding.instance.addPostFrameCallback((_) => _send("hi"));
  }

  Future<void> _ensureLocation() async {
    // If already have coords, try to reverse-geocode once (optional).
    if (_lat != null && _lon != null && _address == null) {
      try {
        final placemarks = await placemarkFromCoordinates(_lat!, _lon!);
        if (placemarks.isNotEmpty) {
          final p = placemarks.first;
          setState(() {
            _address = [
              p.street,
              p.subLocality,
              p.locality,
              p.administrativeArea,
              p.postalCode,
              p.country
            ].where((e) => (e ?? '').trim().isNotEmpty).join(', ');
          });
        }
      } catch (_) {}
      return;
    }

    // Otherwise, fetch fresh coords.
    final enabled = await Geolocator.isLocationServiceEnabled();
    if (!enabled) {
      await Geolocator.openLocationSettings();
    }

    LocationPermission perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.deniedForever) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location permanently denied. Enable it in Settings.')),
        );
      }
      return;
    }

    try {
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );
      String? addr;
      try {
        final placemarks = await placemarkFromCoordinates(pos.latitude, pos.longitude);
        if (placemarks.isNotEmpty) {
          final p = placemarks.first;
          addr = [
            p.street,
            p.subLocality,
            p.locality,
            p.administrativeArea,
            p.postalCode,
            p.country
          ].where((e) => (e ?? '').trim().isNotEmpty).join(', ');
        }
      } catch (_) {}
      if (!mounted) return;
      setState(() {
        _lat = pos.latitude;
        _lon = pos.longitude;
        _address = addr;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not get location: $e')),
      );
    }
  }

  Future<void> _send(String text) async {
    if (text.trim().isEmpty || _busy) return;

    setState(() {
      _messages.add(_Msg(role: "user", text: text));
      _controller.clear();
      _busy = true;
    });

    // If we don't have location yet, try to fetch once (non-blocking for user UX).
    if (_lat == null || _lon == null) {
      await _ensureLocation();
    }

    final uri = Uri.parse("$base/convai/message");
    try {
      final res = await http.post(
        uri,
        headers: {"Content-Type": "application/json"},
        body: json.encode({
          "session_id": _sessionId,
          "message": text,
          "user_id": widget.userId,
          "user_lat": _lat, // may be null if user declined; backend should handle gracefully
          "user_lon": _lon,
        }),
      );

      if (res.statusCode == 200) {
        final body = json.decode(res.body);
        setState(() {
          _messages.add(_Msg(role: "bot", text: (body["reply"] ?? "").toString()));
          _suggestions = body["suggestions"] ?? [];
        });
      } else {
        setState(() {
          _messages.add(_Msg(role: "bot", text: "Oops, something went wrong. (${res.statusCode})"));
        });
      }
    } catch (e) {
      setState(() {
        _messages.add(_Msg(role: "bot", text: "Network error: $e"));
      });
    } finally {
      _scrollToEnd();
      setState(() => _busy = false);
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
    final hasLoc = _lat != null && _lon != null;
    final locLine = hasLoc
        ? (_address ?? "${_lat!.toStringAsFixed(5)}, ${_lon!.toStringAsFixed(5)}")
        : "Location not shared";

    return Scaffold(
      appBar: AppBar(
        title: const Text("Assistant"),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(24),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              locLine,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: hasLoc ? Colors.white70 : Colors.amberAccent,
                  ),
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          if (!hasLoc)
            MaterialBanner(
              content: const Text("I can’t find nearby workers without your location."),
              actions: [
                TextButton(
                  onPressed: _ensureLocation,
                  child: const Text("Share now"),
                ),
              ],
            ),
          Expanded(
            child: ListView.builder(
              controller: _scroll,
              padding: const EdgeInsets.all(12),
              itemCount: _messages.length + (_suggestions.isNotEmpty ? 1 : 0),
              itemBuilder: (context, i) {
                if (i < _messages.length) {
                  final m = _messages[i];
                  final align = m.role == "user" ? Alignment.centerRight : Alignment.centerLeft;
                  final color  = m.role == "user"
                      ? Theme.of(context).colorScheme.primary
                      : Colors.grey.shade200;
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
                        final rating = (s["rating"] ?? 0).toString();
                        final dist = (s["distance"] ?? "-").toString();
                        final rate = (s["hourly_rate"] ?? "-").toString();

                        return Card(
                          child: ListTile(
                            leading: const Icon(Icons.build),
                            title: Text(s["name"]?.toString() ?? "—"),
                            subtitle: Text("⭐ $rating • $dist km • \$$rate/hr"),
                            trailing: TextButton(
                              onPressed: () => _send("request #${idx + 1}"),
                              child: const Text("Request"),
                            ),
                            onTap: () => _send("book #${idx + 1}"),
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
                  icon: _busy ? const SizedBox(
                    width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)
                  ) : const Icon(Icons.send),
                  onPressed: _busy ? null : () => _send(_controller.text),
                )
              ],
            ),
          ),
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
