import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'firebase_options.dart';

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
import 'Pages/chat_thread.dart';
import 'Pages/chats_list.dart';
import 'Pages/admin_dashboard.dart';
import 'Pages/jobrequest.dart';
import 'Pages/wallet.dart';
import 'Pages/CustomerUpcomingBookingsPage.dart';
import 'Pages/WorkerCompletedBookingsPage.dart';
import 'Pages/settings_page.dart';
import 'services/auth_manager.dart';

final FlutterLocalNotificationsPlugin _local = FlutterLocalNotificationsPlugin();

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  // Optional: handle background message
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
      .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);

  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  await _initFcm();

  // Restore any persisted session (validates the stored JWT against the backend)
  // before the first frame so AuthGate can route to the right screen.
  await AuthManager.instance.init();

  runApp(const MyApp());
}

Future<void> _initFcm() async {
  final fm = FirebaseMessaging.instance;
  await fm.requestPermission(alert: true, badge: true, sound: true);

  FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
    final notification = message.notification;
    if (notification != null) {
      await _local.show(
        notification.hashCode,
        notification.title,
        notification.body,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'mac1_default',
            'General',
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(),
        ),
      );
    }
  });
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      navigatorKey: navigatorKey,
      title: 'MAC1',
      theme: ThemeData(
        primaryColor: const Color(0xFFFF4D00),
        scaffoldBackgroundColor: Colors.white,
        colorScheme: ColorScheme.fromSwatch().copyWith(
          primary: const Color(0xFFFF4D00),
          secondary: const Color(0xFF1A1A1A),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 0,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFFF4D00),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          ),
        ),
        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.grey.shade200),
          ),
        ),
      ),
      initialRoute: '/',
      onGenerateRoute: (settings) {
        final args = settings.arguments;

        // Route guard: every screen except the entry gate and signup requires
        // an authenticated session. Blocks stale deep-links / FCM taps from
        // opening a protected screen after the token is gone.
        const openRoutes = {'/', '/signup'};
        if (!openRoutes.contains(settings.name) &&
            !AuthManager.instance.isLoggedIn) {
          return MaterialPageRoute(builder: (_) => const AuthGate());
        }

        switch (settings.name) {
          case '/':
            return MaterialPageRoute(builder: (_) => const AuthGate());

          case '/signup':
            return MaterialPageRoute(builder: (_) => const Signuppage());

          case '/customerHome':
            if (args is int) {
              return MaterialPageRoute(builder: (_) => Customerhp(userId: args));
            }
            return _errorRoute("Invalid args for /customerHome");

          case '/workerHome':
            if (args is int) {
              return MaterialPageRoute(builder: (_) => Workershp(userId: args));
            }
            return _errorRoute("Invalid args for /workerHome");

          case '/settings':
            return MaterialPageRoute(builder: (_) => const SettingsPage());

          case '/adminDashboard':
            return MaterialPageRoute(builder: (_) => const AdminDashboard());

          case '/upcomingJobs':
            if (args is int) {
              return MaterialPageRoute(builder: (_) => CustomerUpcomingBookingsPage(userId: args));
            }
            return _errorRoute("Invalid args for /upcomingJobs");

          case '/workerCompletedJobList':
            if (args is int) {
              return MaterialPageRoute(builder: (_) => WorkerCompletedBookingsPage(userId: args));
            }
            return _errorRoute("Invalid args for /workerCompletedJobList");

          case '/workerInfo':
            if (args is int) {
              return MaterialPageRoute(builder: (_) => WorkerInfoPage(userId: args));
            }
            return _errorRoute("Invalid args for /workerInfo");

          case '/incomingRequests':
            if (args is int) {
              return MaterialPageRoute(builder: (_) => IncomingRequestsPage(workerId: args));
            }
            return _errorRoute("Invalid args for /incomingRequests");

          case '/wallet':
            if (args is int) {
              return MaterialPageRoute(builder: (_) => WalletPage(workerId: args));
            }
            return _errorRoute("Invalid args for /wallet");

          case '/service_workers':
            if (args is Map<String, dynamic>) {
              return MaterialPageRoute(
                builder: (_) => ServiceWorkersPage(
                  skill: args['skill'] ?? '',
                  customerLat: (args['customerLat'] as num?)?.toDouble() ?? 0.0,
                  customerLon: (args['customerLon'] as num?)?.toDouble() ?? 0.0,
                  customerId: args['customerId'] ?? 0,
                  customerAddress: args['customerAddress'] ?? '',
                ),
              );
            }
            return _errorRoute("Invalid args for /service_workers");

          case '/chatbot':
            if (args is Map<String, dynamic>) {
              return MaterialPageRoute(
                builder: (_) => ChatScreen(
                  userId: args['userId'],
                  userLat: (args['customerLat'] as num?)?.toDouble(),
                  userLon: (args['customerLon'] as num?)?.toDouble(),
                  userAddress: args['customerAddress'],
                ),
              );
            }
            return MaterialPageRoute(builder: (_) => const ChatScreen());

          case '/chats':
            if (args is int) {
              return MaterialPageRoute(builder: (_) => ChatsListPage(userId: args));
            }
            return _errorRoute("Invalid args for /chats");

          case '/chat':
            if (args is Map<String, dynamic>) {
              return MaterialPageRoute(
                builder: (_) => ChatThreadPage(
                  bookingId: (args['bookingId'] as num).toInt(),
                  otherName: args['otherName'] ?? 'Chat',
                  chatOpen: args['chatOpen'] ?? true,
                ),
              );
            }
            return _errorRoute("Invalid args for /chat");

          case '/pendingJobs':
            if (args is int) {
              return MaterialPageRoute(builder: (_) => PendingJobsPage(userId: args));
            }
            return _errorRoute("Invalid args for /pendingJobs");

          case '/job-request':
            if (args is Map<String, dynamic>) {
              return MaterialPageRoute(
                builder: (_) => JobRequestPage(
                  customerId: args['customerId'] ?? 0,
                  workerId: args['workerId'] ?? 0,
                  workerName: args['workerName'] ?? '',
                  workerSkill: args['workerSkill'] ?? '',
                  hourlyRate: (args['hourlyRate'] as num?)?.toDouble() ?? 0.0,
                  distance: (args['distance'] as num?)?.toDouble() ?? 0.0,
                  customerLat: (args['customerLat'] as num?)?.toDouble() ?? 0.0,
                  customerLon: (args['customerLon'] as num?)?.toDouble() ?? 0.0,
                  customerAddress: args['customerAddress'] ?? '',
                  problem: args['problem'] ?? '',
                ),
              );
            }
            return _errorRoute("Invalid args for /job-request");

          case '/book':
            if (args is Map<String, dynamic>) {
              return MaterialPageRoute(
                builder: (_) => BookingPage(
                  customerId: args['customerId'] ?? 0,
                  workerId: args['workerId'] ?? 0,
                  workerName: args['workerName'] ?? '',
                  skill: args['skill'] ?? '',
                  hourlyRate: (args['hourlyRate'] as num?)?.toDouble() ?? 0.0,
                  rating: (args['rating'] as num?)?.toDouble() ?? 0.0,
                  customerLat: (args['customerLat'] as num?)?.toDouble() ?? 0.0,
                  customerLon: (args['customerLon'] as num?)?.toDouble() ?? 0.0,
                  customerAddress: args['customerAddress'] as String?,
                  date: args['date'] ?? '',
                  time: args['time'] ?? '',
                ),
              );
            }
            return _errorRoute("Invalid args for /book");

          case '/completedJobs':
            if (args is Map<String, dynamic>) {
              return MaterialPageRoute(
                builder: (_) => CompletedJobPage(
                  booking_id: args['booking_id'] ?? 0,
                  userId: args['userId'] ?? 0,
                ),
              );
            }
            return _errorRoute("Invalid args for /completedJobs");

          case '/customerCompletedJobs':
            if (args is int) {
              return MaterialPageRoute(builder: (_) => Customercompletedjobs(userId: args));
            }
            return _errorRoute("Invalid args for /customerCompletedJobs");

          case '/payslip':
            if (args is int) {
              return MaterialPageRoute(builder: (_) => Finalpayslip(booking_id: args));
            }
            return _errorRoute("Invalid args for /payslip");

          case '/rate':
            if (args is Map<String, dynamic>) {
              return MaterialPageRoute(
                builder: (_) => RateWorkerPage(
                  customerId: args['customer_id'] ?? 0,
                  workerId: args['worker_id'] ?? 0,
                  bookingId: args['booking_id'] ?? 0,
                ),
              );
            }
            return _errorRoute("Invalid args for /rate");

          case '/acceptedWorkers':
            if (args is Map<String, dynamic>) {
              return MaterialPageRoute(
                builder: (_) => AcceptedWorkersFull(
                  userId: args['userId'] ?? 0,
                  customerLat: (args['customerLat'] as num?)?.toDouble() ?? 0.0,
                  customerLon: (args['customerLon'] as num?)?.toDouble() ?? 0.0,
                ),
              );
            }
            return _errorRoute("Invalid args for /acceptedWorkers");

          default:
            return _errorRoute("Route not found: ${settings.name}");
        }
      },
      routes: const {}, // We are using onGenerateRoute, so this can be empty
    );
  }

  MaterialPageRoute _errorRoute(String message) {
    return MaterialPageRoute(
      builder: (_) => Scaffold(
        appBar: AppBar(title: const Text("Error")),
        body: Center(child: Text(message)),
      ),
    );
  }
}

/// Decides the first screen based on the restored session: login when logged
/// out, otherwise the role-appropriate home. Used for '/' and as the fallback
/// when the route guard rejects a protected route.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = AuthManager.instance;
    if (!auth.isLoggedIn) return const Loginpage();

    switch (auth.role) {
      case 'customer':
        return Customerhp(userId: auth.userId!);
      case 'worker':
        return Workershp(userId: auth.userId!);
      case 'admin':
        return const AdminDashboard();
      default:
        return const Loginpage();
    }
  }
}
