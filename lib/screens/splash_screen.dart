import 'package:flutter/material.dart';
import 'package:healthlab/constants.dart';
import '../services/auth_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  SplashScreenState createState() => SplashScreenState();
}

class SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _logoAnimation;
  late Animation<double> _textAnimation;
  final AuthService _authService = AuthService();

  @override
  void initState() {
    super.initState();
    // Animation Controller for smooth transitions
    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );

    // Define the logo and text animation
    _logoAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeIn),
    );

    _textAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    // Start the animation
    _controller.forward();

    // Check for stored credentials after animations
    _checkLoginStatus();
  }

  Future<void> _checkLoginStatus() async {
    // Wait for animations to complete
    await Future.delayed(const Duration(seconds: 2));

    // Check if user should stay logged in with role awareness
    final loginResult = await _authService.autoLogin();


    if (loginResult['success']) {
      // Route based on role
      if (loginResult['role'] == 'admin') {
        Navigator.pushReplacementNamed(context, '/admin_dashboard');
      } else if (loginResult['role'] == 'user') {
        // User role
        Navigator.pushReplacementNamed(context, '/home');
      }
      else if (loginResult['role'] == 'doctor') {
        // Doctor role
        Navigator.pushReplacementNamed(context, '/doctor_dashboard');
      }
    } else {
      // If auto login failed, redirect to login screen
      Navigator.pushReplacementNamed(context, '/login');
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    AppConstants.init(context);
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Animated logo
            FadeTransition(
              opacity: _logoAnimation,
              child: Container(
                height: AppConstants.deviceHeight * 0.3,
                width: AppConstants.deviceWidth,
                decoration: BoxDecoration(
                  color: AppColors.lightBlue,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Center(
                  child: Image.asset(
                    'assets/images/logo.png',
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
            SizedBox(height: AppConstants.deviceHeight * 0.05),
            // Animated app name text
            FadeTransition(
              opacity: _textAnimation,
              child: Text(
                'Health App',
                style: TextStyle(
                  fontSize: AppConstants.deviceWidth * 0.08,
                  color: AppColors.teal,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            SizedBox(height: AppConstants.deviceHeight * 0.01),
            // Tagline text
            FadeTransition(
              opacity: _textAnimation,
              child: Text(
                'Take care of your health',
                style: TextStyle(
                  fontSize: AppConstants.deviceWidth * 0.05,
                  color: Colors.grey[600],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}