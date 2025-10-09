import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class Loginpage extends StatefulWidget {
  const Loginpage({super.key});

  @override
  State<Loginpage> createState() => _LoginpageState();
}

class _LoginpageState extends State<Loginpage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  Future<void> _handleLogin() async {
    if (_formKey.currentState!.validate()) {
      final email = _emailController.text.trim();
      final password = _passwordController.text.trim();

      final url = Uri.parse("http://10.121.172.237:8000/auth/login");

      try {
        final response = await http.post(
          url,
          headers: {"Content-Type": "application/json"},
          body: jsonEncode({
            "email": email,
            "password": password,
          }),
        );

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final role = data['role'];
          final userId = data['user_id'];

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Login successful!")),
          );

          if (role == 'customer') {
            Navigator.pushReplacementNamed(context, '/customerHome', arguments: userId);
          } else if (role == 'worker') {
            Navigator.pushReplacementNamed(context, '/workerHome', arguments: userId);
          } else if (role == 'admin') {
            Navigator.pushReplacementNamed(context, '/adminDashboard');
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Unknown role. Please contact support.")),
            );
          }
        } else {
          final resData = jsonDecode(response.body);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Error: ${resData["detail"]}")),
          );
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Connection error: $e")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Login")),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(children: [
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(labelText: "Email:"),
                validator: (value) {
                  if (value == null || !value.contains('@')) {
                    return 'Enter a valid email';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _passwordController,
                decoration: const InputDecoration(labelText: "Password"),
                obscureText: true,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return "Enter Password";
                  }
                  return null;
                },
              ),
              const SizedBox(height: 30),
              ElevatedButton(
                onPressed: _handleLogin,
                child: const Text("Login"),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pushNamed(context, '/signup');
                },
                child: const Text("Don't have an account? Sign up here"),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}
