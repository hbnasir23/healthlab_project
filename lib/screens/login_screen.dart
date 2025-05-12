import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:healthlab/constants.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:crypt/crypt.dart';
import 'package:healthlab/globals.dart';
import '../services/auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _isLoading = false;
  bool _stayLoggedIn = false;
  final AuthService _authService = AuthService();

  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  bool _isPasswordVisible = false;

  @override
  void initState() {
    super.initState();
    _loadSavedCredentials();
  }

  Future<void> _loadSavedCredentials() async {
    final credentials = await _authService.getSavedCredentials();
    if (credentials['email'] != null && credentials['password'] != null) {
      setState(() {
        emailController.text = credentials['email']!;
        passwordController.text = credentials['password']!;
        _stayLoggedIn = credentials['stayLoggedIn'] == 'true';
      });
    }
  }

  Future<void> _updateFcmTokenAndSubscribe(
    String email,
    String role,
    String userId,
  ) async {
    String? fcmToken = await FirebaseMessaging.instance.getToken();
    print('email $email'); // Debugging
    if (fcmToken != null) {
      final res = await Supabase.instance.client
          .from('users')
          .update({'fcm_token': fcmToken})
          .eq('email', email);
      print('res $res'); // Debugging
      // Subscribe to role-specific topic
      await FirebaseMessaging.instance.subscribeToTopic(role);

      // Subscribe to individual topic
      await FirebaseMessaging.instance.subscribeToTopic('${role}_$userId');
    } else {
      print('FCM Token is null');
    }
  }

  Future<void> _handleAdminLogin(Map<String, dynamic> userData) async {
    await _updateFcmTokenAndSubscribe(
      userData['email'],
      'admin',
      userData['id'].toString(),
    );

    await _authService.saveCredentials(
      userData['email'],
      passwordController.text,
      _stayLoggedIn,
      'admin',
    );

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Login Successful')));
    Navigator.pushReplacementNamed(context, '/admin_dashboard');
  }

  Future<void> _handleUserLogin(Map<String, dynamic> userData) async {
    print('Handling User Login for User: ${userData['email']}'); // Debugging
    print('dfgdfgdgsd $loggedInEmail');
    loggedInUsername = userData['name'];
    loggedInEmail = userData['email'];

    await _updateFcmTokenAndSubscribe(
      userData['email'],
      'user',
      userData['id'].toString(),
    );

    await _authService.saveCredentials(
      userData['email'],
      passwordController.text,
      _stayLoggedIn,
      'user',
    );
    print('User Logged In: $loggedInEmail'); // Debugging
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Login Successful')));
    Navigator.pushReplacementNamed(context, '/home');
  }

  Future<void> _handleDoctorLogin(Map<String, dynamic> userData) async {
    print('Handling Doctor Login for User: ${userData['email']}'); // Debugging

    var doctorStatus =
        await Supabase.instance.client
            .from('doctors')
            .select('status')
            .eq('user_id', userData['id'])
            .single();

    if (doctorStatus['status'] == 'approved') {
      loggedInUsername = userData['name'];
      loggedInEmail = userData['email'];

      String? fcmToken = await FirebaseMessaging.instance.getToken();
      print('FCM Token: $fcmToken'); // Debugging

      if (fcmToken != null) {
        try {
          final response = await Supabase.instance.client
              .from('users')
              .update({'fcm_token': fcmToken})
              .eq('email', userData['email']);

          print('helloo'); // Debugging
          print('$userData'); // Debugging
          final responsew = await Supabase.instance.client
              .from('users')
              .select('fcm_token')
              .eq('email', userData['email']);

          print('Database Update Response: $responsew');
          final koko = await Supabase.instance.client
              .from('users')
              .select()
              .eq('email', userData['email']); // Debugging

          print('Database after updating: $koko');
        } catch (e) {
          print('Error updating FCM token: $e'); // Debugging
        }
        //
        // Subscribe to doctor topic
        await FirebaseMessaging.instance.subscribeToTopic('doctor');
        // Subscribe to individual doctor topic
        await FirebaseMessaging.instance.subscribeToTopic(
          'doctor_${userData['id']}',
        );
      }

      await _authService.saveCredentials(
        userData['email'],
        passwordController.text,
        _stayLoggedIn,
        'doctor',
      );

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Login Successful')));
      Navigator.pushReplacementNamed(context, '/doctor_dashboard');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Your account is not approved yet')),
      );
    }
  }

  Future<void> _handleLogin(BuildContext context) async {
    print(' lorrforf $loggedInEmail');
    if (_isLoading) return;
    setState(() {
      _isLoading = true;
    });

    try {
      // Check if the email exists in the users table
      PostgrestList response = await Supabase.instance.client
          .from('users')
          .select("email")
          .eq("email", emailController.text);

      if (response.isEmpty) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('No Such Account Exists')));
        return;
      }

      // Fetch user details
      var res = await Supabase.instance.client
          .from('users')
          .select()
          .eq('email', emailController.text);

      if (res.isNotEmpty) {
        if (res[0]['role'] == 'admin' &&
            res[0]['password'] == passwordController.text) {
          await _handleAdminLogin(res[0]);
        } else if (Crypt(res[0]['password']).match(passwordController.text)) {
          if (res[0]['role'] == 'user') {
            await _handleUserLogin(res[0]);
          } else if (res[0]['role'] == 'doctor') {
            await _handleDoctorLogin(res[0]);
          }
        } else {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Invalid Credentials')));
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        top: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: AppConstants.deviceWidth * 0.05,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(
                        width: AppConstants.deviceWidth * 0.91,
                        height: AppConstants.deviceHeight * 0.25,
                        decoration: BoxDecoration(
                          color: AppColors.lightBlue,
                          borderRadius: const BorderRadius.vertical(
                            bottom: Radius.circular(16),
                          ),
                        ),
                        child: Center(
                          child: Image.asset(
                            'assets/images/logo.png',
                            width: AppConstants.deviceWidth * 0.4,
                            height: AppConstants.deviceHeight * 0.15,
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                      SizedBox(height: AppConstants.deviceHeight * 0.04),
                      const Text(
                        'Login',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: AppColors.teal,
                        ),
                      ),
                      SizedBox(height: AppConstants.deviceHeight * 0.04),
                      TextField(
                        controller: emailController,
                        decoration: InputDecoration(
                          hintText: 'Email',
                          filled: true,
                          fillColor: const Color(0xFFF8F9FE),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.all(16),
                        ),
                      ),
                      SizedBox(height: AppConstants.deviceHeight * 0.02),
                      TextField(
                        controller: passwordController,
                        obscureText: !_isPasswordVisible,
                        decoration: InputDecoration(
                          hintText: 'Password',
                          filled: true,
                          fillColor: const Color(0xFFF8F9FE),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.all(16),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _isPasswordVisible
                                  ? Icons.visibility
                                  : Icons.visibility_off,
                            ),
                            onPressed: () {
                              setState(() {
                                _isPasswordVisible = !_isPasswordVisible;
                              });
                            },
                          ),
                        ),
                      ),
                      SizedBox(height: AppConstants.deviceHeight * 0.01),
                      // Add Stay Logged In checkbox
                      CheckboxListTile(
                        title: const Text('Stay Logged In'),
                        value: _stayLoggedIn,
                        controlAffinity: ListTileControlAffinity.leading,
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        activeColor: AppColors.teal,
                        onChanged: (value) {
                          setState(() {
                            _stayLoggedIn = value ?? false;
                          });
                        },
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () {},
                          child: const Text(
                            'Forgot your password?',
                            style: TextStyle(color: AppColors.teal),
                          ),
                        ),
                      ),
                      SizedBox(height: AppConstants.deviceHeight * 0.02),
                      SizedBox(
                        width: AppConstants.deviceWidth * 0.9,
                        child: ElevatedButton(
                          onPressed:
                              _isLoading ? null : () => _handleLogin(context),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.teal,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child:
                              _isLoading
                                  ? const SizedBox(
                                    height: 24,
                                    width: 24,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  )
                                  : const Text(
                                    'Login',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                        ),
                      ),
                      SizedBox(height: AppConstants.deviceHeight * 0.03),
                      TextButton(
                        onPressed: () {
                          Navigator.pushNamed(context, '/signup');
                        },
                        child: const Text(
                          'Create new account',
                          style: TextStyle(color: Colors.black87),
                        ),
                      ),
                      SizedBox(
                        height: MediaQuery.of(context).viewInsets.bottom,
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
