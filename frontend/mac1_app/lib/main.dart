import 'package:flutter/material.dart';
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
void main() async {
  runApp(const MyApp());
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
            // return MaterialPageRoute(builder: (_) => WalletPage(userId: userId));
            return MaterialPageRoute(builder: (_) => Placeholder()); 
          case '/acceptedWorkerList':
            final userId = settings.arguments as int;
            return MaterialPageRoute(
              builder: (_) => AcceptedWorkersFullPage(userId: userId),
            );
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
            final userId = settings.arguments as int;
            return MaterialPageRoute(builder: (_) => ChatScreen(userId: userId));
          case '/adminDashboard':
            return MaterialPageRoute(builder: (_) => AdminDashboard());
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
