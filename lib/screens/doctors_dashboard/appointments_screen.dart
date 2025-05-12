import 'package:flutter/material.dart';
import 'package:healthlab/screens/doctors_dashboard/transaction_history.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../constants.dart';
import '../../globals.dart';
import '../../services/auth_service.dart';


class AppointmentScreen extends StatefulWidget {
  const AppointmentScreen({Key? key}) : super(key: key);

  @override
  State<AppointmentScreen> createState() => _AppointmentScreenState();
}

class _AppointmentScreenState extends State<AppointmentScreen> {
  List<Map<String, dynamic>> _confirmedAppointments = [];
  bool _isLoading = true;
  String _errorMessage = '';
  final _supabase = Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    _fetchConfirmedAppointments();
  }

  Future<void> _fetchConfirmedAppointments() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });
    Future<int?> getUserIdByEmail(String email) async {
      final supabase = Supabase.instance.client;
      final response = await supabase
          .from('users')
          .select('id')
          .eq('email', email)
          .single();

      if (response != null) {
        return response['id'];
      } else {
        return null; // No user found
      }
    }

    try {
      final doctorId = await getUserIdByEmail(loggedInEmail!);

      final response = await _supabase
          .from('appointments')
          .select('*, patient:user_id(*)')
          .eq('doctor_id', doctorId!)
          .eq('status', 'confirmed')
          .order('booking_date', ascending: false);

      setState(() {
        _confirmedAppointments = List<Map<String, dynamic>>.from(response);
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _updateAppointmentPaymentStatus(String appointmentId, bool isPaid) async {
    try {
      await _supabase
          .from('appointments')
          .update({'payment_status': isPaid ? 'paid' : 'pending'})
          .eq('appointment_id', appointmentId);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Payment marked as ${isPaid ? 'completed' : 'pending'}'),
          backgroundColor: isPaid ? Colors.green : Colors.orange,
        ),
      );

      // Refresh the list
      _fetchConfirmedAppointments();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating payment status: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _updateAppointmentStatus(String appointmentId, String status) async {
    try {
      await _supabase
          .from('appointments')
          .update({'status': status})
          .eq('appointment_id', appointmentId);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Appointment marked as $status'),
          backgroundColor: status == 'completed' ? Colors.green : Colors.blue,
        ),
      );

      // Refresh the list
      _fetchConfirmedAppointments();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating appointment status: $e'),
          backgroundColor: Colors.red,
        ),
      );
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
                  SizedBox(height: AppConstants.deviceHeight * .10), // Space from top
                  ListTile(
                    leading: const Icon(Icons.history, color: AppColors.teal),
                    title: const Text("Transaction History"),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>  PaymentDetailsScreen(),
                        ),
                      );
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.info, color: AppColors.teal),
                    title: const Text("About"),
                    onTap: () {
                      Navigator.pop(context);
                      showAboutPopup();
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.logout, color: Colors.red),
                    title: const Text("Logout"),
                    onTap: () {
                      showLogoutPopup(context);
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
            begin: const Offset(-1.0, 0.0), // Start off-screen left
            end: Offset.zero, // Slide into place
          ).animate(animation),
          child: child,
        );
      },
    );
  }
  void showLogoutPopup(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Confirm Logout"),
          content: const Text("Are you sure you want to logout?"),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close the dialog
              },
              child: const Text("Cancel"),
            ),
            TextButton(
              onPressed: () {
                AuthService().clearCredentials();
                Navigator.of(context).pop(); // Close the dialog
                Navigator.pushReplacementNamed(context, '/login');
              },
              child: const Text("Logout", style: TextStyle(color: Colors.red)),
            ),
          ],
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Colors.white,
        toolbarHeight: AppConstants.deviceHeight * 0.08,
        title: Padding(
          padding: EdgeInsets.only(top: 10.0), // Adjust this value to move it down
          child: Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              // Settings Button (Left-most)
              IconButton(
                icon: const Icon(Icons.settings, color: AppColors.teal),
                onPressed: showSettingsDrawer, // Open the settings drawer
              ),
              // Title Text
              Text(
                'Confirmed Appointments',
                style: TextStyle(
                  fontSize: AppConstants.deviceWidth * 0.0553,
                  fontWeight: FontWeight.bold,
                  color: AppColors.teal,
                ),
              ),
              // Logo Image
              Image.asset(
                'assets/images/logo.png',
                height: AppConstants.deviceHeight * 0.08,
              ),
            ],
          ),
        ),
        iconTheme: const IconThemeData(color: AppColors.teal),
        elevation: 0, // Optional: Removes shadow for a clean UI
      ),
      body: RefreshIndicator(
        onRefresh: _fetchConfirmedAppointments,
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.teal));
    }

    if (_errorMessage.isNotEmpty) {
      return Center(child: Text(_errorMessage, style: TextStyle(color: Colors.red)));
    }

    if (_confirmedAppointments.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.calendar_today, size: 60, color: AppColors.lightBlue),
            const SizedBox(height: 16),
            Text(
              'No confirmed appointments',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _confirmedAppointments.length,
      itemBuilder: (context, index) {
        final appointment = _confirmedAppointments[index];
        final appointmentId = appointment['appointment_id'] ?? -1;
        final patientName = appointment['patient']?['name'] ?? 'Unknown Patient';
        final patientPhone = appointment['patient']?['phone'] ?? 'N/A';
        final bookingDate = DateTime.parse(appointment['booking_date'] ?? DateTime.now().toString());
        final formattedDate = DateFormat('MMM dd, yyyy').format(bookingDate);
        final appointmentTime = appointment['appointment_time'] ?? 'N/A';
        final appointmentDay = appointment['appointment_day'] ?? 'N/A';
        final amount = appointment['amount']?.toString() ?? '0';
        final paymentMethod = appointment['payment_method'] ?? 'N/A';
        final paymentStatus = appointment['payment_status'] ?? 'unpaid';
        final isPaid = paymentStatus.toLowerCase() == 'paid';

        return _buildAppointmentCard(
          appointmentId: appointmentId,
          patientName: patientName,
          patientPhone: patientPhone,
          appointmentDate: formattedDate,
          appointmentTime: appointmentTime,
          appointmentDay: appointmentDay,
          amount: amount,
          paymentMethod: paymentMethod,
          isPaid: isPaid,
        );
      },
    );
  }

  Widget _buildAppointmentCard({
    required String appointmentId,
    required String patientName,
    required String patientPhone,
    required String appointmentDate,
    required String appointmentTime,
    required String appointmentDay,
    required String amount,
    required String paymentMethod,
    required bool isPaid,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: AppColors.teal.withOpacity(0.3), width: 1),
      ),
      child: Column(
        children: [
          // Patient info section
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.teal.withOpacity(0.1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: AppColors.teal.withOpacity(0.3),
                  radius: 24,
                  child: const Icon(Icons.person, size: 28, color: AppColors.teal),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        patientName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                      Row(
                        children: [
                          const Icon(Icons.phone, size: 14, color: Colors.grey),
                          const SizedBox(width: 4),
                          Text(
                            patientPhone,
                            style: TextStyle(
                              color: Colors.grey[700],
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: isPaid ? Colors.green : Colors.orange,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    isPaid ? 'Paid' : 'Unpaid',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Appointment details section
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _buildDetailRow(Icons.calendar_today, 'Date', appointmentDate),
                _buildDetailRow(Icons.access_time, 'Time', appointmentTime),
                _buildDetailRow(Icons.today, 'Day', appointmentDay),
                _buildDetailRow(Icons.payments, 'Amount', 'Rs.$amount'),
                _buildDetailRow(Icons.payment, 'Method', paymentMethod),

                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 16),

                // Action buttons
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _updateAppointmentPaymentStatus(appointmentId, !isPaid),
                        icon: Icon(isPaid ? Icons.money_off : Icons.attach_money),
                        label: Text(isPaid ? 'Mark Unpaid' : 'Mark Paid'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isPaid ? Colors.orange : Colors.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _updateAppointmentStatus(appointmentId, 'completed'),
                        icon: const Icon(Icons.check_circle),
                        label: const Text('Complete'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.teal,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.teal),
          const SizedBox(width: 10),
          Text(
            '$label:',
            style: const TextStyle(
              fontWeight: FontWeight.w500,
              fontSize: 14,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}