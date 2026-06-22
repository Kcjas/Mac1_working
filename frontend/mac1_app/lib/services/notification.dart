import 'dart:convert';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import 'auth_manager.dart';

class NotificationService {
  NotificationService._();
  static final NotificationService I = NotificationService._();

  final FirebaseMessaging _fm = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _local = FlutterLocalNotificationsPlugin();

  bool _initialized = false;
  int? _currentUserId;

  Future<void> init({int? currentUserId}) async {
    if (_initialized) return;
    _initialized = true;
    _currentUserId = currentUserId;

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings();
    const init = InitializationSettings(android: androidInit, iOS: iosInit);
    await _local.initialize(
      init,
      onDidReceiveNotificationResponse: (resp) {
        _handleNotificationTap(resp.payload);
      },
    );

    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'mac1_default', 'General',
      description: 'General notifications',
      importance: Importance.high,
    );
    await _local
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    await _fm.requestPermission();

    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    FirebaseMessaging.onMessage.listen((RemoteMessage m) async {
      final title = m.notification?.title ?? 'Notification';
      final body  = m.notification?.body  ?? '';
      final payload = jsonEncode(m.data); 
      await _local.show(
        0,
        title,
        body,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'mac1_default', 'General',
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(),
        ),
        payload: payload,
      );
    });

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage m) {
      _routeFromData(m.data);
    });


    final initial = await _fm.getInitialMessage();
    if (initial != null) {
      _routeFromData(initial.data);
    }
  }

  
  Future<void> registerTokenWithBackend(int userId) async {
    _currentUserId = userId;
    final token = await _fm.getToken();
    if (token == null) return;
    final baseUrl = await ApiConfig.getBaseUrl();
    final url = Uri.parse("$baseUrl/auth/update_token");
    await http.post(
      url,
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"user_id": userId, "fcm_token": token}),
    );

    FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
      final baseUrl = await ApiConfig.getBaseUrl();
      final url = Uri.parse("$baseUrl/auth/update_token");
      await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"user_id": _currentUserId, "fcm_token": newToken}),
      );
    });
  }

  void _routeFromData(Map<String, dynamic> data) {
    final route = data['route'];
    if (route == null) return;

    final navigator = navigatorKey.currentState;
    if (navigator == null) return;

    switch (route) {
      case '/incomingRequests': {
        final workerId = int.tryParse(data['workerId']?.toString() ?? '');
        if (workerId != null) {
          navigator.pushNamed('/incomingRequests', arguments: workerId);
        }
        break;
      }
      case '/acceptedWorkerList': {
        final userId = _currentUserId;
        if (userId != null) {
          navigator.pushNamed('/acceptedWorkers', arguments: {
            'userId': userId,
            'customerLat': 0.0,
            'customerLon': 0.0,
          });
        }
        break;
      }
      case '/pendingJobs': {
        final workerId = int.tryParse(data['workerId']?.toString() ?? '');
        if (workerId != null) {
          navigator.pushNamed('/pendingJobs', arguments: workerId);
        }
        break;
      }
      case '/payslip': {
        final bookingId = int.tryParse(data['bookingId']?.toString() ?? '');
        if (bookingId != null) {
          navigator.pushNamed('/payslip', arguments: bookingId);
        }
        break;
      }
      case '/rate': {
        final customerId = int.tryParse(data['customerId']?.toString() ?? '');
        final workerId   = int.tryParse(data['workerId']?.toString() ?? '');
        final bookingId  = int.tryParse(data['bookingId']?.toString() ?? '');
        if (customerId != null && workerId != null) {
          navigator.pushNamed('/rate', arguments: {
            'customer_id': customerId,
            'worker_id': workerId,
            'booking_id': bookingId ?? 0,
          });
        }
        break;
      }
      case '/completedJobList': {
        final userId = _currentUserId;
        if (userId != null) {
          navigator.pushNamed('/customerCompletedJobs', arguments: userId);
        }
        break;
      }
      case '/workerHome': {
        final workerId = int.tryParse(data['workerId']?.toString() ?? '');
        if (workerId != null) {
          navigator.pushNamed('/workerHome', arguments: workerId);
        }
        break;
      }
      default:
        break;
    }
  }


  void _handleNotificationTap(String? payload) {
    if (payload == null || payload.isEmpty) return;
    try {
      final data = Map<String, dynamic>.from(jsonDecode(payload));
      _routeFromData(data);
    } catch (_) {}
  }
}

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}
