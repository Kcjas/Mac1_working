import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../services/auth_http.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import '../config/api_config.dart';

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
  Future<Uri> _api(String path) async {
    final baseUrl = await ApiConfig.getBaseUrl();
    return Uri.parse("$baseUrl$path");
  }

  final _controller = TextEditingController();
  final _scroll = ScrollController();
  final String _sessionId = DateTime.now().millisecondsSinceEpoch.toString();

  final List<_Msg> _messages = [];
  List<Map<String, dynamic>> _suggestions = [];
  double? _lat, _lon;
  String? _address;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _lat = widget.userLat;
    _lon = widget.userLon;
    _address = widget.userAddress;
    WidgetsBinding.instance.addPostFrameCallback((_) => _send("hi"));
  }

  Future<void> _ensureLocation() async {
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
            ].where((e) => (e ?? '').toString().trim().isNotEmpty).join(', ');
          });
        }
      } catch (_) {}
      return;
    }

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
          ].where((e) => (e ?? '').toString().trim().isNotEmpty).join(', ');
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

    if (_lat == null || _lon == null) {
      await _ensureLocation();
    }

    try {
      final apiUrl = await _api("/convai/message");
      final res = await AuthHttp.post(
        apiUrl,
        headers: {"Content-Type": "application/json"},
        body: json.encode({
          "session_id": _sessionId,
          "message": text,
          "user_id": widget.userId,
          "user_lat": _lat,
          "user_lon": _lon,
        }),
      );

      if (res.statusCode == 200) {
        final Map<String, dynamic> body = json.decode(res.body);
        final reply = (body["reply"] ?? "").toString();
        setState(() {
          _messages.add(_Msg(role: "bot", text: reply));
        });

        final sugg = body["suggestions"];
        if (sugg is List) {
          setState(() {
            _suggestions = sugg.map<Map<String, dynamic>>((e) {
              if (e is Map<String, dynamic>) return e;
              return Map<String, dynamic>.from(e as Map);
            }).toList();
          });
        } else {
          setState(() => _suggestions = []);
        }

        final redirect = body["redirect"];
        if (redirect is Map<String, dynamic>) {
          final path = (redirect["path"] ?? "").toString();
          final params = (redirect["params"] is Map<String, dynamic>)
              ? (redirect["params"] as Map<String, dynamic>)
              : <String, dynamic>{};
          if (widget.userId != null) {
            params["customerId"] = widget.userId;
          }
          if (_lat != null && _lon != null) {
            params["customer_lat"] = _lat;
            params["customer_lon"] = _lon;
          }
          if (_address != null) {
            params["customerAddress"] = _address;
          }
          try {
            if (!mounted) return;
            Navigator.pushNamed(context, path, arguments: params);
          } catch (_) {
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Job Request route not found. Wire '/job-request' in your routes.")),
            );
          }
        }
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
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("Assistant", style: TextStyle(fontWeight: FontWeight.w600)),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black87,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(20),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 12, left: 16, right: 16),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                locLine,
                style: TextStyle(
                  fontSize: 12,
                  color: hasLoc ? Colors.grey.shade600 : Colors.amber.shade700,
                ),
              ),
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          if (!hasLoc)
            Container(
              color: Colors.amber.shade50,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Icon(Icons.location_off, size: 18, color: Colors.amber.shade700),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      "Share your location to find nearby workers",
                      style: TextStyle(fontSize: 14, color: Colors.amber.shade900),
                    ),
                  ),
                  TextButton(
                    onPressed: _ensureLocation,
                    child: Text(
                      "Enable",
                      style: TextStyle(color: Colors.amber.shade700, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: ListView.builder(
              controller: _scroll,
              padding: const EdgeInsets.all(12),
              itemCount: _messages.length + (_suggestions.isNotEmpty ? 1 : 0),
              itemBuilder: (context, i) {
                if (i < _messages.length) {
                  final m = _messages[i];
                  final isUser = m.role == "user";
                  return Align(
                    alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                      decoration: BoxDecoration(
                        color: isUser ? Colors.black87 : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        m.text,
                        style: TextStyle(
                          color: isUser ? Colors.white : Colors.black87,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  );
                } else {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 12),
                      ..._suggestions.asMap().entries.map((e) {
                        final idx = e.key;
                        final s = e.value;
                        final name = (s["name"] ?? "—").toString();
                        final rating = (s["rating"] ?? 0).toString();
                        final dist = (s["distance"] ?? "-").toString();
                        final rate = (s["hourly_rate"] ?? "-").toString();

                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: ListTile(
                            leading: Icon(Icons.build_outlined, color: Colors.grey.shade600),
                            title: Text(name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                            subtitle: Text("⭐ $rating • $dist km • \$$rate/hr", style: const TextStyle(fontSize: 12)),
                            trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
                            onTap: () => _send("${idx + 1}"),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      onSubmitted: _send,
                      enabled: !_busy,
                      decoration: InputDecoration(
                        hintText: "Type a message…",
                        hintStyle: TextStyle(color: Colors.grey.shade500),
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
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        isDense: true,
                      ),
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.black87,
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
                      onPressed: _busy ? null : () => _send(_controller.text),
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

class _Msg {
  final String role;
  final String text;
  _Msg({required this.role, required this.text});
}
