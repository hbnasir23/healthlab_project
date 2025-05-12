import 'package:flutter/material.dart';
import 'package:healthlab/constants.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:crypt/crypt.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  _SignupScreenState createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  bool _isLoading = false;

  final TextEditingController nameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController confirmPasswordController =
      TextEditingController();

  bool _isPasswordVisible = false;
  bool _isconfirmpasswordVisible = false;

  Future<void> _handleSignup(BuildContext context) async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
    });

    try {
      if (passwordController.text != confirmPasswordController.text) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Passwords do not match')));
        return;
      }
      if (!emailController.text.contains('@gmail.com')) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Invalid Email')));
        return;
      }
      if (passwordController.text.length < 6) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Password should be at least 6 characters')));
        return;
      }
      if (nameController.text.isEmpty ||
          emailController.text.isEmpty ||
          passwordController.text.isEmpty ||
          confirmPasswordController.text.isEmpty) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('All fields are required')));
        return;
      }

      final hashedPassword = Crypt.sha256(passwordController.text).toString();
      PostgrestList response = await Supabase.instance.client
          .from('users')
          .select("email")
          .eq("email", emailController.text);

      if (response.isNotEmpty) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Email already exists')));
        return;
      }

      await Supabase.instance.client.from('users').insert({
        'name': nameController.text,
        'email': emailController.text,
        'password': hashedPassword,
        'role': 'user',
      });

      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Account created successfully')));

      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Error Creating Account.')));
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
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior
                  .onDrag,
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Padding(
                  padding: EdgeInsets.symmetric(
                      horizontal: AppConstants.deviceWidth * 0.05),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Logo Container
                      Container(
                        width: AppConstants.deviceWidth,
                        height: AppConstants.deviceHeight * 0.25,
                        decoration: BoxDecoration(
                          color: AppColors.lightBlue,
                          borderRadius: const BorderRadius.vertical(
                              bottom: Radius.circular(16)),
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

                      SizedBox(height: AppConstants.deviceHeight * 0.034
                      ),

                      // Centered Title
                      const Align(
                        alignment: Alignment.center,
                        child: Text(
                          'Create Account',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: AppColors.teal,
                          ),
                        ),
                      ),

                      SizedBox(height: AppConstants.deviceHeight * 0.034),
                      TextField(
                        controller: nameController,
                        decoration: InputDecoration(
                          hintText: 'Name',
                          filled: true,
                          fillColor: const Color(0xFFF8F9FE),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.all(16),
                        ),
                      ),
                      SizedBox(height: AppConstants.deviceHeight * 0.019),

                      // Email Input
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

                      SizedBox(height: AppConstants.deviceHeight * 0.019),

                      // Password Input
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

                      SizedBox(height: AppConstants.deviceHeight * 0.019),

                      // Confirm Password Input
                      TextField(
                        controller: confirmPasswordController,
                        obscureText: !_isconfirmpasswordVisible,
                        decoration: InputDecoration(
                          hintText: 'Confirm Password',
                          filled: true,
                          fillColor: const Color(0xFFF8F9FE),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.all(16),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _isconfirmpasswordVisible
                                  ? Icons.visibility
                                  : Icons.visibility_off,
                            ),
                            onPressed: () {
                              setState(() {
                                _isconfirmpasswordVisible =
                                    !_isconfirmpasswordVisible;
                              });
                            },
                          ),
                        ),
                      ),

                      SizedBox(height: AppConstants.deviceHeight * 0.034),


                      SizedBox(
                        width: AppConstants.deviceWidth * 0.9,
                        child: ElevatedButton(
                          onPressed:
                              _isLoading ? null : () => _handleSignup(context),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.teal,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  height: 24,
                                  width: 24,
                                  child: CircularProgressIndicator(
                                    color: AppColors.teal,
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text(
                                  'Signup',
                                  style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white),
                                ),
                        ),
                      ),

                      SizedBox(height: AppConstants.deviceHeight * 0.015),

                      // Already have an account? Button
                      TextButton(
                        onPressed: () {
                          Navigator.pushNamed(context, '/login');
                        },
                        child: const Text(
                          'Already have an account',
                          style: TextStyle(
                            color: Colors.black87,
                          ),
                        ),
                      ),

                      TextButton(
                        onPressed: () {
                          Navigator.pushNamed(context, '/doctor_signup');
                        },
                        child: const Text(
                          'Register as Doctor',
                          style: TextStyle(
                            color: Colors.black87,
                          ),
                        ),
                      ),
                      SizedBox(
                          height: MediaQuery.of(context).viewInsets.bottom),
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
