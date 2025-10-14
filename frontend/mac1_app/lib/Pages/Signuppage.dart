import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class Signuppage extends StatefulWidget{
  const Signuppage({super.key});
  
  @override
  State<Signuppage> createState() => _SignupPageState();
}

class _SignupPageState extends State<Signuppage>{
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _ageController = TextEditingController();
  String _selectedRole = 'customer';
  String _selectedGender = 'M';

  Future<void> _handleSignup() async {
    String name = _nameController.text.trim();
    String email = _emailController.text.trim();
    String password = _passwordController.text.trim();
    String role = _selectedRole;
    String age = _ageController.text.trim();
    String gender = _selectedGender;

    int Age = int.tryParse(age) ?? -1;
    if(Age<0){
      ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Please enter a valid age')),
    );
    return;
    }
    if (!email.contains('@')) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Email must be a @gmail.com address')),
    );
    return;
    }
    if (name.isEmpty || email.isEmpty || password.isEmpty || age.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all fields')),
      );
      return;
    }


    final url = Uri.parse("http://192.168.1.12:8000/auth/signup");

    try{
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "name" : name,
          "age" : age,
          "email" : email,
          "gender": gender,
          "password": password,
          "role": role
          })
      );
      if(response.statusCode==200){
        final resData = jsonDecode(response.body);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('SignUp Succussfull')));
        final userId = resData['user_id'];
        if(role == 'worker'){
          Navigator.pushReplacementNamed(context,'/workerInfo',arguments: userId);
          }else{
            Navigator.pushReplacementNamed(context, '/');
          }
        }else{
          final resData = jsonDecode(response.body);
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: ${resData["detail"]}")));
          
          
        }
    }catch(e){
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("connection error: $e")));
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Signup complete!')),
    );
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Sign Up")),
      body:SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child:Column(
          children:[
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Name',),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(labelText: 'Email',),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _passwordController,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Password',)
              ),
              const SizedBox(height: 10),
            TextField(
              controller: _ageController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Age',)
            ),
            const SizedBox(height:10),
            DropdownButtonFormField(
              value: _selectedGender,
              items: const [
                DropdownMenuItem(value: 'M',child: Text("Male")),
                DropdownMenuItem(value: 'F',child: Text("Female"))
              ],
              onChanged: (value){
                setState(() {
                  _selectedGender = value!;
                });
              }
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField(
              value: _selectedRole,
              items: const [
                DropdownMenuItem(value: 'customer', child: Text("Customer")),
                DropdownMenuItem(value: 'worker', child: Text('Worker')),
              ], 
              onChanged: (value){
                setState((){
                  _selectedRole = value!;
                });
              },
              decoration: const InputDecoration(labelText: "Select Role")
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: _handleSignup,
              child: const Text('Sign Up')
              )
          ]
        )
      )
    );
  }
}