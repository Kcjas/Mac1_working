import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../services/notification.dart';
import '../config/api_config.dart';
import '../services/auth_manager.dart';

class Loginpage extends StatefulWidget {
  const Loginpage({super.key});

  @override
  State<Loginpage> createState() => _LoginpageState();
}

class HeroPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white.withOpacity(0.15);
    const tileSize = 50.0;

    for (double x = -tileSize; x < size.width + tileSize; x += tileSize) {
      for (double y = -tileSize; y < size.height + tileSize; y += tileSize) {
        final col = (x / tileSize).floor();
        final row = (y / tileSize).floor();
        final variant = (col + row) % 4;

        if (variant == 0) {
          // quarter circle from top-left corner
          canvas.drawArc(
            Rect.fromLTWH(x, y, tileSize * 2, tileSize * 2),
            0, 1.5708, true, paint,
          );
        } else if (variant == 1) {
          // quarter circle from top-right corner
          canvas.drawArc(
            Rect.fromLTWH(x - tileSize, y, tileSize * 2, tileSize * 2),
            1.5708, 1.5708, true, paint,
          );
        } else if (variant == 2) {
          // quarter circle from bottom-right
          canvas.drawArc(
            Rect.fromLTWH(x - tileSize, y - tileSize, tileSize * 2, tileSize * 2),
            3.1416, 1.5708, true, paint,
          );
        } else {
          // quarter circle from bottom-left
          canvas.drawArc(
            Rect.fromLTWH(x, y - tileSize, tileSize * 2, tileSize * 2),
            4.7124, 1.5708, true, paint,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _LoginpageState extends State<Loginpage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  Future<void> _handleLogin() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);

      final baseUrl = await ApiConfig.getBaseUrl();
      final url = Uri.parse("$baseUrl/auth/login");

      try {
        final response = await http.post(
          url,
          headers: {"Content-Type": "application/json"},
          body: jsonEncode({
            "email": _emailController.text.trim(),
            "password": _passwordController.text.trim(),
          }),
        );

        if (!mounted) return;

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final role = data['role'];
          final userId = data['user_id'];

          // Persist the JWT before any authenticated follow-up calls.
          await AuthManager.instance.login(
            token: data['access_token'],
            userId: userId,
            role: role,
          );

          await NotificationService.I.registerTokenWithBackend(userId);


          if (role == 'customer') {
            Navigator.pushReplacementNamed(context, '/customerHome', arguments: userId);
          } else if (role == 'worker') {
            Navigator.pushReplacementNamed(context, '/workerHome', arguments: userId);
          } else if (role == 'admin') {
            Navigator.pushReplacementNamed(context, '/adminDashboard');
          }
        } else {
          final resData = jsonDecode(response.body);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(resData["detail"] ?? "Login failed")),
          );
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e")),
        );
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(height: 230,
          child: Stack(
            children: [
              CustomPaint(size: Size.infinite, painter: HeroPainter()),
              Center(
                child: Text(
                  "MAC1",
                  style: TextStyle(
                    fontSize: 48,
                    fontWeight: FontWeight.w900,
                    color: Colors.white.withOpacity(0.9),
                  ),
                ),
              ),
            ],
          )
          ),
          //White card
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.only(topLeft: Radius.circular(90)),
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 20),
                      const Text(
                        "Login",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(height: 40),
                      TextFormField(
                        controller: _emailController,
                        enabled: !_isLoading,
                        decoration: InputDecoration(
                          labelText: "Email",
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(20),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(20),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(20),
                            borderSide: const BorderSide(color: Colors.black87, width: 2),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || !value.contains('@')) {
                            return 'Enter a valid email';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _passwordController,
                        enabled: !_isLoading,
                        obscureText: true,
                        decoration: InputDecoration(
                          labelText: "Password",
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(20),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(20),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(20),
                            borderSide: const BorderSide(color: Colors.black87, width: 2),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Enter password';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 28),
                      ElevatedButton(
                        onPressed: _isLoading ? null : _handleLogin,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.black87,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          elevation: 0,
                        ),
                        child: _isLoading
                            ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)))
                            : const Text("Sign In", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(height: 100),
                      Center(
                        child: TextButton(
                          onPressed: _isLoading ? null : () => Navigator.pushNamed(context, '/signup'),
                          child: Text(
                            "Don't have an account? Sign up",
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.grey.shade800),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            )
          )
        ],
      )
      // body: Center(
      //Container(
            //   decoration: BoxDecoration(
            //     color: Colors.white,
            //     borderRadius: const BorderRadius.only(topLeft: Radius.circular(80)),
            //     boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 10)],
            //   ),
            // ),
      //   child: SingleChildScrollView(
      //     padding: const EdgeInsets.all(24),
      //     child: Form(
      //       key: _formKey,
      //       child: Column(
      //         crossAxisAlignment: CrossAxisAlignment.stretch,
      //         children: [
      //           const SizedBox(height: 20),
      //           const Text(
      //             "MAC1",
      //             textAlign: TextAlign.center,
      //             style: TextStyle(
      //               fontSize: 48,
      //               fontWeight: FontWeight.w900,
      //               color: Colors.black,
      //             ),
      //           ),
      //           const SizedBox(height: 40),
      //           TextFormField(
      //             controller: _emailController,
      //             enabled: !_isLoading,
      //             decoration: InputDecoration(
      //               labelText: "Email",
      //               filled: true,
      //               fillColor: Colors.white,
      //               border: OutlineInputBorder(
      //                 borderRadius: BorderRadius.circular(20),
      //                 borderSide: BorderSide(color: Colors.grey.shade300),
      //               ),
      //               enabledBorder: OutlineInputBorder(
      //                 borderRadius: BorderRadius.circular(20),
      //                 borderSide: BorderSide(color: Colors.grey.shade300),
      //               ),
      //               focusedBorder: OutlineInputBorder(
      //                 borderRadius: BorderRadius.circular(20),
      //                 borderSide: const BorderSide(color: Color(0xFFFF4D00), width: 2),
      //               ),
      //             ),
      //             validator: (value) {
      //               if (value == null || !value.contains('@')) {
      //                 return 'Enter a valid email';
      //               }
      //               return null;
      //             },
      //           ),
      //           const SizedBox(height: 16),
      //           TextFormField(
      //             controller: _passwordController,
      //             enabled: !_isLoading,
      //             obscureText: true,
      //             decoration: InputDecoration(
      //               labelText: "Password",
      //               filled: true,
      //               fillColor: Colors.white,
      //               border: OutlineInputBorder(
      //                 borderRadius: BorderRadius.circular(20),
      //                 borderSide: BorderSide(color: Colors.grey.shade300),
      //               ),
      //               enabledBorder: OutlineInputBorder(
      //                 borderRadius: BorderRadius.circular(20),
      //                 borderSide: BorderSide(color: Colors.grey.shade300),
      //               ),
      //               focusedBorder: OutlineInputBorder(
      //                 borderRadius: BorderRadius.circular(20),
      //                 borderSide: const BorderSide(color: Color(0xFFFF4D00), width: 2),
      //               ),
      //             ),
      //             validator: (value) {
      //               if (value == null || value.isEmpty) {
      //                 return 'Enter password';
      //               }
      //               return null;
      //             },
      //           ),
      //           const SizedBox(height: 28),
      //           ElevatedButton(
      //             onPressed: _isLoading ? null : _handleLogin,
      //             style: ElevatedButton.styleFrom(
      //               backgroundColor: const Color(0xFFFF4D00),
      //               foregroundColor: Colors.white,
      //               padding: const EdgeInsets.symmetric(vertical: 18),
      //               shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      //               elevation: 0,
      //             ),
      //             child: _isLoading
      //                 ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)))
      //                 : const Text("Sign In", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      //           ),
      //           const SizedBox(height: 16),
      //           Center(
      //             child: TextButton(
      //               onPressed: _isLoading ? null : () => Navigator.pushNamed(context, '/signup'),
      //               child: Text(
      //                 "Don't have an account? Sign up",
      //                 style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.grey.shade800),
      //               ),
      //             ),
      //           ),
      //         ],
      //       ),
      //     ),
      //   ),
      // ),
    );
  }
}
