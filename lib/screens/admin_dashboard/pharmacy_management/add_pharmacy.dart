import 'package:flutter/material.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../constants.dart';

class AddPharmacyItemScreen extends StatefulWidget {
  final Map<String, dynamic>? item;

  const AddPharmacyItemScreen({super.key, this.item});

  @override
  State<AddPharmacyItemScreen> createState() => _AddPharmacyItemScreenState();
}

class _AddPharmacyItemScreenState extends State<AddPharmacyItemScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _quantityController = TextEditingController();
  File? _imageFile;

  @override
  void initState() {
    super.initState();
    if (widget.item != null) {
      _nameController.text = widget.item!['name'];
      _descriptionController.text = widget.item!['description'];
      _priceController.text = widget.item!['price'].toString();
      _quantityController.text = widget.item!['quantity'].toString();
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

  Future<void> _addPharmacyItem(BuildContext context) async {
    if (_imageFile == null && widget.item == null) {
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
          final fileName = 'item_${DateTime.now().millisecondsSinceEpoch}.jpg';
          final bucketPath = 'pharmacy/$fileName'; // Folder in Supabase Storage

          await supabase.storage.from('pharmacy').uploadBinary(
                bucketPath,
                fileBytes,
                fileOptions: const FileOptions(contentType: 'image/jpeg'),
              );

          // Get public URL
          imageUrl = supabase.storage.from('pharmacy').getPublicUrl(bucketPath);
        }

        final item = {
          'name': _nameController.text,
          'description': _descriptionController.text,
          'price': double.tryParse(_priceController.text) ?? 0.0,
          'quantity': int.tryParse(_quantityController.text) ?? 0,
          'photo': imageUrl ?? widget.item?['photo'],
        };

        if (widget.item == null) {
          // Adding a new item
          await supabase.from('pharmacy').insert(item);
          _showSuccessMessage(context, 'Item added successfully!');
        } else {
          // Updating an existing item
          await supabase
              .from('pharmacy')
              .update(item)
              .eq('id', widget.item!['id']);
          _showSuccessMessage(context, 'Item updated successfully!');
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
    int? maxLines = 1, // Add maxLines parameter with default value
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines,
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
                      widget.item == null ? 'Add New Item' : 'Edit Item',
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
                            : widget.item != null &&
                                    widget.item!['photo'] != null
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: Image.network(widget.item!['photo'],
                                        fit: BoxFit.cover),
                                  )
                                : const Icon(Icons.add_a_photo,
                                    size: 50, color: Colors.grey),
                      ),
                    ),
                    _buildTextField(
                      controller: _nameController,
                      label: 'Item Name',
                      validator: (value) =>
                          value!.isEmpty ? 'Please enter item name' : null,
                    ),
                    _buildTextField(
                      controller: _descriptionController,
                      label: 'Description',
                      validator: (value) =>
                          value!.isEmpty ? 'Please enter description' : null,
                      maxLines: null, // Allows multiple lines
                    ),
                    _buildTextField(
                      controller: _priceController,
                      label: 'Price',
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value!.isEmpty) return 'Please enter price';
                        if (double.tryParse(value) == null) {
                          return 'Please enter valid price';
                        }
                        return null;
                      },
                    ),
                    _buildTextField(
                      controller: _quantityController,
                      label: 'Quantity',
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value!.isEmpty) return 'Please enter quantity';
                        if (int.tryParse(value) == null) {
                          return 'Please enter valid quantity';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () => _addPharmacyItem(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text(
                          widget.item == null ? 'Add Item' : 'Save Changes'),
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
