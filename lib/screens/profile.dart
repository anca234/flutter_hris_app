import 'package:flutter/material.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color.fromRGBO(204, 0, 0, 1.0),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 18.0),
            child: Image.asset(
              'assets/logoptap.png',
              width: 50,
            ),
          ),
        ],
      ),
      backgroundColor: const Color.fromARGB(255, 255, 255, 255),
      resizeToAvoidBottomInset: true,
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              const Center(
                child: CircleAvatar(
                  radius: 50,
                  backgroundColor: Colors.grey,
                ),
              ),
              const SizedBox(height: 20),
              const TextField(
                decoration: InputDecoration(labelText: 'Employee Name:'),
              ),
              const TextField(
                decoration: InputDecoration(labelText: 'Job Title:'),
              ),
              const TextField(
                decoration: InputDecoration(labelText: 'Department:'),
              ),
              const TextField(
                decoration: InputDecoration(labelText: 'Employee ID:'),
              ),
              const TextField(
                decoration: InputDecoration(labelText: 'Email:'),
              ),
              const TextField(
                decoration: InputDecoration(labelText: 'Phone:'),
              ),
              const TextField(
                decoration: InputDecoration(labelText: 'Date of Birth:'),
              ),
              const TextField(
                decoration: InputDecoration(labelText: 'Address:'),
              ),
              const SizedBox(height: 20),
              Center(
                child: ElevatedButton(
                  onPressed: () {},
                  child: const Text('Edit Profile'),
                ),
              ),
              const SizedBox(height: 10),
              Center(
                child: TextButton(
                  onPressed: () {},
                  child: const Text(
                    'more detail',
                    style: TextStyle(color: Colors.blue),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
