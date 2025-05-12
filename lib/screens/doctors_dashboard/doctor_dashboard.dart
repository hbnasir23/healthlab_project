import 'package:flutter/material.dart';
import 'package:healthlab/screens/doctors_dashboard/transaction_history.dart';
import '../../constants.dart';
import '../../services/auth_service.dart';
import 'schedule_screen.dart';
import 'profile_screen.dart';
import 'appointments_screen.dart';
import 'notifications.dart';

class DoctorDashboardScreen extends StatefulWidget {
  const DoctorDashboardScreen({super.key});

  @override
  DoctorDashboardScreenState createState() => DoctorDashboardScreenState();
}

class DoctorDashboardScreenState extends State<DoctorDashboardScreen> {
  int selectedIndex = 2; // Default to middle (Schedule)

  Widget getCurrentScreen() {
    switch (selectedIndex) {
      case 0:
        return PaymentDetailsScreen(); // Payments
      case 1:
        return const DoctorProfileScreen();
      case 2:
        return  AppointmentScreen(); // Appointments
      case 3:
        return DoctorScheduleScreen(); // Schedule

      case 4:
        return  NotificationsScreen(); // Notifications
      default:
        return AppointmentScreen();
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: getCurrentScreen(),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.2),
              spreadRadius: 1,
              blurRadius: 10,
            ),
          ],
        ),
        child: BottomNavigationBar(
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.white,
          selectedItemColor: AppColors.teal,
          unselectedItemColor: Colors.grey,
          currentIndex: selectedIndex,
          onTap: (index) {
            setState(() {
              selectedIndex = index;
            });
          },
          items: [
            const BottomNavigationBarItem(
              icon: Icon(Icons.payments),
              label: 'Payments',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.person),
              label: 'Profile',
            ),
             BottomNavigationBarItem(
              icon: Container(
                decoration: const BoxDecoration(
                  color: AppColors.teal,
                  shape: BoxShape.circle,
                ),
                padding: EdgeInsets.all(AppConstants.deviceWidth * 0.03),
                child: const Icon(Icons.list_alt, color: Colors.white),
              ),
              label: 'Appointments',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.calendar_today),

              label: 'Schedule',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.notifications),
              label: 'Notifications',
            ),
          ],
        ),
      ),
    );
  }
}