import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  // ===== Config =====
  static const String base = "http://192.168.1.12:8000";
  final int _limit = 20;

  // ===== Data =====
  List<dynamic> users = [];
  List<dynamic> workers = [];
  List<dynamic> bookings = [];
  double revenue = 0.0;

  // ===== Paging =====
  int _usersPage = 1, _workersPage = 1, _bookingsPage = 1;
  bool _usersHasNext = false, _workersHasNext = false, _bookingsHasNext = false;

  // ===== Loading flags =====
  bool _loadingUsers = false, _loadingWorkers = false, _loadingBookings = false, _loadingRevenue = false;

  // ===== Search / Filters =====
  final _userSearch = TextEditingController();
  final _workerSearch = TextEditingController();
  final _bookingSearch = TextEditingController();
  String? _roleFilter;      // users: customer | worker | admin
  String? _skillFilter;     // workers: plumber | electrician | cleaning | hvac
  String? _statusFilter;    // bookings: pending | completed | accepted | rejected

  // ===== Sorting =====
  // Workers
  String _workersSortBy = "rating"; // rating | name
  String _workersSortDir = "desc";   // asc | desc
  // Bookings
  String _bookingsSortBy = "date";   // date | status | title
  String _bookingsSortDir = "desc";  // asc | desc

  // ===== Debounce =====
  Timer? _debUsers, _debWorkers, _debBookings;

  @override
  void initState() {
    super.initState();
    fetchAll();
  }

  @override
  void dispose() {
    _userSearch.dispose();
    _workerSearch.dispose();
    _bookingSearch.dispose();
    _debUsers?.cancel();
    _debWorkers?.cancel();
    _debBookings?.cancel();
    super.dispose();
  }

  // -------- Utilities --------
  Uri _uri(String path, Map<String, String?> q) {
    final qp = <String, String>{};
    q.forEach((k, v) {
      if (v != null && v.trim().isNotEmpty) qp[k] = v.trim();
    });
    return Uri.parse("$base$path").replace(queryParameters: qp.isEmpty ? null : qp);
  }

  Future<void> fetchAll() async {
    await Future.wait([
      _fetchUsers(reset: true),
      _fetchWorkers(reset: true),
      _fetchBookings(reset: true),
      _fetchRevenue(),
    ]);
  }

  // -------- API Calls --------
  Future<void> _fetchUsers({bool reset = false}) async {
    if (reset) {
      _usersPage = 1;
      users = [];
    }
    setState(() => _loadingUsers = true);
    try {
      final res = await http.get(_uri("/admin/users", {
        "search": _userSearch.text,
        "role": _roleFilter,
        "page": _usersPage.toString(),
        "limit": _limit.toString(),
      }));
      if (res.statusCode == 200) {
        final body = json.decode(res.body);
        final List items = body is Map ? (body["items"] ?? []) : (json.decode(res.body) ?? []);
        // If your backend returns plain list (no paging envelope), fallback:
        final useItems = (body is Map && body.containsKey("items")) ? items : (body as List);
        final hasNext = (body is Map) ? (body["has_next"] ?? false) : false;
        setState(() {
          users.addAll(useItems);
          _usersHasNext = hasNext;
        });
      }
    } finally {
      if (mounted) setState(() => _loadingUsers = false);
    }
  }

  Future<void> _fetchWorkers({bool reset = false}) async {
    if (reset) {
      _workersPage = 1;
      workers = [];
    }
    setState(() => _loadingWorkers = true);
    try {
      final res = await http.get(_uri("/admin/workers", {
        "search": _workerSearch.text,
        "skill": _skillFilter,
        "page": _workersPage.toString(),
        "limit": _limit.toString(),
        "sort_by": _workersSortBy,
        "sort_dir": _workersSortDir,
      }));
      if (res.statusCode == 200) {
        final body = json.decode(res.body);
        final List items = body is Map ? (body["items"] ?? []) : (json.decode(res.body) ?? []);
        final useItems = (body is Map && body.containsKey("items")) ? items : (body as List);
        final hasNext = (body is Map) ? (body["has_next"] ?? false) : false;
        setState(() {
          workers.addAll(useItems);
          _workersHasNext = hasNext;
        });
      }
    } finally {
      if (mounted) setState(() => _loadingWorkers = false);
    }
  }

  Future<void> _fetchBookings({bool reset = false}) async {
    if (reset) {
      _bookingsPage = 1;
      bookings = [];
    }
    setState(() => _loadingBookings = true);
    try {
      final res = await http.get(_uri("/admin/bookings", {
        "search": _bookingSearch.text,
        "status": _statusFilter,
        "page": _bookingsPage.toString(),
        "limit": _limit.toString(),
        "sort_by": _bookingsSortBy,
        "sort_dir": _bookingsSortDir,
      }));
      if (res.statusCode == 200) {
        final body = json.decode(res.body);
        final List items = body is Map ? (body["items"] ?? []) : (json.decode(res.body) ?? []);
        final useItems = (body is Map && body.containsKey("items")) ? items : (body as List);
        final hasNext = (body is Map) ? (body["has_next"] ?? false) : false;
        setState(() {
          bookings.addAll(useItems);
          _bookingsHasNext = hasNext;
        });
      }
    } finally {
      if (mounted) setState(() => _loadingBookings = false);
    }
  }

  Future<void> _fetchRevenue() async {
    setState(() => _loadingRevenue = true);
    try {
      final res = await http.get(Uri.parse("$base/admin/revenue"));
      if (res.statusCode == 200) {
        final body = json.decode(res.body);
        setState(() => revenue = body["total_revenue"]?.toDouble() ?? 0.0);
      }
    } finally {
      if (mounted) setState(() => _loadingRevenue = false);
    }
  }

  // -------- UI Helpers --------
  Widget _section(String title, Widget child, VoidCallback onRefreshTap) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const Spacer(),
              IconButton(tooltip: "Refresh", onPressed: onRefreshTap, icon: const Icon(Icons.refresh)),
            ]),
            const SizedBox(height: 10),
            child,
          ],
        ),
      ),
    );
  }

  Widget _searchField(TextEditingController c, String hint, void Function(String) onChanged) {
    return Expanded(
      child: TextField(
        controller: c,
        decoration: InputDecoration(
          hintText: hint,
          prefixIcon: const Icon(Icons.search),
          border: const OutlineInputBorder(),
          isDense: true,
        ),
        onChanged: onChanged,
      ),
    );
  }

  DropdownButton<String> _dropdown(String hint, String? value, List<String> items, ValueChanged<String?> onChanged) {
    return DropdownButton<String>(
      value: value,
      hint: Text(hint),
      items: items.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
      onChanged: onChanged,
    );
  }

  Widget _orderDropdown({
    required String value,
    required ValueChanged<String?> onChanged,
  }) {
    return DropdownButton<String>(
      value: value,
      items: const ["asc", "desc"]
          .map((e) => DropdownMenuItem(value: e, child: Text(e.toUpperCase())))
          .toList(),
      onChanged: onChanged,
    );
  }

  Widget _loadMoreButton({required bool visible, required VoidCallback onPressed}) {
    if (!visible) return const SizedBox.shrink();
    return Align(
      alignment: Alignment.centerLeft,
      child: TextButton.icon(
        onPressed: onPressed,
        icon: const Icon(Icons.keyboard_arrow_down),
        label: const Text("Load more"),
      ),
    );
  }

  // -------- Build --------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Admin Dashboard")),
      body: RefreshIndicator(
        onRefresh: fetchAll,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            children: [
              // Revenue
              _section(
                "Total Revenue",
                _loadingRevenue
                    ? const Padding(padding: EdgeInsets.all(8), child: CircularProgressIndicator())
                    : Text("\$${revenue.toStringAsFixed(2)}", style: const TextStyle(fontSize: 18)),
                _fetchRevenue,
              ),

              // USERS
              _section(
                "Users",
                Column(
                  children: [
                    Row(
                      children: [
                        _searchField(_userSearch, "Search name/email", (v) {
                          _debUsers?.cancel();
                          _debUsers = Timer(const Duration(milliseconds: 350), () {
                            _fetchUsers(reset: true);
                          });
                        }),
                        const SizedBox(width: 8),
                        _dropdown("Role", _roleFilter, const ["customer", "worker", "admin"], (v) {
                          setState(() => _roleFilter = v);
                          _fetchUsers(reset: true);
                        }),
                        const SizedBox(width: 8),
                        TextButton.icon(
                          onPressed: () {
                            setState(() {
                              _userSearch.clear();
                              _roleFilter = null;
                            });
                            _fetchUsers(reset: true);
                          },
                          icon: const Icon(Icons.clear), label: const Text("Reset"),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    if (_loadingUsers && users.isEmpty) const LinearProgressIndicator(),
                    ...users.map((u) => ListTile(
                          leading: const Icon(Icons.person),
                          title: Text(u['name'] ?? "—"),
                          subtitle: Text(u['email'] ?? "—"),
                          trailing: Chip(label: Text(u['role'] ?? "—")),
                        )),
                    _loadMoreButton(
                      visible: _usersHasNext,
                      onPressed: () {
                        _usersPage += 1;
                        _fetchUsers();
                      },
                    ),
                    if (!_loadingUsers && users.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Text("No users found."),
                      ),
                  ],
                ),
                () => _fetchUsers(reset: true),
              ),

              // WORKERS
              _section(
                "Workers",
                Column(
                  children: [
                    Column(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [
    // LINE 1: skill + reset
    Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        // Skill dropdown
        DropdownButton<String>(
          value: _skillFilter,
          hint: const Text("Skill"),
          isDense: true,
          items: const ["plumber", "electrician", "cleaning", "hvac"]
              .map((e) => DropdownMenuItem(value: e, child: Text(e)))
              .toList(),
          onChanged: (v) {
            setState(() => _skillFilter = v);
            _fetchWorkers(reset: true);
          },
        ),
        TextButton.icon(
          onPressed: () {
            setState(() {
              _skillFilter = null;
              _workersSortBy = "rating";
              _workersSortDir = "desc";
            });
            _fetchWorkers(reset: true);
          },
          icon: const Icon(Icons.clear),
          label: const Text("Reset"),
        ),
      ],
    ),

    const SizedBox(height: 8),

    // LINE 2: sort + order
    Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        // Sort by (rating/name)
        DropdownButton<String>(
          value: _workersSortBy,
          isDense: true,
          items: const ["rating", "name"]
              .map((e) => DropdownMenuItem(value: e, child: Text("Sort: $e")))
              .toList(),
          onChanged: (v) {
            setState(() => _workersSortBy = v ?? "rating");
            _fetchWorkers(reset: true);
          },
        ),
        // Order (ASC/DESC)
        DropdownButton<String>(
          value: _workersSortDir,
          isDense: true,
          items: const ["asc", "desc"]
              .map((e) => DropdownMenuItem(value: e, child: Text(e.toUpperCase())))
              .toList(),
          onChanged: (v) {
            setState(() => _workersSortDir = v ?? "desc");
            _fetchWorkers(reset: true);
          },
        ),
      ],
    ),
  ],
),
                    const SizedBox(height: 10),
                    if (_loadingWorkers && workers.isEmpty) const LinearProgressIndicator(),
                    ...workers.map((w) => ListTile(
                          leading: const Icon(Icons.build),
                          title: Text(w['name'] ?? "—"),
                          subtitle: Text("${w['skill'] ?? "—"} • \$${(w['hourly_rate'] ?? 0).toString()} / hr"),
                          trailing: Text("⭐ ${w['rating'] ?? 0}"),
                        )),
                    _loadMoreButton(
                      visible: _workersHasNext,
                      onPressed: () {
                        _workersPage += 1;
                        _fetchWorkers();
                      },
                    ),
                    if (!_loadingWorkers && workers.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Text("No workers found."),
                      ),
                  ],
                ),
                () => _fetchWorkers(reset: true),
              ),

              // BOOKINGS
              _section(
                "Bookings",
                Column(
                  children: [
                    Column(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [
    // LINE 1: status filter + reset
    Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        DropdownButton<String>(
          value: _statusFilter,
          hint: const Text("Status"),
          isDense: true,
          items: const ["pending", "completed", "cancelled"]
              .map((e) => DropdownMenuItem(value: e, child: Text(e)))
              .toList(),
          onChanged: (v) {
            setState(() => _statusFilter = v);
            _fetchBookings(reset: true);
          },
        ),
        TextButton.icon(
          onPressed: () {
            setState(() {
              _statusFilter = null;
              _bookingsSortBy = "date";
              _bookingsSortDir = "desc";
            });
            _fetchBookings(reset: true);
          },
          icon: const Icon(Icons.clear),
          label: const Text("Reset"),
        ),
      ],
    ),

    const SizedBox(height: 8),

    // LINE 2: sort field + sort direction
    Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        DropdownButton<String>(
          value: _bookingsSortBy,
          isDense: true,
          items: const ["date", "title", "status"]
              .map((e) => DropdownMenuItem(value: e, child: Text("Sort: $e")))
              .toList(),
          onChanged: (v) {
            setState(() => _bookingsSortBy = v ?? "date");
            _fetchBookings(reset: true);
          },
        ),
        DropdownButton<String>(
          value: _bookingsSortDir,
          isDense: true,
          items: const ["asc", "desc"]
              .map((e) => DropdownMenuItem(value: e, child: Text(e.toUpperCase())))
              .toList(),
          onChanged: (v) {
            setState(() => _bookingsSortDir = v ?? "desc");
            _fetchBookings(reset: true);
          },
        ),
      ],
    ),
  ],
),
                    const SizedBox(height: 10),
                    if (_loadingBookings && bookings.isEmpty) const LinearProgressIndicator(),
                    ...bookings.map((b) => ListTile(
                          leading: const Icon(Icons.event_note),
                          title: Text(b['job_title'] ?? "—"),
                          subtitle: Text("Date: ${b['date']} ${b['time']}"),
                          trailing: Chip(label: Text(b['status'] ?? "—")),
                        )),
                    _loadMoreButton(
                      visible: _bookingsHasNext,
                      onPressed: () {
                        _bookingsPage += 1;
                        _fetchBookings();
                      },
                    ),
                    if (!_loadingBookings && bookings.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Text("No bookings found."),
                      ),
                  ],
                ),
                () => _fetchBookings(reset: true),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
