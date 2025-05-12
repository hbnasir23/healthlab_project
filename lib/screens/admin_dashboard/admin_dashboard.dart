import 'package:flutter/material.dart';
import '../../constants.dart';
import 'manage_users_screen.dart';
import 'doctor_management/manage_doctors_screen.dart';
import 'pharmacy_management/manage_pharmacy_screen.dart';
import 'notification_screen.dart';
import '../../widgets/navigation_button.dart';
import '../../services/auth_service.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  _AdminDashboardScreenState createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  int _selectedIndex = 2;

  List<Widget> _getScreens() {
    return [
      const ManageUsersScreen(),
      const ManageDoctorsScreen(),
      AdminHomeScreen(onNavigate: _updateIndex),
      const ManagePharmacyScreen(),
      NotificationScreen(),
    ];
  }

  void _updateIndex(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _getScreens()[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.white,
        selectedItemColor: AppColors.teal,
        unselectedItemColor: Colors.grey,
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        items: [
          const BottomNavigationBarItem(
              icon: Icon(Icons.person), label: 'Users'),
          const BottomNavigationBarItem(
              icon: Icon(Icons.medical_services), label: 'Doctors'),
          BottomNavigationBarItem(
            icon: Container(
              decoration: const BoxDecoration(
                color: AppColors.teal,
                shape: BoxShape.circle,
              ),
              padding: EdgeInsets.all(
                  AppConstants.deviceWidth * 0.03), // Responsive padding
              child: const Icon(Icons.home, color: Colors.white),
            ),
            label: 'Home',
          ),
          const BottomNavigationBarItem(
              icon: Icon(Icons.local_pharmacy), label: 'Pharmacy'),
          const BottomNavigationBarItem(
              icon: Icon(Icons.notifications), label: 'Notifications'),
        ],
      ),
    );
  }
}

class AdminHomeScreen extends StatelessWidget {
  final Function(int) onNavigate; // Callback function to update index

  const AdminHomeScreen({super.key, required this.onNavigate});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.logout, color: Colors.red),
                  onPressed: () {
                    AuthService().clearCredentials();
                    Navigator.pushReplacementNamed(context, '/login');
                  },
                ),
                Text(
                  'Admin Dashboard',
                  style: TextStyle(
                    fontSize: AppConstants.deviceWidth * 0.06,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Image.asset(
                  'assets/images/logo.png',
                  height: AppConstants.deviceHeight * 0.08,
                ),
              ],
            ),
            SizedBox(height: AppConstants.deviceHeight * 0.05),
            Expanded(
              child: GridView.count(
                crossAxisCount: 2,
                mainAxisSpacing: AppConstants.deviceHeight * 0.02,
                crossAxisSpacing: AppConstants.deviceWidth * 0.04,
                children: [
                  NavigationButton(
                      title: 'Manage Users',
                      screenIndex: 0,
                      onTap: () => onNavigate(0)),
                  NavigationButton(
                      title: 'Manage Doctors',
                      screenIndex: 1,
                      onTap: () => onNavigate(1)),
                  NavigationButton(
                      title: 'Manage Pharmacy',
                      screenIndex: 3,
                      onTap: () => onNavigate(3)),
                  NavigationButton(
                      title: 'Notifications',
                      screenIndex: 4,
                      onTap: () => onNavigate(4)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
