import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async';
import '../../constants.dart';
import '../../widgets/bottom_navigation.dart';
import 'charts_screen.dart';
import 'profile_screen.dart';
import 'pharmacy/user_pharmacy_screen.dart';
import 'doctor_screen.dart';
import 'package:healthlab/globals.dart';
import '../../services/auth_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  HomeScreenState createState() => HomeScreenState();
}

class HomeScreenState extends State<HomeScreen> {
  int selectedIndex = 2;
  bool isLoading = true;
  Map<String, dynamic>? latestData;

  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    fetchLatestData();

    // Setup automatic refresh every 5 seconds
    _refreshTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (mounted && selectedIndex == 2) { // Only refresh when on home screen
        fetchLatestData();
      }
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel(); // Cancel the timer to prevent setState after dispose
    super.dispose();
  }

  Future<void> fetchLatestData() async {
    if (!mounted) return; // Check if widget is still mounted before proceeding

    try {
      final supabase = Supabase.instance.client;
      final response = await supabase
          .from('banddata')
          .select()
          .order('created_at', ascending: false)
          .limit(1)
          .single();

      if (mounted) { // Check again after async operation
        setState(() {
          latestData = response;
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) { // Check if still mounted before calling setState
        setState(() {
          isLoading = false;
        });
      }
      debugPrint('Error fetching latest data: $e');
    }
  }

  Widget getCurrentScreen() {
    switch (selectedIndex) {
      case 0:
        return const ChartsScreen();
      case 1:
        return const ProfileScreen();
      case 2:
        return buildHomeScreen();
      case 3:
        return const DoctorScreen();
      case 4:
        return const UserPharmacyScreen();
      default:
        return buildHomeScreen();
    }
  }

  void showSettingsDrawer() {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: "Settings",
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (_, __, ___) {
        return Align(
          alignment: Alignment.centerLeft,
          child: Material(
            color: Colors.white,
            child: SizedBox(
              width: AppConstants.deviceWidth * 0.6,
              height: AppConstants.deviceHeight,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(height: AppConstants.deviceHeight * .10),
                  ListTile(
                    leading: const Icon(Icons.info, color: AppColors.teal),
                    title: const Text("About"),
                    onTap: () {
                      Navigator.pop(context);
                      showAboutPopup();
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.history, color: AppColors.teal),
                    title: const Text("Purchase History"),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.pushNamed(context, '/purchase_history');
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.logout, color: Colors.red),
                    title: const Text("Logout"),
                    onTap: () {
                      AuthService().clearCredentials();
                      Navigator.pushReplacementNamed(context, '/login');
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(-1.0, 0.0),
            end: Offset.zero,
          ).animate(animation),
          child: child,
        );
      },
    );
  }

  void showAboutPopup() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("About This App"),
          content: const Text(
            "This is a health tracking application that helps users monitor their medical records and connect with doctors.",
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Close"),
            ),
          ],
        );
      },
    );
  }

  Color getVitalColor(String vitalType, double value) {
    switch (vitalType) {
      case 'heart_rate':
        if (value < 60 || value > 100) return Colors.red;
        if (value < 65 || value > 90) return Colors.orange;
        return Colors.green;

      case 'spo2':
        if (value < 90) return Colors.red;
        if (value < 95) return Colors.orange;
        return Colors.green;

      case 'body_temp':
        if (value < 95.9 || value > 100.4) return Colors.red;
        if (value < 97.0 || value > 99.5) return Colors.orange;
        return Colors.green;

      case 'room_temp':
        if (value < 18) return Colors.blue;       // Too cold
        if (value < 20) return Colors.orange;     // Slightly cold
        if (value <= 30) return Colors.green;     // Comfortable
        return Colors.red;                        // Hot

      case 'uv_index':
        if (value <= 2) return Colors.green;       // Low
        if (value <= 5) return Colors.orange;      // Moderate
        if (value <= 7) return Colors.red;         // High
        return Colors.deepPurple;                  // Very High

      default:
        return Colors.green;
    }
  }


  // Get icon for vital type
  IconData getVitalIcon(String vitalType) {
    switch (vitalType) {
      case 'heart_rate':
        return Icons.favorite;
      case 'spo2':
        return Icons.air;
      case 'body_temp':
        return Icons.thermostat;
      case 'room_temp':
        return Icons.home;
      case 'uv_index':
        return Icons.wb_sunny;
      default:
        return Icons.assessment;
    }
  }

  // Get label for vital type
  String getVitalLabel(String vitalType) {
    switch (vitalType) {
      case 'heart_rate':
        return 'Heart Rate';
      case 'spo2':
        return 'SpO₂';
      case 'body_temp':
        return 'Body Temp';
      case 'room_temp':
        return 'Room Temp';
      case 'uv_index':
        return 'UV Index';
      default:
        return vitalType;
    }
  }

  // Get unit for vital type
  String getVitalUnit(String vitalType) {
    switch (vitalType) {
      case 'heart_rate':
        return 'bpm';
      case 'spo2':
        return '%';
      case 'body_temp':
        return '°F';
      case 'room_temp':
        return '°C';
      case 'uv_index':
        return '';
      default:
        return '';
    }
  }

  Widget buildVitalTile(String vitalType, double value) {
    final color = getVitalColor(vitalType, value);
    final icon = getVitalIcon(vitalType);
    final label = getVitalLabel(vitalType);
    final unit = getVitalUnit(vitalType);
    final statusText = getVitalStatusText(vitalType, value);

    // Format the value to show only 1 decimal place
    final formattedValue = value.toStringAsFixed(1);

    return Container(
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color, width: 2),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 40, color: color),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              color: Colors.black87,
              fontSize: AppConstants.deviceWidth * 0.035,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                formattedValue,
                style: TextStyle(
                  color: Colors.black87,
                  fontSize: AppConstants.deviceWidth * 0.05,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                ' $unit',
                style: TextStyle(
                  color: Colors.black54,
                  fontSize: AppConstants.deviceWidth * 0.035,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            statusText,
            style: TextStyle(
              color: color,
              fontSize: AppConstants.deviceWidth * 0.03,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  String getVitalStatusText(String vitalType, double value) {
    switch (vitalType) {
      case 'heart_rate':
        if (value < 60) return 'Dangerously Low';
        if (value < 65) return 'Low';
        if (value > 100) return 'Dangerously High';
        if (value > 90) return 'High';
        return 'Normal';

      case 'spo2':
        if (value < 90) return 'Dangerously Low';
        if (value < 95) return 'Low';
        return 'Normal';

      case 'body_temp':
        if (value < 95.9) return 'Dangerously Low';
        if (value > 100.4) return 'Dangerously High';
        if (value < 97.0) return 'Low';
        if (value > 99.5) return 'High';
        return 'Normal';

      case 'room_temp':
        if (value < 18) return 'Too Cold';
        if (value < 20) return 'Chilly';
        if (value <= 30) return 'Comfortable';
        return 'Too Hot';

      case 'uv_index':
        if (value <= 2) return 'Low';
        if (value <= 5) return 'Moderate';
        if (value <= 7) return 'High';
        if (value <= 10) return 'Very High';
        return 'Extreme';

      default:
        return '';
    }
  }

  Widget buildHomeScreen() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.settings, color: AppColors.teal),
                      onPressed: showSettingsDrawer,
                    ),
                    Text(
                      'Hi, $loggedInUsername!',
                      style: TextStyle(
                        fontSize: AppConstants.deviceWidth * 0.06,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                Image.asset(
                  'assets/images/logo.png',
                  height: AppConstants.deviceHeight * 0.08,
                ),
              ],
            ),
            SizedBox(height: AppConstants.deviceHeight * 0.05),
            isLoading
                ? const Center(child: CircularProgressIndicator())
                : latestData == null
                ? const Center(
              child: Text(
                'No health data available',
                style: TextStyle(fontSize: 18),
              ),
            )
                : Expanded(
              child: Column(
                children: [
                  // First row - 2 tiles
                  Expanded(
                    child: Row(
                      children: [
                        Expanded(
                          child: buildVitalTile('heart_rate', latestData!['heart_rate'].toDouble()),
                        ),
                        SizedBox(width: AppConstants.deviceWidth * 0.04),
                        Expanded(
                          child: buildVitalTile('spo2', latestData!['spo2'].toDouble()),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: AppConstants.deviceHeight * 0.02),
                  // Second row - 2 tiles
                  Expanded(
                    child: Row(
                      children: [
                        Expanded(
                          child: buildVitalTile('body_temp', latestData!['body_temp'].toDouble()),
                        ),
                        SizedBox(width: AppConstants.deviceWidth * 0.04),
                        Expanded(
                          child: buildVitalTile('room_temp', latestData!['room_temp'].toDouble()),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: AppConstants.deviceHeight * 0.02),
                  // Third row - 1 centered tile
                  Expanded(
                    child: Row(
                      children: [
                        Expanded(flex: 1, child: Container()),
                        Expanded(
                          flex: 2,
                          child: buildVitalTile('uv_index', latestData!['uv_index'].toDouble()),
                        ),
                        Expanded(flex: 1, child: Container()),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void onTabChanged(int index) {
    if (mounted) {
      setState(() {
        selectedIndex = index;
      });
    }

    // Fetch latest data when returning to home screen tab
    if (index == 2 && mounted) {
      fetchLatestData();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: getCurrentScreen(),
      bottomNavigationBar: BottomNavigationBarWidget(
        currentIndex: selectedIndex,
        onTap: onTabChanged,
      ),
    );
  }
}