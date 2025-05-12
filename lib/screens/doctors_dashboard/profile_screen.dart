import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../../globals.dart';
import 'package:intl/intl.dart';
import '../../constants.dart';

class DoctorProfileScreen extends StatefulWidget {
  const DoctorProfileScreen({super.key});

  @override
  State<DoctorProfileScreen> createState() => _DoctorProfileScreenState();
}

class _DoctorProfileScreenState extends State<DoctorProfileScreen> {
  final supabase = Supabase.instance.client;
  final ImagePicker _picker = ImagePicker();
  Map<String, dynamic>? userData;
  Map<String, dynamic>? doctorData;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _fetchDoctorData();
  }

  Future<void> _fetchDoctorData() async {
    setState(() => _isLoading = true);
    try {
      // Fetch user data based on logged-in email
      final userResponse = await supabase
          .from('users')
          .select('name, email,id')
          .eq('email', loggedInEmail!)
          .maybeSingle();
      print(userResponse);

      // Fetch doctor data using user_id from users table
      final doctorResponse = await supabase
          .from('doctors')
          .select()
          .eq('user_id', userResponse!['id'])
          .maybeSingle();

      setState(() {
        userData = userResponse;
        doctorData = doctorResponse;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error fetching doctor data: $e')),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _updateDoctorData(String field, dynamic value) async {
    setState(() => _isLoading = true);
    try {
      String dbField = field.toLowerCase().replaceAll(' ', '');
      dynamic processedValue = value;

      switch (dbField) {
        case 'experience':
        case 'fees':
          processedValue = int.tryParse(value.toString()) ?? 0;
          break;
      }

      Map<String, dynamic> updateData = {dbField: processedValue};

      final response = await supabase
          .from('doctors')
          .update(updateData)
          .eq('user_id', userData!['id'])
          .select();

      if (response.isNotEmpty) {
        setState(() {
          doctorData = response[0];
          _isLoading = false;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Profile updated successfully')),
          );
        }
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating profile: $e')),
        );
      }
    }
  }

  Future<void> _updateProfilePicture() async {
    setState(() => _isLoading = true);
    try {
      final XFile? pickedFile = await _picker.pickImage(source: ImageSource.gallery);
      if (pickedFile != null) {
        final file = File(pickedFile.path);
        final fileName = 'profile_${DateTime.now().millisecondsSinceEpoch}.png';

        // Upload the image to Supabase storage under the 'doctors' bucket
        await supabase.storage
            .from('doctors')
            .upload(fileName, file, fileOptions: const FileOptions(upsert: true));

        // Get the public URL of the uploaded image
        final imageUrl = supabase.storage
            .from('doctors')
            .getPublicUrl(fileName);

        // Update the doctor's profile picture in the doctors table
        await supabase
            .from('doctors')
            .update({'photo': imageUrl})
            .eq('user_id', userData!['id']);

        // Refresh the doctor data to reflect the new profile picture
        await _fetchDoctorData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating profile picture: $e')),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }
  void _showEditPopup(String field, String currentValue) {
    TextEditingController controller = TextEditingController(text: currentValue);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Edit $field",style: const TextStyle(color: Colors.teal), // Title text in teal
      ),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              foregroundColor: Colors.teal, // AppColors.teal
            ),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _updateDoctorData(field, controller.text.trim());
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.lightBlue,
              elevation: 0,
              foregroundColor: Colors.black,

            ),
            child: const Text("Save",),
          ),
        ],
      ),
    );
  }


  Widget _buildProfileItem(String label, String value, {bool isEditable = true, String? unit}) {
    String displayValue = value;
    if (unit != null && value != "Not set") {
      displayValue = "$value $unit";
    }

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        title: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(displayValue),
        trailing: isEditable
            ? IconButton(
          icon: const Icon(Icons.edit, color: Colors.teal),
          onPressed: () => _showEditPopup(label, value),
        )
            : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (userData == null || doctorData == null || _isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      body: SingleChildScrollView(
        child: Column(
          children: [
            SizedBox(height: AppConstants.deviceHeight * .040),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Doctor Profile',
                    style: TextStyle(
                      fontSize: AppConstants.deviceWidth * 0.06,
                      fontWeight: FontWeight.bold,
                      color: AppColors.teal,
                    ),
                  ),
                  Image.asset(
                    'assets/images/logo.png',
                    height: AppConstants.deviceHeight * 0.08,
                  ),
                ],
              ),
            ),
            SingleChildScrollView(
              padding: const EdgeInsets.all(6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: GestureDetector(
                      onTap: _updateProfilePicture,
                      child: Stack(
                        children: [
                          CircleAvatar(
                            radius: 50,
                            backgroundColor: Colors.teal.shade100,
                            backgroundImage: doctorData!['photo'] != null
                                ? NetworkImage(doctorData!['photo'])
                                : null,
                            child: doctorData!['photo'] == null
                                ? const Icon(Icons.person, size: 50, color: Colors.teal)
                                : null,
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: Colors.teal,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Icon(
                                Icons.edit,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  _buildProfileItem("Name", userData!['name'] ?? "Not set", isEditable: false),
                  _buildProfileItem("Email", userData!['email'] ?? "Not set", isEditable: false),
                  _buildProfileItem("Specialization", doctorData!['specialization'] ?? "Not set"),
                  _buildProfileItem("Experience", doctorData!['experience']?.toString() ?? "Not set", unit: "years"),
                  _buildProfileItem("Consultation Fee", doctorData!['fees']?.toString() ?? "Not set", unit: "PKR"),
                  _buildProfileItem("Clinic Name", doctorData!['hospital'] ?? "Not set"),
                  _buildProfileItem("Clinic Address", doctorData!['clinic_address'] ?? "Not set"),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}