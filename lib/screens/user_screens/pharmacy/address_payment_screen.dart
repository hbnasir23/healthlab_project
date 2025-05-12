import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:location/location.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../constants.dart';
import '../../../globals.dart';
import 'cart/cart_provider.dart';
import 'receipt_screen.dart';

class CheckoutScreen extends StatefulWidget {
  final List<CartItem> cartItems;
  final double totalAmount;

  const CheckoutScreen({
    super.key,
    required this.cartItems,
    required this.totalAmount,
  });

  @override
  _CheckoutScreenState createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  GoogleMapController? _mapController;
  LocationData? _currentLocation;
  final Location _location = Location();
  final TextEditingController _addressController = TextEditingController();
  String _selectedPayment = 'Credit Card';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _getUserLocation();
  }

  Future<void> _getUserLocation() async {
    final supabase = Supabase.instance.client;
    final userEmail = loggedInEmail;

    try {
      final locationData = await _location.getLocation();
      setState(() {
        _currentLocation = locationData;
      });

      _mapController?.animateCamera(
        CameraUpdate.newLatLng(
          LatLng(locationData.latitude!, locationData.longitude!),
        ),
      );

      // Fetch user data including address
      final userResponse =
          await supabase
              .from('users')
              .select('id, address')
              .eq('email', userEmail!)
              .single();

      if (userResponse != null && userResponse['address'] != null) {
        setState(() {
          _addressController.text = userResponse['address'];
        });
      }
    } catch (e) {
      print('Error fetching user  location or address: $e');
    }
  }

  Future<void> _placeOrder() async {
    final supabase = Supabase.instance.client;
    final userEmail = loggedInEmail;

    try {
      setState(() {
        _isLoading = true;
      });

      final userResponse =
          await supabase
              .from('users')
              .select('id')
              .eq('email', userEmail!)
              .single();

      if (userResponse == null || userResponse['id'] == null) {
        throw Exception('User not found.');
      }

      final userId = userResponse['id'];

      for (var item in widget.cartItems) {
        final response =
            await supabase
                .from('pharmacy')
                .select('quantity')
                .eq('id', item.id)
                .single();

        if (response != null && response['quantity'] != null) {
          int currentQuantity = response['quantity'];
          int newQuantity = (currentQuantity - item.quantity).clamp(
            0,
            currentQuantity,
          );

          await supabase
              .from('pharmacy')
              .update({'quantity': newQuantity})
              .eq('id', item.id);
        }
      }

      await supabase.from('orders').insert({
        'user_id': userId,
        'items': widget.cartItems.map((item) => item.toJson()).toList(),
        'total_amount': widget.totalAmount,
        'address': _addressController.text,
        'payment_type': _selectedPayment,
        'latitude': _markers.isNotEmpty ? _markers.first.position.latitude : _currentLocation?.latitude,
        'longitude': _markers.isNotEmpty ? _markers.first.position.longitude : _currentLocation?.longitude,
        'timestamp': 'now()',
      });


      await supabase
          .from('users')
          .update({'address': _addressController.text})
          .eq('id', userId);

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder:
              (context) => ReceiptScreen(
                items: widget.cartItems,
                totalAmount: widget.totalAmount,
              ),
        ),
      );
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
  Set<Marker> _markers = {};

  void _onMapTapped(LatLng position) {
    setState(() {
      _markers = {
        Marker(
          markerId: MarkerId('selectedLocation'),
          position: position,
        ),
      };
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              flex: 5,
              child: Stack(
                children: [
                  GoogleMap(
                    initialCameraPosition: CameraPosition(
                      target: LatLng(
                        _currentLocation?.latitude ?? 37.7749,
                        _currentLocation?.longitude ?? -122.4194,
                      ),
                      zoom: 14,
                    ),
                    onMapCreated: (controller) {
                      setState(() {
                        _mapController = controller;
                      });
                    },
                    myLocationEnabled: true, // Enable the blue dot
                    myLocationButtonEnabled: false, // Disable the default location button

                    onTap:
                        _onMapTapped, // Allow user to select a location by tapping
                    markers: _markers,
                  ),

                  // Back Button (Top Left)
                  Positioned(
                    top: 16,
                    left: 16,
                    child: FloatingActionButton(
                      onPressed: () => Navigator.pop(context),
                      backgroundColor: AppColors.teal,
                      child: Icon(Icons.arrow_back, color: Colors.white),
                    ),
                  ),

                  // Current Location Button (Bottom Left)
                  Positioned(
                    bottom: 16,
                    left: 16,
                    child: FloatingActionButton(
                      onPressed: _getUserLocation,
                      backgroundColor: AppColors.teal,
                      child: Icon(Icons.my_location, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),

            // Checkout Form
            Expanded(
              flex: 5,
              child: SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: AppConstants.deviceWidth * 0.05,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(height: 16),

                      // Address Label
                      Text(
                        "Address",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 8),

                      // Address Input Field
                      TextField(
                        controller: _addressController,
                        decoration: InputDecoration(
                          hintText: 'Enter your address',
                          filled: true,
                          fillColor: const Color(0xFFF8F9FE),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.all(16),
                        ),
                      ),
                      SizedBox(height: 16),

                      // Payment Type (Radio Buttons)
                      Text(
                        "Payment Type",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Column(
                        children: [
                          ListTile(
                            title: Text('Credit Card'),
                            leading: Radio(
                              value: 'Credit Card',
                              groupValue: _selectedPayment,
                              onChanged: (value) {
                                setState(() {
                                  _selectedPayment = value as String;
                                });
                              },
                              activeColor: AppColors.teal,
                            ),
                          ),
                          ListTile(
                            title: Text('Cash on Delivery'),
                            leading: Radio(
                              value: 'Cash on Delivery',
                              groupValue: _selectedPayment,
                              onChanged: (value) {
                                setState(() {
                                  _selectedPayment = value as String;
                                });
                              },
                              activeColor: AppColors.teal,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 24),

                      // Checkout Button
                      SizedBox(
                        width: AppConstants.deviceWidth * 0.9,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _placeOrder,
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
                                    'Checkout',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                        ),
                      ),
                      SizedBox(
                        height: 16,
                      ), // To prevent bottom content from cutting off
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
