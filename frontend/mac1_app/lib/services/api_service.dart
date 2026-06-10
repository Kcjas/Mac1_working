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

}

