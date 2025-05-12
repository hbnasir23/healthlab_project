import 'package:flutter/material.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../constants.dart';

class AddDoctorsScreen extends StatefulWidget {
  final Map<String, dynamic>? doctor;

  const AddDoctorsScreen({super.key, this.doctor});

  @override
  State<AddDoctorsScreen> createState() => _AddDoctorsScreenState();
}

class _AddDoctorsScreenState extends State<AddDoctorsScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _specializationController =
      TextEditingController();
  final TextEditingController _areaController = TextEditingController();
  final TextEditingController _hospitalController = TextEditingController();
  final TextEditingController _feesController = TextEditingController();
  File? _imageFile;

  @override
  @override
  void initState() {
    super.initState();
    if (widget.doctor != null) {
      _nameController.text = widget.doctor!['name'] ?? '';
      _phoneController.text = widget.doctor!['phone'] ?? '';
      _specializationController.text = widget.doctor!['specialization'] ?? '';
      _areaController.text = widget.doctor!['area'] ?? '';
      _hospitalController.text = widget.doctor!['hospital'] ?? '';
      _feesController.text = widget.doctor!['fees']?.toString() ?? '0';
    }
  }

  Future<void> _pickImage() async {
    final pickedFile =
        await ImagePicker().pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _imageFile = File(pickedFile.path);
      });
    }
  }

  Future<void> _addDoctor(BuildContext context) async {
    if (_imageFile == null && widget.doctor == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an image')),
      );
      return;
    }

    if (_formKey.currentState!.validate()) {
      try {
        final supabase = Supabase.instance.client;

        String? imageUrl;

        if (_imageFile != null) {
          // Upload image to Supabase Storage
          final fileBytes = await _imageFile!.readAsBytes();
          final fileName =
              'doctor_${DateTime.now().millisecondsSinceEpoch}.jpg';
          final bucketPath = 'doctors/$fileName'; // Folder in Supabase Storage

          await supabase.storage.from('doctors').uploadBinary(
                bucketPath,
                fileBytes,
                fileOptions: const FileOptions(contentType: 'image/jpeg'),
              );

          // Get public URL
          imageUrl = supabase.storage.from('doctors').getPublicUrl(bucketPath);
        }

        final doctor = {
          'name': _nameController.text,
          'phone': _phoneController.text.toString(),
          'specialization': _specializationController.text,
          'area': _areaController.text,
          'hospital': _hospitalController.text,
          'fees': double.tryParse(_feesController.text) ?? 0.0,
          'photo': imageUrl ?? widget.doctor?['photo'],
        };

        if (widget.doctor == null) {
          // Adding a new doctor
          await supabase.from('doctors').insert(doctor);
          _showSuccessMessage(context, 'Doctor added successfully!');
          setState(() {});
        } else {
          // Updating an existing doctor
          await supabase
              .from('doctors')
              .update(doctor)
              .eq('id', widget.doctor!['id']);
          _showSuccessMessage(context, 'Doctor updated successfully!');
        }

        Navigator.of(context).pop();
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  void _showSuccessMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
        validator: validator,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Stack(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      widget.doctor == null ? 'Add New Doctor' : 'Edit Doctor',
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.teal,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    GestureDetector(
                      onTap: _pickImage,
                      child: Container(
                        height: AppConstants.deviceHeight * 0.18,
                        width: AppConstants.deviceWidth * 0.18,
                        margin: const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: _imageFile != null
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child:
                                    Image.file(_imageFile!, fit: BoxFit.cover),
                              )
                            : widget.doctor != null &&
                                    widget.doctor!['photo'] != null
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: Image.network(
                                        widget.doctor!['photo'],
                                        fit: BoxFit.cover),
                                  )
                                : const Icon(Icons.add_a_photo,
                                    size: 50, color: Colors.grey),
                      ),
                    ),
                    _buildTextField(
                      controller: _nameController,
                      label: 'Doctor Name',
                      validator: (value) =>
                          value!.isEmpty ? 'Please enter doctor name' : null,
                    ),
                    _buildTextField(
                      controller: _phoneController,
                      label: 'Phone Number',
                      keyboardType: TextInputType.phone,
                      validator: (value) =>
                          value!.isEmpty ? 'Please enter phone number' : null,
                    ),
                    _buildTextField(
                      controller: _specializationController,
                      label: 'Specialization',
                      validator: (value) =>
                          value!.isEmpty ? 'Please enter specialization' : null,
                    ),
                    _buildTextField(
                      controller: _areaController,
                      label: 'Area',
                      validator: (value) =>
                          value!.isEmpty ? 'Please enter area' : null,
                    ),
                    _buildTextField(
                      controller: _hospitalController,
                      label: 'Hospital/Clinic',
                      validator: (value) => value!.isEmpty
                          ? 'Please enter hospital/clinic'
                          : null,
                    ),
                    _buildTextField(
                      controller: _feesController,
                      label: 'Consultation Fees',
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value!.isEmpty) return 'Please enter fees';
                        if (double.tryParse(value) == null) {
                          return 'Please enter valid amount';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () => _addDoctor(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text(widget.doctor == null
                          ? 'Add Doctor'
                          : 'Save Changes'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
