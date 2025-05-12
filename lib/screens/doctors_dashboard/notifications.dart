import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../constants.dart';
import '../../globals.dart';


class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({Key? key}) : super(key: key);

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<Map<String, dynamic>> _pendingAppointments = [];
  bool _isLoading = true;
  String _errorMessage = '';
  final _supabase = Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    _fetchPendingAppointments();
  }
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


  Future<void> _fetchPendingAppointments() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final doctorId = await getUserIdByEmail(loggedInEmail!);

      final response = await _supabase
          .from('appointments')
          .select('*, patient:user_id(*)')
          .eq('doctor_id', doctorId!)
          .eq('status', 'pending')
          .order('booking_date', ascending: false);

      setState(() {
        _pendingAppointments = List<Map<String, dynamic>>.from(response);
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error: $e';
        _isLoading = false;
      });
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
          content: Text('Appointment ${status == 'confirmed' ? 'accepted' : 'rejected'} successfully'),
          backgroundColor: status == 'confirmed' ? Colors.green : Colors.red,
        ),
      );

      // Refresh the list
      _fetchPendingAppointments();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Colors.white,
        toolbarHeight: AppConstants.deviceHeight*.1,

        title: Padding(
          padding: EdgeInsets.only(top: 10.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'New Appointments',
                style: TextStyle(
                  fontSize: AppConstants.deviceWidth * 0.07,
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
        iconTheme: const IconThemeData(color: AppColors.teal),
        elevation: 0, // Optional: Removes shadow for a clean UI
      ),

      body: RefreshIndicator(
        onRefresh: _fetchPendingAppointments,
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage.isNotEmpty) {
      return Center(child: Text(_errorMessage, style: TextStyle(color: Colors.red)));
    }

    if (_pendingAppointments.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.calendar_today, size: 60, color: AppColors.lightBlue),
            const SizedBox(height: 16),
            Text(
              'No New appointments',
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
      itemCount: _pendingAppointments.length,
      itemBuilder: (context, index) {
        final appointment = _pendingAppointments[index];
        final appointmentId = appointment['appointment_id'] ?? -1;
        final patientName = appointment['patient']?['name'] ?? 'Unknown Patient';
        final bookingDate = DateTime.parse(appointment['booking_date'] ?? DateTime.now().toString());
        final formattedDate = DateFormat('MMM dd, yyyy').format(bookingDate);
        final appointmentTime = appointment['appointment_time'] ?? 'N/A';

        return _buildNotificationCard(
          patientName: patientName,
          appointmentDate: formattedDate,
          appointmentTime: appointmentTime,
          appointmentDay: appointment['appointment_day'] ?? 'N/A',
          amount: appointment['amount']?.toString() ?? '0',
          paymentMethod: appointment['payment_method'] ?? 'N/A',
          shiftName: appointment['shift_name'] ?? 'N/A',
          appointmentId: appointmentId,
        );
      },
    );
  }

  Widget _buildNotificationCard({
    required String patientName,
    required String appointmentDate,
    required String appointmentTime,
    required String appointmentDay,
    required String amount,
    required String paymentMethod,
    required String shiftName,
    required String appointmentId,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: AppColors.teal.withOpacity(0.3), width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: AppColors.teal.withOpacity(0.2),
                  child: Icon(Icons.person, color: AppColors.teal),
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
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        appointmentDate,
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.teal.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Pending',
                    style: TextStyle(
                      color: AppColors.teal,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),
            _buildInfoRow(Icons.access_time, 'Time', appointmentTime),
            _buildInfoRow(Icons.calendar_today, 'Day', appointmentDay),
            _buildInfoRow(Icons.payment, 'Amount', 'Rs. $amount'),
            _buildInfoRow(Icons.credit_card, 'Payment', paymentMethod),
            _buildInfoRow(Icons.schedule, 'Shift', shiftName),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _updateAppointmentStatus(appointmentId, 'rejected'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Reject'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _updateAppointmentStatus(appointmentId, 'confirmed'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.teal,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Accept'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey[600]),
          const SizedBox(width: 8),
          Text(
            '$label:',
            style: TextStyle(
              fontWeight: FontWeight.w500,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(width: 4),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}