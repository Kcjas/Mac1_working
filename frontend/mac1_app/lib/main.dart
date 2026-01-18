import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'Pages/Loginpage.dart';
import 'Pages/Signuppage.dart';
import 'Pages/WorkerInfoPage.dart';
import 'Pages/WorkersHP.dart';
import 'Pages/pendingJobs.dart';
import 'Pages/incoming_request.dart';
import 'Pages/accepted_workers_full.dart';
import 'Pages/booking.dart';
import 'Pages/service_workers.dart';
import 'Pages/customerhomepage.dart';
import 'Pages/Completed_jobs_page.dart';
import 'Pages/customercompletedjobs.dart';
import 'Pages/finalPaySlip.dart';
import 'Pages/Rating.dart';
import 'Pages/chatbot.dart';
import 'Pages/admin_dashboard.dart';
import 'Pages/jobrequest.dart';
import 'Pages/wallet.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';


import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

const String BASE_URL = "http://192.168.1.12:8000";

final FlutterLocalNotificationsPlugin _local = FlutterLocalNotificationsPlugin();

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  final notification = message.notification;
  if (notification != null) {await _local.show(
    0,
    notification.title,
    notification.body,
    const NotificationDetails(
      android: AndroidNotificationDetails(
        'mac1_default', 'General',
        importance: Importance.high,
        priority: Priority.high,        
      ),
      iOS: DarwinNotificationDetails(),
      ),
    );}
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
  const iosInit = DarwinInitializationSettings();
  const initSettings = InitializationSettings(android: androidInit, iOS: iosInit);
  await _local.initialize(initSettings);

  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'mac1_default',
    'General',
    description: 'General notifications',
    importance: Importance.high,
  );
  await _local
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);

  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  await _initFcm();

  runApp(const MyApp());
}

Future<void> _initFcm() async {
  final fm = FirebaseMessaging.instance;

  await fm.requestPermission(alert: true, badge: true, sound: true);

  final token = await fm.getToken();
  debugPrint("FCM TOKEN => $token");

  FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
    debugPrint("Foreground notification: ${message.notification?.title}");
    final notification = message.notification;
    if (notification != null) {
      await _local.show(
        0,
        notification.title,
        notification.body,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'mac1_default', 'General',
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(),
        ),
      );
    }
  });

  FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
    debugPrint("FCM TOKEN REFRESHED => $newToken");
  });
}

Future<void> _registerTokenWithBackend(int userId, String token) async {
  final url = Uri.parse("$BASE_URL/auth/update_token");
  await http.post(
    url,
    headers: {"Content-Type": "application/json"},
    body: jsonEncode({"user_id": userId, "fcm_token": token}),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: "MAC1",
      initialRoute: "/",
      onGenerateRoute: (settings) {
        switch (settings.name) {
          case '/':
            return MaterialPageRoute(builder: (_) => Loginpage());

          case '/signup':
            return MaterialPageRoute(builder: (_) => Signuppage());

          case '/customerHome':
            final userId = settings.arguments as int;
            return MaterialPageRoute(builder: (_) => Customerhp(userId: userId));

          case '/workerHome':
            final userId = settings.arguments as int;
            return MaterialPageRoute(builder: (_) => Workershp(userId: userId));

          case '/workerInfo':
            final userId = settings.arguments as int;
            return MaterialPageRoute(builder: (_) => WorkerInfoPage(userId: userId,));

          case '/incomingRequests':
            final workerId = settings.arguments as int;
            return MaterialPageRoute(builder: (_) => IncomingRequestsPage(workerId: workerId));

          case '/pendingJobs':
            final workerId = settings.arguments as int;
            return MaterialPageRoute(builder: (_) => PendingJobsPage(userId: workerId));

          case '/service_workers':
            final args = settings.arguments as Map<String, dynamic>;
            return MaterialPageRoute(
              builder: (_) => ServiceWorkersPage(
                skill:        args['skill'],
                customerLat:  args['customerLat'],
                customerLon:  args['customerLon'],
                customerId:   args['customerId'],
                customerAddress: args['customerAddress'],
              ),
            );

          case '/book':
            final args = settings.arguments as Map<String, dynamic>;
            return MaterialPageRoute(
              builder: (_) => BookingPage(
                customerId : args['customerId']  as int,
                workerId   : args['workerId']    as int,
                workerName : args['workerName']  as String,
                skill      : args['skill']       as String,
                hourlyRate : (args['hourlyRate'] as num).toDouble(),
                rating     : (args['rating']     as num).toDouble(),
                customerLat: (args['customerLat'] as num).toDouble(),
                customerLon: (args['customerLon'] as num).toDouble(),
                date: args['date'],
                time: args['time']
              ),
            );

          case '/wallet':
            final userId = settings.arguments as int;
            return MaterialPageRoute(builder: (_) => WalletPage(workerId: userId));

          case '/acceptedWorkerList':
            final args = settings.arguments as Map<String, dynamic>;
            return MaterialPageRoute(builder: (_) => AcceptedWorkersFull(userId: args['customer_id'],customerLat: args['customer_lat'] , customerLon: args['customer_lon']),);

          case '/completedJobs':
            final args = settings.arguments as Map<String,dynamic>;
            return MaterialPageRoute(builder: (_) => CompletedJobPage(booking_id: args['booking_id'], userId:  args['userId']));

          case '/completedJobList':
            final userId = settings.arguments as int;
            return MaterialPageRoute(builder: (_) => Customercompletedjobs(userId: userId));

          case '/payslip':
            final bookingId = settings.arguments as int;
            return MaterialPageRoute(builder: (_) => Finalpayslip(booking_id: bookingId));

          case '/rate':
            final args = settings.arguments as Map<String, dynamic>;
            return MaterialPageRoute(
              builder: (_) => RateWorkerPage(
                customerId: args['customer_id'] as int,
                workerId: args['worker_id'] as int,
              ),
            );

          case '/chatbot':
            final args = settings.arguments as Map<String, dynamic>;
            return MaterialPageRoute(builder: (_) => ChatScreen(
              userId: args['userId'] as int?,
              userLat: args['customerLat'] as double?,
              userLon: args['customerLon'] as double?,
              userAddress: args['customerAddress'] as String?,
            ));

          case '/adminDashboard':
            return MaterialPageRoute(builder: (_) => AdminDashboard());

          case '/job-request':
            final args = settings.arguments as Map<String, dynamic>;
            return MaterialPageRoute(builder: (_) => JobRequestPage(
              customerId: args['customerId'] as int,
              workerId: args['workerId'] as int,
              workerName: args['workerName'] as String,
              workerSkill: args['workerSkill'] as String,
              hourlyRate: (args['hourlyRate'] as num).toDouble(),
              distance: (args['distance'] as num).toDouble(),
              customerLat: (args['customerLat'] as num).toDouble(),
              customerLon: (args['customerLon'] as num).toDouble(),
              customerAddress: args['customerAddress'] as String,
              problem: args['problem']! as String,
            ));
            
          default:
            return MaterialPageRoute(
              builder: (_) => Scaffold(
                body: Center(child: Text("No route defined for ${settings.name}")),
              ),
            );
        }
      },
    );
  }
}
