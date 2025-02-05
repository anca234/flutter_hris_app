import 'package:flutter/material.dart';
import 'package:secondly/screens/onboarding_screen.dart';
import 'package:secondly/screens/main_screen.dart';
import 'package:secondly/service/auth_service.dart';

void main() async {
  try {
    WidgetsFlutterBinding.ensureInitialized();
    
    // Initialize auth service
    await AuthService.init().catchError((error) {
      print('Auth initialization error: $error');
      // If auth init fails, we'll handle it in the FutureBuilder
    });
    
    runApp(const MyApp());
  } catch (e) {
    print('Startup error: $e');
    // Fallback to basic app initialization if something goes wrong
    runApp(const MaterialApp(home: OnboardingScreen()));
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: FutureBuilder<bool>(
        future: Future(() async {
          try {
            return await AuthService.isLoggedIn();
          } catch (e) {
            print('Login check error: $e');
            // If there's an error checking login state, assume not logged in
            return false;
          }
        }),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(
                child: CircularProgressIndicator(),
              ),
            );
          }

          // If we got an error or not logged in, go to onboarding
          if (snapshot.hasError || snapshot.data != true) {
            return const OnboardingScreen();
          }
          
          // Otherwise go to main screen
          return const MainScreen();
        },
      ),
    );
  }
}