import 'dart:io';
import 'package:flutter/material.dart';
import 'package:healthlab/constants.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:crypt/crypt.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as path;

class DoctorSignupScreen extends StatefulWidget {
  const DoctorSignupScreen({super.key});

  @override
  _DoctorSignupScreenState createState() => _DoctorSignupScreenState();
}

class _DoctorSignupScreenState extends State<DoctorSignupScreen> {
  bool _isLoading = false;
  File? _selectedImage;
  String? _imageUrl;
  String _selectedGender = 'Male';
  final List<String> _genders = ['Male', 'Female', 'Other'];
  bool _termsAccepted = false;

  final TextEditingController nameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController confirmPasswordController = TextEditingController();
  final TextEditingController specializationController = TextEditingController();
  final TextEditingController areaController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController hospitalController = TextEditingController();
  final TextEditingController ageController = TextEditingController();
  final TextEditingController experienceController = TextEditingController();
  final TextEditingController consultationFeeController = TextEditingController();

  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);

    if (image != null) {
      setState(() {
        _selectedImage = File(image.path);
      });
    }
  }

  Future<String?> _uploadImage() async {
    if (_selectedImage == null) return null;

    try {
      final fileName = '${DateTime.now().millisecondsSinceEpoch}_${path.basename(_selectedImage!.path)}';
      await Supabase.instance.client.storage
          .from('doctors')
          .upload(fileName, _selectedImage!);

      final String imageUrl = Supabase.instance.client.storage
          .from('doctors')
          .getPublicUrl(fileName);

      return imageUrl;
    } catch (e) {
      print('Error uploading image: $e');
      return null;
    }
  }

  void _showTermsAndConditions() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text(
                'Terms and Conditions',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppColors.teal,
                ),
              ),
              content: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Doctor Registration Agreement',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'By registering as a doctor on our platform, you agree to the following terms and conditions:',
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      '1. You confirm that all information provided is accurate and complete.\n\n'
                          '2. You understand that your registration is subject to verification and approval by our administrative staff.\n\n'
                          '3. You agree to maintain patient confidentiality and adhere to medical ethics.\n\n'
                          '4. You will provide timely responses to patient inquiries and appointment requests.\n\n'
                          '5. You acknowledge that the platform may collect a service fee from your consultation charges.\n\n'
                          '6. You will keep your availability calendar updated to ensure accurate scheduling.\n\n'
                          '7. You agree to comply with all applicable laws and regulations regarding telemedicine and medical practice.\n\n'
                          '8. You understand that false information or violation of these terms may result in termination of your account.\n\n'
                          '9. You consent to the use of your profile information for displaying on our platform.\n\n'
                          '10. You agree to our privacy policy and data handling practices.\n\n'
                          '11. 10% of  your consultation fee will be deducted by us.',
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Checkbox(
                          value: _termsAccepted,
                          activeColor: AppColors.teal,
                          onChanged: (bool? value) {
                            setState(() {
                              _termsAccepted = value ?? false;
                            });
                          },
                        ),
                        const Expanded(
                          child: Text(
                            'I have read and agree to the terms and conditions',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: const Text(
                    'Cancel',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
                ElevatedButton(
                  onPressed: _termsAccepted
                      ? () {
                    Navigator.of(context).pop();
                    setState(() {
                      // This updates the parent state
                      this._termsAccepted = true;
                    });
                  }
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.teal,
                    disabledBackgroundColor: Colors.grey.shade300,
                  ),
                  child: const Text(
                    'Accept',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _handleDoctorSignup(BuildContext context) async {
    if (_isLoading) return;

    if (!_termsAccepted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please accept the terms and conditions')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Validation checks
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
          confirmPasswordController.text.isEmpty ||
          specializationController.text.isEmpty ||
          areaController.text.isEmpty ||
          phoneController.text.isEmpty ||
          hospitalController.text.isEmpty ||
          ageController.text.isEmpty ||
          experienceController.text.isEmpty ||
          consultationFeeController.text.isEmpty) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('All fields are required')));
        return;
      }

      if (_selectedImage == null) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Please select a profile photo')));
        return;
      }
// Check if email already exists
      PostgrestList response = await Supabase.instance.client
          .from('users')
          .select("id") // Also select 'id'
          .eq("email", emailController.text);

      if (response.isNotEmpty) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Email already exists')));
        return;
      }

