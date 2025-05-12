import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../../globals.dart';
import 'package:intl/intl.dart';
import '../../constants.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final supabase = Supabase.instance.client;
  final ImagePicker _picker = ImagePicker();
  Map<String, dynamic>? userData;
  bool _isPasswordVisible = false;
  bool _isLoading = false;

  final List<String> bloodGroups = [
    'A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'
  ];

  @override
  void initState() {
    super.initState();
    _fetchUserData();
  }

  Future<void> _fetchUserData() async {
    try {
      final response = await supabase
          .from('users')
          .select()
          .eq('email', loggedInEmail!)
          .single();

      setState(() {
        userData = response;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error fetching user data: $e')),
        );
      }
    }
  }

  Future<void> _updateUserData(String field, dynamic value) async {
    setState(() => _isLoading = true);
    try {
      String dbField = field.toLowerCase().replaceAll(' ', '');
      dynamic processedValue = value;

      switch (dbField) {
        case 'weight':
        case 'height':
          processedValue = int.tryParse(value.toString()) ?? 0;
          break;
        case 'dateofbirth':
          try {
            processedValue = DateTime.parse(value).toIso8601String();
          } catch (e) {
            throw Exception('Invalid date format');
          }
          break;
      }

      Map<String, dynamic> updateData = {dbField: processedValue};

      final response = await supabase
          .from('users')
          .update(updateData)
          .eq('email', loggedInEmail!)
          .select();

      if (response.isNotEmpty) {
        setState(() {
          userData = response[0];
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

  void _showGenderSelection() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Select Gender"),
        content: StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            String currentGender = userData?['sex'] ?? 'Male';
            return Container(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SingleChildScrollView(
                    child: SafeArea(
                    child: SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(
                          value: 'Male',
                          icon: Icon(Icons.male),
                          label: Text('Male'),
                        ),
                        ButtonSegment(
                          value: 'Female',
                          icon: Icon(Icons.female),
                          label: Text('Female'),
                        ),
                      ],
                      selected: {currentGender},
                      onSelectionChanged: (Set<String> selection) {
                        setState(() {
                          currentGender = selection.first;
                        });
                        Navigator.pop(context);
                        _updateUserData('sex', selection.first);
                      },
                      style: ButtonStyle(
                        backgroundColor: MaterialStateProperty.resolveWith<Color>(
                              (Set<MaterialState> states) {
                            if (states.contains(MaterialState.selected)) {
                              return Colors.teal;
                            }
                            return Colors.white;
                          },
                        ),
                      ),
                    ),
                  ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
  String? _selectedBloodGroup;

  void _showBloodGroupDropdown() {
    _selectedBloodGroup = userData?['bloodgroup'] ?? bloodGroups[0];

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Select Blood Group"),
          content: StatefulBuilder(
            builder: (context, setState) {
              return DropdownButton<String>(
                value: _selectedBloodGroup,
                isExpanded: true,
                items: bloodGroups.map((String group) {
                  return DropdownMenuItem<String>(
                    value: group,
                    child: Text(group),
                  );
                }).toList(),
                onChanged: (String? newValue) {
                  if (newValue != null) {
                    setState(() {
                      _selectedBloodGroup = newValue;
                    });
                  }
                },
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context), // Close without saving
              child: const Text("Cancel"),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context); // Close dialog
                _updateUserData('bloodgroup', _selectedBloodGroup!); // Save to Supabase
              },
              child: const Text("Save"),
            ),
          ],
        );
      },
    );
  }


  String _formatDate(String? dateString) {
    if (dateString == null || dateString == "Not set") return "Not set";
    try {
      DateTime date = DateTime.parse(dateString);
      return DateFormat('MMM dd, yyyy').format(date);
    } catch (e) {
      return dateString;
    }
  }


  void _showEditPopup(String field, String currentValue) {
    switch (field.toLowerCase()) {
      case 'dateofbirth':
        _showDatePicker(currentValue);
        break;
      case 'weight':
      case 'height':
        _showNumberEditPopup(field, currentValue);
        break;
      case 'sex':
        _showGenderSelection();
        break;
      case 'bloodgroup':
        _showBloodGroupDropdown();
        break;
      default:
        if (!['email', 'name', 'password'].contains(field.toLowerCase())) {
          _showTextEditPopup(field, currentValue);
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

        await supabase.storage
            .from('users')
            .upload(fileName, file, fileOptions: const FileOptions(upsert: true));

        final imageUrl = supabase.storage
            .from('users')
            .getPublicUrl(fileName);

        await _updateUserData('photo', imageUrl);
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


  void _showDatePicker(String currentValue) async {
    DateTime? initialDate;
    try {
      initialDate = DateTime.parse(currentValue);
    } catch (e) {
      initialDate = DateTime.now();
    }

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );

    if (picked != null) {
      _updateUserData('dateofbirth', picked.toIso8601String());
    }
  }

  void _showNumberEditPopup(String field, String currentValue) {
    TextEditingController controller = TextEditingController(text: currentValue);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Edit $field"),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _updateUserData(field, controller.text.trim());
            },
            child: const Text("Save"),
          ),
        ],
      ),
    );
  }

  void _showTextEditPopup(String field, String currentValue) {
    TextEditingController controller = TextEditingController(text: currentValue);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Edit $field"),
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
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _updateUserData(field, controller.text.trim());
            },
            child: const Text("Save"),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileItem(String label, String value, {bool isPassword = false, bool isEditable = true, String? unit}) {
    // Format the display value if unit is provided or if it's a date
    String displayValue = value;
    if (label.toLowerCase() == 'date of birth') {
      displayValue = _formatDate(value);
    } else if (unit != null && value != "Not set") {
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
            ? Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(
                label.toLowerCase() == 'bloodgroup'
                    ? Icons.arrow_drop_down
                    : isPassword
                    ? (_isPasswordVisible ? Icons.visibility : Icons.visibility_off)
                    : Icons.edit,
                color: Colors.teal,
              ),
              onPressed: () {
                if (label.toLowerCase().replaceAll(" ", "") == 'bloodgroup') {
                  _showBloodGroupDropdown();
                } else if (label.toLowerCase() == 'date of birth') {
                  _showDatePicker(value);
                } else if (label.toLowerCase() == 'sex') {
                  _showGenderSelection();
                } else if (isPassword) {
                  setState(() {
                    _isPasswordVisible = !_isPasswordVisible;
                  });
                } else {
                  _showEditPopup(label, value);
                }
              },
            ),
          ],
        )
            : null,
      ),
    );
  }
  @override
  Widget build(BuildContext context) {
    if (userData == null || _isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      body: SingleChildScrollView(
        child: Column(

          children: [
      SizedBox(height: AppConstants.deviceHeight * .055),
      Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Profile',
              style: TextStyle(
                fontSize: AppConstants.deviceWidth * 0.06,
                fontWeight: FontWeight.bold,
                color: Colors.black,
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
                      backgroundImage: userData!['photo'] != null
                          ? NetworkImage(userData!['photo'])
                          : null,
                      child: userData!['photo'] == null
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
            _buildProfileItem("Address", userData!['address'] ?? "Not set",),

            _buildProfileItem("Date of Birth", userData!['dateofbirth']?.toString() ?? "Not set"),
            _buildProfileItem("Weight", userData!['weight']?.toString() ?? "Not set", unit: "kg"),
            _buildProfileItem("Height", userData!['height']?.toString() ?? "Not set", unit: "cm"),
            _buildProfileItem("Sex", userData!['sex'] ?? "Not set"),
            _buildProfileItem("Blood Group", userData!['bloodgroup'] ?? "Not set"),
          ],
        ),
      ),
    ],
    )
    )
    );
  }
}