import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../services/auth_http.dart';
import 'package:fl_chart/fl_chart.dart'; 
import '../services/api_service.dart';
import '../config/api_config.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  static const int usersLimit = 5;
  static const int workersLimit = 5;
  static const int bookingsLimit = 5;

  Map<String, String> get _headers => {
        "Accept": "application/json",
        "Content-Type": "application/json",
      };
  
  final Map<String, Color> _jobColors = {
    "plumber": Colors.blue,
    "electrician": Colors.amber,
    "cleaning": Colors.green,
    "hvac": Colors.redAccent,
    "carpenter": Colors.brown,
    "other": Colors.grey,
  };

  Color _getColorForSkill(String skill) {
    String lower = skill.toLowerCase();
    if (lower.contains("plumb")) return _jobColors["plumber"]!;
    if (lower.contains("elect")) return _jobColors["electrician"]!;
    if (lower.contains("clean")) return _jobColors["cleaning"]!;
    if (lower.contains("hvac")) return _jobColors["hvac"]!;
    if (lower.contains("carpet") || lower.contains("clean")) return _jobColors["cleaning"]!; 
    return _jobColors["other"]!;
  }

  Future<Uri> _buildUri(String path, [Map<String, String?> q = const {}]) async {
    final baseUrl = await ApiConfig.getBaseUrl();
    final cleanPath = path.startsWith("/") ? path : "/$path";
    var uri = Uri.parse("$baseUrl$cleanPath");
    
    final qp = <String, String>{};
    q.forEach((k, v) {
      if (v != null && v.trim().isNotEmpty) qp[k] = v.trim();
    });
    
    if (qp.isNotEmpty) {
      uri = uri.replace(queryParameters: qp);
    }
    return uri;
  }

  Future<http.Response> _get(String path, {Map<String, String?> q = const {}}) async {
    final uri = await _buildUri(path, q);
    final res = await AuthHttp.get(uri, headers: _headers);
    if (res.statusCode >= 200 && res.statusCode < 300) return res;
    throw Exception("GET $path failed (${res.statusCode}): ${res.body}");
  }

  Future<http.Response> _patch(String path, Map<String, dynamic> body) async {
    final uri = await _buildUri(path);
    final res = await AuthHttp.patch(uri, headers: _headers, body: json.encode(body));
    if (res.statusCode >= 200 && res.statusCode < 300) return res;
    throw Exception("PATCH $path failed (${res.statusCode}): ${res.body}");
  }

  Future<http.Response> _delete(String path) async {
    final uri = await _buildUri(path);
    final res = await AuthHttp.delete(uri, headers: _headers);
    if (res.statusCode >= 200 && res.statusCode < 300) return res;
    throw Exception("DELETE $path failed (${res.statusCode}): ${res.body}");
  }

  ({List data, bool hasNext}) _parseList(String body, {required int limit}) {
    final decoded = json.decode(body);
    if (decoded is List) return (data: decoded, hasNext: decoded.length >= limit);
    if (decoded is Map) {
      final items = (decoded["items"] ?? decoded["data"] ?? decoded["results"] ?? []) as List;
      final hasNext = (decoded["has_next"] == true) ||
          (decoded["next"] != null) ||
          (decoded["page"] != null &&
              decoded["total_pages"] != null &&
              decoded["page"] < decoded["total_pages"]);
      return (data: items, hasNext: hasNext);
    }
    return (data: const [], hasNext: false);
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  double revenue = 0;
  int pendingCount = 0;
  int completedCount = 0;
  Map<String, dynamic> jobPopularity = {};
  Map<String, dynamic> workerDistribution = {};
  List<dynamic> monthlyUsers = [];
  bool loadingStats = false;

  final userSearch = TextEditingController();
  String? roleFilter;
  List users = [];
  bool loadingUsers = false, usersHasNext = false;
  int usersPage = 1;

  final workerSearch = TextEditingController();
  String? skillFilter;
  String workersSortBy = "rating", workersSortDir = "desc";
  List workers = [];
  bool loadingWorkers = false, workersHasNext = false;
  int workersPage = 1;

  final bookingSearch = TextEditingController();
  String? statusFilter;
  String bookingsSortBy = "date", bookingsSortDir = "desc";
  List bookings = [];
  bool loadingBookings = false, bookingsHasNext = false;
  int bookingsPage = 1;

  Timer? debUsers, debWorkers, debBookings;

  @override
  void initState() {
    super.initState();
    _refreshAll();
  }

  @override
  void dispose() {
    userSearch.dispose();
    workerSearch.dispose();
    bookingSearch.dispose();
    debUsers?.cancel();
    debWorkers?.cancel();
    debBookings?.cancel();
    super.dispose();
  }

  Future<void> _refreshAll() async {
    await Future.wait([
      _fetchStats(),
      _fetchUsers(page: 1),
      _fetchWorkers(page: 1),
      _fetchBookings(page: 1),
    ]);
  }

  Future<void> _fetchStats() async {
    setState(() => loadingStats = true);
    try {
      // Fetch Revenue
      final revRes = await _get("/admin/revenue");
      final revBody = json.decode(revRes.body);
      
      // Fetch Counts & Charts
      final statsRes = await _get("/admin/stats");
      final statsBody = json.decode(statsRes.body);

      if (mounted) {
        setState(() {
          revenue = (revBody["total_revenue"] ?? 0).toDouble();
          pendingCount = statsBody["pending_count"] ?? 0;
          completedCount = statsBody["completed_count"] ?? 0;
          jobPopularity = statsBody["job_popularity"] ?? {};
          workerDistribution = statsBody["worker_distribution"] ?? {};
          monthlyUsers = statsBody["monthly_users"] ?? [];
        });
      }
    } catch (e) {
      _toast("Stats error: $e");
    } finally {
      if (mounted) setState(() => loadingStats = false);
    }
  }

  Future<void> _fetchUsers({int? page}) async {
    if (page != null) usersPage = page;
    setState(() => loadingUsers = true);
    try {
      final res = await _get("/admin/users", q: {
        "search": userSearch.text,
        "role": roleFilter,
        "page": "$usersPage",
        "limit": "$usersLimit",
      });
      final parsed = _parseList(res.body, limit: usersLimit);
      setState(() {
        users = parsed.data;
        usersHasNext = parsed.hasNext;
      });
    } catch (e) {
      _toast("Users error: $e");
    } finally {
      if (mounted) setState(() => loadingUsers = false);
    }
  }

  Future<void> _fetchWorkers({int? page}) async {
    if (page != null) workersPage = page;
    setState(() => loadingWorkers = true);
    try {
      final res = await _get("/admin/workers", q: {
        "search": workerSearch.text,
        "skill": skillFilter,
        "page": "$workersPage",
        "limit": "$workersLimit",
        "sort_by": workersSortBy,
        "sort_dir": workersSortDir,
      });
      final parsed = _parseList(res.body, limit: workersLimit);
      setState(() {
        workers = parsed.data;
        workersHasNext = parsed.hasNext;
      });
    } catch (e) {
      _toast("Workers error: $e");
    } finally {
      if (mounted) setState(() => loadingWorkers = false);
    }
  }

  Future<void> _fetchBookings({int? page}) async {
    if (page != null) bookingsPage = page;
    setState(() => loadingBookings = true);
    try {
      final res = await _get("/admin/bookings", q: {
        "search": bookingSearch.text,
        "status": statusFilter,
        "page": "$bookingsPage",
        "limit": "$bookingsLimit",
        "sort_by": bookingsSortBy,
        "sort_dir": bookingsSortDir,
      });
      final parsed = _parseList(res.body, limit: bookingsLimit);
      setState(() {
        bookings = parsed.data;
        bookingsHasNext = parsed.hasNext;
      });
    } catch (e) {
      _toast("Bookings error: $e");
    } finally {
      if (mounted) setState(() => loadingBookings = false);
    }
  }


  Future<void> _editUserDialog(Map u) async {
    final nameCtrl = TextEditingController(text: "${u['name'] ?? ''}");
    final emailCtrl = TextEditingController(text: "${u['email'] ?? ''}");
    String role = "${u['role'] ?? 'customer'}";

    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Edit User"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: "Name")),
            const SizedBox(height: 16),
            TextField(controller: emailCtrl, decoration: const InputDecoration(labelText: "Email")),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: role,
              items: const ["customer", "worker", "admin"]
                  .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                  .toList(),
              onChanged: (v) => role = v ?? role,
              decoration: const InputDecoration(labelText: "Role"),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text("Save")),
        ],
      ),
    );

    if (saved == true) {
      try {
        await _patch("/admin/users/${u['id']}", {
          "name": nameCtrl.text.trim(),
          "email": emailCtrl.text.trim(),
          "role": role,
        });
        _toast("User updated");
        await _fetchUsers(page: usersPage);
      } catch (e) {
        _toast("Update failed: $e");
      }
    }
  }

  Future<void> _deleteUser(Map u) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Delete User"),
        content: Text("Delete ${u['name'] ?? 'this user'}?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text("Delete")),
        ],
      ),
    );
    if (ok == true) {
      try {
        await _delete("/admin/users/${u['id']}");
        _toast("User deleted");
        if (users.length <= 1 && usersPage > 1) usersPage--;
        await _fetchUsers(page: usersPage);
      } catch (e) {
        _toast("Delete failed: $e");
      }
    }
  }

  Future<void> _warnWorker(int workerId) async {
    try {
      final uri = await _buildUri("/admin/warn/$workerId");
      final res = await AuthHttp.post(uri, headers: _headers);
      if (res.statusCode == 200) {
        _toast("Warning sent to worker");
      } else {
        _toast("Failed to warn");
      }
    } catch (e) {
      _toast("Error: $e");
    }
  }

  Future<void> _editWorkerDialog(Map w) async {
    final skillCtrl = TextEditingController(text: "${w['skill'] ?? ''}");
    final rateCtrl = TextEditingController(text: "${w['hourly_rate'] ?? 0}");
    final expCtrl = TextEditingController(text: "${w['experience'] ?? 0}");

    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Edit Worker"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: skillCtrl, decoration: const InputDecoration(labelText: "Skill")),
            const SizedBox(height: 16),
            TextField(controller: rateCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "Hourly Rate")),
            const SizedBox(height: 16),
            TextField(controller: expCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "Experience (years)")),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text("Save")),
        ],
      ),
    );

    if (saved == true) {
      try {
        await _patch("/admin/workers/${w['id']}", {
          "skill": skillCtrl.text.trim(),
          "hourly_rate": double.tryParse(rateCtrl.text) ?? 0,
          "experience": int.tryParse(expCtrl.text) ?? 0,
        });
        _toast("Worker updated");
        await _fetchWorkers(page: workersPage);
      } catch (e) {
        _toast("Update failed: $e");
      }
    }
  }

  Future<void> _editBookingDialog(Map b) async {
    final titleCtrl = TextEditingController(text: "${b['job_title'] ?? ''}");
    final dateCtrl = TextEditingController(text: "${b['date'] ?? ''}");
    final timeCtrl = TextEditingController(text: "${b['time'] ?? ''}");
    String status = "${b['status'] ?? 'pending'}";

    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Edit Booking"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: "Title")),
            const SizedBox(height: 16),
            TextField(controller: dateCtrl, decoration: const InputDecoration(labelText: "Date (YYYY-MM-DD)")),
            const SizedBox(height: 16),
            TextField(controller: timeCtrl, decoration: const InputDecoration(labelText: "Time (HH:MM)")),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: status,
              items: const ["pending", "completed"]
                  .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                  .toList(),
              onChanged: (v) => status = v ?? status,
              decoration: const InputDecoration(labelText: "Status"),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text("Save")),
        ],
      ),
    );

    if (saved == true) {
      try {
        await _patch("/admin/bookings/${b['id']}", {
          "job_title": titleCtrl.text.trim(),
          "date": dateCtrl.text.trim(),
          "time": timeCtrl.text.trim(),
          "status": status,
        });
        _toast("Booking updated");
        await _fetchBookings(page: bookingsPage);
        // await _fetchRevenue(); // Stat is auto refreshed in _fetchStats
      } catch (e) {
        _toast("Update failed: $e");
      }
    }
  }

  // ================= UI HELPERS =================
  Widget _statCard(String title, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[200]!),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: TextStyle(color: Colors.grey[600], fontSize: 13, fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            Text(value, style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _pager({
    required int page,
    required bool hasNext,
    required bool isLoading,
    required VoidCallback onPrev,
    required VoidCallback onNext,
  }) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Text("Page $page", style: TextStyle(color: Colors.grey[600], fontSize: 13)),
          const SizedBox(width: 4),
          IconButton(
            onPressed: (page > 1 && !isLoading) ? onPrev : null,
            icon: const Icon(Icons.chevron_left, size: 20),
            visualDensity: VisualDensity.compact,
          ),
          IconButton(
            onPressed: (hasNext && !isLoading) ? onNext : null,
            icon: const Icon(Icons.chevron_right, size: 20),
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }

  Widget _section(String title, Widget child, {List<Widget> actions = const []}) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Expanded(child: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis)),
              ...actions,
            ]),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }

  Widget _buildLegend(Map<String, dynamic> data) {
    if (data.isEmpty) return const SizedBox.shrink();
    return Wrap(
      spacing: 16,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      children: data.keys.map((key) {
        final color = _getColorForSkill(key);
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 12, height: 12, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
            const SizedBox(width: 4),
            Text(key.toUpperCase(), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.black54)),
          ],
        );
      }).toList(),
    );
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text("Admin Dashboard"),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
      ),
      body: RefreshIndicator(
        onRefresh: _refreshAll,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            children: [
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    _statCard("Total Revenue", "\$${revenue.toStringAsFixed(0)}", Colors.green),
                    const SizedBox(width: 12),
                    _statCard("Pending Bookings", "$pendingCount", Colors.orange),
                    const SizedBox(width: 12),
                    _statCard("Completed Bookings", "$completedCount", Colors.blue),
                  ],
                ),
              ),
              if (!loadingStats) ...[
                const SizedBox(height: 24),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    children: [_section("Job Popularity", Column(children: [
                            AspectRatio(aspectRatio: 1.5,
                              child: jobPopularity.isEmpty ? const Center(child: Text("No data")): PieChart(
                                  PieChartData(sections: jobPopularity.entries.map((e) {
                                      final color = _getColorForSkill(e.key.toString());
                                      return PieChartSectionData(
                                        value: (e.value as num).toDouble(),
                                        title: "${e.value}", 
                                        color: color,
                                        radius: 50,
                                        titleStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                                      );
                                    }).toList(),
                                    sectionsSpace: 2,
                                    centerSpaceRadius: 40,
                                  ),),),
                            const SizedBox(height: 24),
                            _buildLegend(jobPopularity),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      _section("Worker Skills", 
                        Column(
                          children: [
                            AspectRatio(
                              aspectRatio: 1.5,
                              child: workerDistribution.isEmpty 
                                ? const Center(child: Text("No data"))
                                : PieChart(
                                  PieChartData(
                                    sections: workerDistribution.entries.map((e) {
                                      final color = _getColorForSkill(e.key.toString());
                                      return PieChartSectionData(
                                        value: (e.value as num).toDouble(),
                                        title: "${e.value}", // Only show count
                                        color: color,
                                        radius: 50,
                                        titleStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                                      );
                                    }).toList(),
                                    sectionsSpace: 2,
                                    centerSpaceRadius: 40,
                                  ),
                                ),
                            ),
                            const SizedBox(height: 24),
                            _buildLegend(workerDistribution),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 12),

              // USERS
              _section(
                "Users",
                Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: userSearch,
                            decoration: InputDecoration(
                              prefixIcon: const Icon(Icons.search, size: 20),
                              hintText: "Search name or email",
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            ),
                            onChanged: (_) {
                              debUsers?.cancel();
                              debUsers = Timer(const Duration(milliseconds: 300), () => _fetchUsers(page: 1));
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey[300]!),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: DropdownButton<String>(
                            value: roleFilter,
                            hint: const Text("Role", style: TextStyle(fontSize: 14)),
                            underline: const SizedBox(),
                            items: const ["customer", "worker", "admin"]
                                .map((e) => DropdownMenuItem(value: e, child: Text(e, style: TextStyle(fontSize: 14))))
                                .toList(),
                            onChanged: (v) {
                              setState(() => roleFilter = v);
                              _fetchUsers(page: 1);
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ...users.map((u) => Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          decoration: BoxDecoration(
                            color: Colors.grey[50],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: Colors.blue[50],
                              child: Icon(Icons.person, color: Colors.blue[700], size: 20),
                            ),
                            title: Text(u['name'] ?? '—', style: const TextStyle(fontWeight: FontWeight.w500)),
                            subtitle: Text(u['email'] ?? '', style: TextStyle(fontSize: 13, color: Colors.grey[600])),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.grey[200],
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(u['role'] ?? '—', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                                ),
                                const SizedBox(width: 4),
                                IconButton(
                                  icon: const Icon(Icons.edit_outlined, size: 18),
                                  onPressed: () => _editUserDialog(u),
                                  visualDensity: VisualDensity.compact,
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, size: 18),
                                  onPressed: () => _deleteUser(u),
                                  visualDensity: VisualDensity.compact,
                                ),
                              ],
                            ),
                          ),
                        )),
                    _pager(
                      page: usersPage,
                      hasNext: usersHasNext,
                      isLoading: loadingUsers,
                      onPrev: () => _fetchUsers(page: usersPage - 1),
                      onNext: () => _fetchUsers(page: usersPage + 1),
                    ),
                    if (!loadingUsers && users.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: Text("No users found", style: TextStyle(color: Colors.grey[500])),
                      ),
                  ],
                ),
                actions: [
                  IconButton(
                    onPressed: () => _fetchUsers(page: 1),
                    icon: const Icon(Icons.refresh, size: 20),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),

              // WORKERS
              _section(
                "Workers",
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey[300]!),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: DropdownButton<String>(
                            value: skillFilter,
                            hint: const Text("Skill", style: TextStyle(fontSize: 14)),
                            underline: const SizedBox(),
                            items: const ["plumber", "electrician", "cleaning", "hvac"]
                                .map((e) => DropdownMenuItem(value: e, child: Text(e, style: TextStyle(fontSize: 14))))
                                .toList(),
                            onChanged: (v) {
                              setState(() => skillFilter = v);
                              _fetchWorkers(page: 1);
                            },
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey[300]!),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: DropdownButton<String>(
                            value: workersSortBy,
                            underline: const SizedBox(),
                            items: const ["rating", "name"]
                                .map((e) => DropdownMenuItem(value: e, child: Text("Sort: $e", style: TextStyle(fontSize: 14))))
                                .toList(),
                            onChanged: (v) {
                              setState(() => workersSortBy = v ?? "rating");
                              _fetchWorkers(page: 1);
                            },
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey[300]!),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: DropdownButton<String>(
                            value: workersSortDir,
                            underline: const SizedBox(),
                            items: const ["asc", "desc"]
                                .map((e) => DropdownMenuItem(value: e, child: Text(e.toUpperCase(), style: TextStyle(fontSize: 14))))
                                .toList(),
                            onChanged: (v) {
                              setState(() => workersSortDir = v ?? "desc");
                              _fetchWorkers(page: 1);
                            },
                          ),
                        ),
                        SizedBox(
                          width: 200,
                          child: TextField(
                            controller: workerSearch,
                            decoration: InputDecoration(
                              hintText: "Search worker",
                              isDense: true,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                              prefixIcon: const Icon(Icons.search, size: 20),
                            ),
                            onChanged: (_) {
                              debWorkers?.cancel();
                              debWorkers = Timer(const Duration(milliseconds: 300),
                                  () => _fetchWorkers(page: 1));
                            },
                          ),
                        ),
                        TextButton.icon(
                          onPressed: () {
                            setState(() {
                              workerSearch.clear();
                              skillFilter = null;
                              workersSortBy = "rating";
                              workersSortDir = "desc";
                            });
                            _fetchWorkers(page: 1);
                          },
                          icon: const Icon(Icons.clear, size: 18),
                          label: const Text("Reset", style: TextStyle(fontSize: 14)),
                          style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ...workers.map((w) => Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          decoration: BoxDecoration(
                            color: Colors.grey[50],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: Colors.orange[50],
                              child: Icon(Icons.build, color: Colors.orange[700], size: 20),
                            ),
                            title: Text(w['name'] ?? '—', style: const TextStyle(fontWeight: FontWeight.w500)),
                            subtitle: Text(
                              "${w['skill'] ?? '—'} • \$${(w['hourly_rate'] ?? 0)}/hr"
                              "${w['experience'] != null ? ' • ${w['experience']} yrs' : ''}",
                              style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.amber[50],
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.star, size: 14, color: Colors.amber),
                                      const SizedBox(width: 4),
                                      Text("${w['rating'] ?? 0}", style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 4),
                                if ((w['rating'] ?? 5) < 3.0)
                                  IconButton(
                                    tooltip: "Warn Low Rating",
                                    icon: const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 20),
                                    onPressed: () => _warnWorker(w['id']),
                                    visualDensity: VisualDensity.compact,
                                  ),
                                IconButton(
                                  tooltip: "Edit Worker",
                                  icon: const Icon(Icons.edit_outlined, size: 18),
                                  onPressed: () => _editWorkerDialog(w),
                                  visualDensity: VisualDensity.compact,
                                ),
                              ],
                            ),
                          ),
                        )),
                    _pager(
                      page: workersPage,
                      hasNext: workersHasNext,
                      isLoading: loadingWorkers,
                      onPrev: () => _fetchWorkers(page: workersPage - 1),
                      onNext: () => _fetchWorkers(page: workersPage + 1),
                    ),
                    if (!loadingWorkers && workers.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: Text("No workers found", style: TextStyle(color: Colors.grey[500])),
                      ),
                  ],
                ),
                actions: [
                  IconButton(
                    onPressed: () => _fetchWorkers(page: 1),
                    icon: const Icon(Icons.refresh, size: 20),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),

              // BOOKINGS
              _section(
                "Bookings",
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey[300]!),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: DropdownButton<String>(
                            value: statusFilter,
                            hint: const Text("Status", style: TextStyle(fontSize: 14)),
                            underline: const SizedBox(),
                            items: const ["pending", "completed"]
                                .map((e) => DropdownMenuItem(value: e, child: Text(e, style: TextStyle(fontSize: 14))))
                                .toList(),
                            onChanged: (v) {
                              setState(() => statusFilter = v);
                              _fetchBookings(page: 1);
                            },
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey[300]!),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: DropdownButton<String>(
                            value: bookingsSortBy,
                            underline: const SizedBox(),
                            items: const ["date", "title", "status"]
                                .map((e) => DropdownMenuItem(value: e, child: Text("Sort: $e", style: TextStyle(fontSize: 14))))
                                .toList(),
                            onChanged: (v) {
                              setState(() => bookingsSortBy = v ?? "date");
                              _fetchBookings(page: 1);
                            },
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey[300]!),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: DropdownButton<String>(
                            value: bookingsSortDir,
                            underline: const SizedBox(),
                            items: const ["asc", "desc"]
                                .map((e) => DropdownMenuItem(value: e, child: Text(e.toUpperCase(), style: TextStyle(fontSize: 14))))
                                .toList(),
                            onChanged: (v) {
                              setState(() => bookingsSortDir = v ?? "desc");
                              _fetchBookings(page: 1);
                            },
                          ),
                        ),
                        SizedBox(
                          width: 200,
                          child: TextField(
                            controller: bookingSearch,
                            decoration: InputDecoration(
                              hintText: "Search booking",
                              isDense: true,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                              prefixIcon: const Icon(Icons.search, size: 20),
                            ),
                            onChanged: (_) {
                              debBookings?.cancel();
                              debBookings = Timer(const Duration(milliseconds: 300),
                                  () => _fetchBookings(page: 1));
                            },
                          ),
                        ),
                        TextButton.icon(
                          onPressed: () {
                            setState(() {
                              bookingSearch.clear();
                              statusFilter = null;
                              bookingsSortBy = "date";
                              bookingsSortDir = "desc";
                            });
                            _fetchBookings(page: 1);
                          },
                          icon: const Icon(Icons.clear, size: 18),
                          label: const Text("Reset", style: TextStyle(fontSize: 14)),
                          style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ...bookings.map((b) => Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          decoration: BoxDecoration(
                            color: Colors.grey[50],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: Colors.purple[50],
                              child: Icon(Icons.calendar_today, color: Colors.purple[700], size: 20),
                            ),
                            title: Text(b['job_title'] ?? '—', style: const TextStyle(fontWeight: FontWeight.w500)),
                            subtitle: Text("${b['date']} • ${b['time']}", style: TextStyle(fontSize: 13, color: Colors.grey[600])),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: (b['status'] == "completed")
                                        ? Colors.green[50]
                                        : (b['status'] == "cancelled" ? Colors.red[50] : Colors.blue[50]),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    (b['status'] ?? "pending").toUpperCase(),
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: (b['status'] == "completed")
                                          ? Colors.green[800]
                                          : (b['status'] == "cancelled" ? Colors.red[800] : Colors.blue[800]),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 4),
                                IconButton(
                                  tooltip: "Edit Booking",
                                  icon: const Icon(Icons.edit_outlined, size: 18),
                                  onPressed: () => _editBookingDialog(b),
                                  visualDensity: VisualDensity.compact,
                                ),
                              ],
                            ),
                          ),
                        )),
                    _pager(
                      page: bookingsPage,
                      hasNext: bookingsHasNext,
                      isLoading: loadingBookings,
                      onPrev: () => _fetchBookings(page: bookingsPage - 1),
                      onNext: () => _fetchBookings(page: bookingsPage + 1),
                    ),
                    if (!loadingBookings && bookings.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: Text("No bookings found", style: TextStyle(color: Colors.grey[500])),
                      ),
                  ],
                ),
                actions: [
                  IconButton(
                    onPressed: () => _fetchBookings(page: 1),
                    icon: const Icon(Icons.refresh, size: 20),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}