// Upload image
      final imageUrl = await _uploadImage();
      if (imageUrl == null) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Failed to upload image')));
        return;
      }

// Hash password
      final hashedPassword = Crypt.sha256(passwordController.text).toString();

// Insert new user
      final userResponse = await Supabase.instance.client
          .from('users')
          .insert({
        'name': nameController.text,
        'email': emailController.text,
        'password': hashedPassword,
        'role': 'doctor',
      })
          .select('id') // Get the inserted user's id
          .single(); // Ensure we get a single result

// Extract user ID
      if (userResponse == null) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Failed to create user')));
        return;
      }
      final userId = userResponse['id']; // Get the user's ID

// Insert into doctors table with user_id
      await Supabase.instance.client.from('doctors').insert({
        'user_id': userId, // Add user_id here
        'photo': imageUrl,
        'specialization': specializationController.text,
        'area': areaController.text,
        'phone': phoneController.text,
        'hospital': hospitalController.text,
        'age': int.parse(ageController.text),
        'gender': _selectedGender,
        'experience': int.parse(experienceController.text),
        'fees': double.parse(consultationFeeController.text),
        'status': 'pending',
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Doctor account created successfully!')),
      );

      // Show success dialog
      _showRegistrationPendingDialog();
    } catch (e) {
      print('Error creating doctor account: $e');
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Error Creating Doctor Account')));
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showRegistrationPendingDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text(
            'Registration Submitted',
            style: TextStyle(
              color: AppColors.teal,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: AppColors.lightBlue.withOpacity(0.3),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.pending_actions,
                  size: 40,
                  color: AppColors.teal,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Your doctor registration has been submitted successfully.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              const Text(
                'Your application is now pending approval by our administrative team. This process typically takes 1-3 business days.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'You will receive an email notification once your account has been approved.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close the dialog
                Navigator.pushNamedAndRemoveUntil(
                  context,
                  '/login',
                      (route) => false,
                ); // Go to login page
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.teal,
                minimumSize: const Size(double.infinity, 45),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Return to Login',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );
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

                      SizedBox(height: AppConstants.deviceHeight * 0.034),

                      // Centered Title
                      const Align(
                        alignment: Alignment.center,
                        child: Text(
                          'Register as Doctor',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: AppColors.teal,
                          ),
                        ),
                      ),

                      SizedBox(height: AppConstants.deviceHeight * 0.034),

                      // Profile Image Selection
                      Center(
                        child: GestureDetector(
                          onTap: _pickImage,
                          child: Container(
                            width: 120,
                            height: 120,
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8F9FE),
                              borderRadius: BorderRadius.circular(60),
                              border: Border.all(color: AppColors.teal, width: 2),
                            ),
                            child: _selectedImage != null
                                ? ClipRRect(
                              borderRadius: BorderRadius.circular(60),
                              child: Image.file(
                                _selectedImage!,
                                fit: BoxFit.cover,
                              ),
                            )
                                : const Center(
                              child: Icon(
                                Icons.add_a_photo,
                                size: 40,
                                color: AppColors.teal,
                              ),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 10),
                      const Center(
                        child: Text(
                          "Add Profile Photo",
                          style: TextStyle(
                            color: AppColors.teal,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),

                      SizedBox(height: AppConstants.deviceHeight * 0.019),

                      // Name Input
                      TextField(
                        controller: nameController,
                        decoration: InputDecoration(
                          hintText: 'Full Name',
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

                      // Specialization Input
                      TextField(
                        controller: phoneController,
                        decoration: InputDecoration(
                          hintText: 'Phone Number',
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

                      // Specialization Input
                      TextField(
                        controller: specializationController,
                        decoration: InputDecoration(
                          hintText: 'Specialization',
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

                      // Area Input
                      TextField(
                        controller: areaController,
                        decoration: InputDecoration(
                          hintText: 'Area',
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

                      // Hospital Input
                      TextField(
                        controller: hospitalController,
                        decoration: InputDecoration(
                          hintText: 'Hospital',
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

                      // Age and Gender in a row
                      Row(
                        children: [
                          // Age Input
                          Expanded(
                            child: TextField(
                              controller: ageController,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                hintText: 'Age',
                                filled: true,
                                fillColor: const Color(0xFFF8F9FE),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide.none,
                                ),
                                contentPadding: const EdgeInsets.all(16),
                              ),
                            ),
                          ),

                          SizedBox(width: AppConstants.deviceWidth * 0.03),

                          // Gender Dropdown
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8F9FE),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: _selectedGender,
                                  hint: const Text('Gender'),
                                  isExpanded: true,
                                  items: _genders.map((String value) {
                                    return DropdownMenuItem<String>(
                                      value: value,
                                      child: Text(value),
                                    );
                                  }).toList(),
                                  onChanged: (newValue) {
                                    setState(() {
                                      _selectedGender = newValue!;
                                    });
                                  },
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),

                      SizedBox(height: AppConstants.deviceHeight * 0.019),

                      // Experience and Consultation Fee in a row
                      Row(
                        children: [
                          // Experience Input
                          Expanded(
                            child: TextField(
                              controller: experienceController,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                hintText: 'Years of Experience',
                                filled: true,
                                fillColor: const Color(0xFFF8F9FE),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide.none,
                                ),
                                contentPadding: const EdgeInsets.all(16),
                              ),
                            ),
                          ),

                          SizedBox(width: AppConstants.deviceWidth * 0.03),

                          // Consultation Fee Input
                          Expanded(
                            child: TextField(
                              controller: consultationFeeController,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                hintText: 'Consultation Fee',
                                filled: true,
                                fillColor: const Color(0xFFF8F9FE),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide.none,
                                ),
                                contentPadding: const EdgeInsets.all(16),
                                prefixText: 'Rs. ',
                              ),
                            ),
                          ),
                        ],
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
                        obscureText: !_isConfirmPasswordVisible,
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
                              _isConfirmPasswordVisible
                                  ? Icons.visibility
                                  : Icons.visibility_off,
                            ),
                            onPressed: () {
                              setState(() {
                                _isConfirmPasswordVisible = !_isConfirmPasswordVisible;
                              });
                            },
                          ),
                        ),
                      ),

                      SizedBox(height: AppConstants.deviceHeight * 0.025),

                      // Terms and Conditions Button
                      GestureDetector(
                        onTap: _showTermsAndConditions,
                        child: Row(
                          children: [
                            Checkbox(
                              value: _termsAccepted,
                              activeColor: AppColors.teal,
                              onChanged: (bool? value) {
                                setState(() {
                                  _termsAccepted = value ?? false;
                                });
                              },
                            ),
                            Expanded(
                              child: Text.rich(
                                TextSpan(
                                  children: [
                                    const TextSpan(
                                      text: 'I agree to the ',
                                    ),
                                    TextSpan(
                                      text: 'Terms and Conditions',
                                      style: TextStyle(
                                        color: AppColors.teal,
                                        fontWeight: FontWeight.bold,
                                        decoration: TextDecoration.underline,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      SizedBox(height: AppConstants.deviceHeight * 0.025),

                      // Signup Button
                      SizedBox(
                        width: AppConstants.deviceWidth * 0.9,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : () => _handleDoctorSignup(context),
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
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                              : const Text(
                            'Register as Doctor',
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
                          Navigator.pushNamed(context, '/signup');
                        },
                        child: const Text(
                          'Register as Patient',
                          style: TextStyle(
                            color: Colors.black87,
                          ),
                        ),
                      ),
                      SizedBox(height: MediaQuery.of(context).viewInsets.bottom),
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