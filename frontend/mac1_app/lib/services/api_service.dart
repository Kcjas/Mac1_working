import 'dart:convert';
import 'package:http/http.dart' as http;
import 'auth_http.dart';
import '../models/WorkerProfile.dart';
import '../models/CustomerProfile.dart';
import '../models/acceptedworker.dart';
import '../config/api_config.dart';

class ApiService {
  /// Get the base URL (async to support SharedPreferences)
  static Future<String> get baseUrl async => await ApiConfig.getBaseUrl();
  
  static Future<Workerprofile> fetchWorkerdata(int userId) async{
     final url = await baseUrl;
     final response = await AuthHttp.get(Uri.parse("$url/worker_profile/$userId"));

    if(response.statusCode == 200){
      final data = json.decode(response.body);
      return Workerprofile.fromJson(data);
    }else{
      throw Exception('failed to load worker profile');
    }
  }

  static Future<double> fetchWorkerRating(int userId) async{
      final url = await baseUrl;
      final response = await AuthHttp.get(Uri.parse("$url/worker_rating/$userId"));

      if(response.statusCode == 200){
        final data = json.decode(response.body);
        final rating = data['average_rating'];
        return (rating ?? 0).toDouble();
      }else{
        throw Exception("Failed to load worker rating");
      }
  }

  static Future<List<Map<String, dynamic>>> fetchLeaderboard() async {
    final url = await baseUrl;
    final response = await AuthHttp.get(Uri.parse("$url/worker/leaderboard"));
    if (response.statusCode == 200) {
      return List<Map<String, dynamic>>.from(jsonDecode(response.body));
      } else {
        throw Exception('Failed to load leaderboard');
      }
  }

  static Future<Customerprofile> fetchCustomerProfile(int userId) async {
    final url = await baseUrl;
    final response = await AuthHttp.get(Uri.parse("$url/customer/profile/$userId"));
  
    if (response.statusCode == 200) {
      return Customerprofile.fromJson(json.decode(response.body));
    } else {
      throw Exception("Failed to load customer profile");
    }
  }



  Future<List<AcceptedWorker>> fetchAcceptedWorkers(int userId) async {
    final url = await ApiConfig.getBaseUrl();
    final uri = Uri.parse('$url/customer/$userId/accepted-workers');
    final response = await AuthHttp.get(uri);

    if (response.statusCode == 200) {
      final List data = json.decode(response.body);
      return data.map((e) => AcceptedWorker.fromJson(e)).toList();
    } else {
      throw Exception('Failed to load accepted workers');
    }
  }

  static Future<Map<String, dynamic>> createBooking({
    required int customerId,
    required int workerId,
    required String jobTitle,
    required String address,
    required String date,
    required String time,
  }) async {
    final url = await baseUrl;
    final response = await AuthHttp.post(
      Uri.parse('$url/book'), 
      headers: {'Content-Type': 'application/json'},
    body: jsonEncode({
      "customer_id": customerId,
      "worker_id": workerId,
      "job_title": jobTitle,
      "address": address,
      "date": date,
      "time": time,
    }),
  );

  if (response.statusCode == 200) {
    return {"success": true};
  } else {
    return {"success": false, "error": response.body};
  }
}


  static Future<List<Map<String, dynamic>>> fetchCustomerUpcomingJobs(int userId) async {
    final url = await baseUrl;
    final response = await AuthHttp.get(Uri.parse("$url/customer/$userId/upcoming-jobs"));

    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      return data.cast<Map<String, dynamic>>();
    } else {
      throw Exception("Failed to load upcoming bookings");
    }
  }

  static Future<List<Map<String, dynamic>>> fetchWorkerCompletedJobs(int userId) async {
    final url = await baseUrl;
    final response = await AuthHttp.get(Uri.parse("$url/worker/$userId/completed-jobs"));

    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      return data.cast<Map<String, dynamic>>();
    } else {
      throw Exception("Failed to load completed bookings");
    }
  }

  // ----- PIN-verified completion flow -----

  /// Extracts the backend's `detail` message from an error response, falling
  /// back to a generic message so the UI always has something to show.
  static String _detail(http.Response res, String fallback) {
    try {
      final body = json.decode(res.body);
      if (body is Map && body['detail'] != null) return body['detail'].toString();
    } catch (_) {}
    return fallback;
  }

  /// Worker enters the customer's start PIN. Returns the response body (incl.
  /// `started_at`) on success; throws with the backend detail on failure.
  static Future<Map<String, dynamic>> startJob(int bookingId, String pin) async {
    final url = await baseUrl;
    final res = await AuthHttp.post(
      Uri.parse("$url/booking/$bookingId/start"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"pin": pin}),
    );
    if (res.statusCode == 200) return json.decode(res.body) as Map<String, dynamic>;
    throw Exception(_detail(res, "Could not start the job"));
  }

  /// Worker enters the customer's completion PIN to stop the timer. Returns the
  /// response body (incl. measured `time_taken`) on success.
  static Future<Map<String, dynamic>> completeJob(int bookingId, String pin) async {
    final url = await baseUrl;
    final res = await AuthHttp.post(
      Uri.parse("$url/booking/$bookingId/complete"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"pin": pin}),
    );
    if (res.statusCode == 200) return json.decode(res.body) as Map<String, dynamic>;
    throw Exception(_detail(res, "Could not complete the job"));
  }

  /// Worker submits the itemized additional costs (each `{reason, cost}`).
  static Future<Map<String, dynamic>> finalizeJob(
      int bookingId, List<Map<String, dynamic>> extras) async {
    final url = await baseUrl;
    final res = await AuthHttp.post(
      Uri.parse("$url/booking/$bookingId/finalize"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"extras": extras}),
    );
    if (res.statusCode == 200) return json.decode(res.body) as Map<String, dynamic>;
    throw Exception(_detail(res, "Could not submit the bill"));
  }

  /// Customer approves the final bill, completing the booking.
  static Future<Map<String, dynamic>> confirmBooking(int bookingId) async {
    final url = await baseUrl;
    final res = await AuthHttp.post(Uri.parse("$url/booking/$bookingId/confirm"));
    if (res.statusCode == 200) return json.decode(res.body) as Map<String, dynamic>;
    throw Exception(_detail(res, "Could not confirm the booking"));
  }

  /// Booking summary/payslip — also carries `status` and parsed `extras`, so the
  /// customer's waiting screen can poll it.
  static Future<Map<String, dynamic>> fetchBookingSummary(int bookingId) async {
    final url = await baseUrl;
    final res = await AuthHttp.get(Uri.parse("$url/booking/$bookingId/summary"));
    if (res.statusCode == 200) return json.decode(res.body) as Map<String, dynamic>;
    throw Exception(_detail(res, "Could not load the booking summary"));
  }
}

