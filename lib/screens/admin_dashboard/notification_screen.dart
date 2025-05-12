import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../../constants.dart';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({Key? key}) : super(key: key);

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  final _supabase = Supabase.instance.client;
  bool _showAppointments = true;
  List<Map<String, dynamic>> _orderNotifications = [];
  List<Map<String, dynamic>> _appointmentNotifications = [];
  bool _isLoading = true;

  // Statistics maps
  Map<String, int> _doctorAppointmentCounts = {};
  Map<String, double> _doctorAmountTotals = {}; // Added for doctor earnings
  int _todayAppointments = 0;
  int _weeklyAppointments = 0;
  double _totalAppointmentAmount = 0; // Added for total appointment amount

  // Order statistics
  int _todayOrders = 0;
  int _weeklyOrders = 0;
  double _todayOrderAmount = 0;
  double _weeklyOrderAmount = 0;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);

    try {
      // Fetch orders with user information
      final orderResponse = await _supabase
          .from('orders')
          .select('*, users:user_id(id, name, email)')
          .order('timeoforder', ascending: false);

      // Fetch appointments with doctor and user information
      final appointmentResponse = await _supabase
          .from('appointments')
          .select('''
            *,
            patient:user_id(id, name, email),
            doctor:doctor_id(user_id),
            schedule:schedule_id(*)
          ''')
          .order('booking_date', ascending: false);

      // For each appointment, fetch the doctor's name from users table
      final appointmentsWithDoctorInfo = await Future.wait(
          List<Map<String, dynamic>>.from(appointmentResponse).map((appointment) async {
            if (appointment['doctor'] != null && appointment['doctor']['user_id'] != null) {
              final doctorUserId = appointment['doctor']['user_id'];
              final doctorInfo = await _supabase
                  .from('users')
                  .select('name, email')
                  .eq('id', doctorUserId)
                  .single();

              appointment['doctor_name'] = doctorInfo['name'];
              appointment['doctor_email'] = doctorInfo['email'];
            } else {
              appointment['doctor_name'] = 'Unknown Doctor';
              appointment['doctor_email'] = '';
            }

            return appointment;
          })
      );

      // Calculate statistics
      _calculateAppointmentStatistics(appointmentsWithDoctorInfo);
      _calculateOrderStatistics(List<Map<String, dynamic>>.from(orderResponse));

      setState(() {
        _orderNotifications = List<Map<String, dynamic>>.from(orderResponse);
        _appointmentNotifications = appointmentsWithDoctorInfo;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error fetching notifications: $e')),
      );
    }
  }

  void _calculateAppointmentStatistics(List<Map<String, dynamic>> appointments) {
    // Reset counts
    _doctorAppointmentCounts = {};
    _doctorAmountTotals = {}; // Reset doctor amount totals
    _todayAppointments = 0;
    _weeklyAppointments = 0;
    _totalAppointmentAmount = 0; // Reset total appointment amount

    // Get current date
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final startOfWeek = today.subtract(Duration(days: today.weekday - 1));
    final endOfWeek = startOfWeek.add(const Duration(days: 6));

    for (var appointment in appointments) {
      // Count by doctor
      final doctorName = appointment['doctor_name'] ?? 'Unknown Doctor';

      // Only include confirmed appointments in financial calculations
      final status = appointment['status']?.toString().toLowerCase() ?? '';
      final isConfirmed = status == 'confirmed' || status == 'completed';

      // Count appointments by doctor
      if (_doctorAppointmentCounts.containsKey(doctorName)) {
        _doctorAppointmentCounts[doctorName] = _doctorAppointmentCounts[doctorName]! + 1;
      } else {
        _doctorAppointmentCounts[doctorName] = 1;
      }

      // Sum amount by doctor - ONLY for confirmed appointments
      if (isConfirmed) {
        final amount = double.tryParse(appointment['amount']?.toString() ?? '0') ?? 0.0;
        if (_doctorAmountTotals.containsKey(doctorName)) {
          _doctorAmountTotals[doctorName] = _doctorAmountTotals[doctorName]! + amount;
        } else {
          _doctorAmountTotals[doctorName] = amount;
        }

        // Add to total appointment amount
        _totalAppointmentAmount += amount;
      }

      // Count today's appointments
      if (appointment['booking_date'] != null) {
        final bookingDate = DateTime.parse(appointment['booking_date']);
        final appointmentDate = DateTime(bookingDate.year, bookingDate.month, bookingDate.day);

        if (appointmentDate.isAtSameMomentAs(today)) {
          _todayAppointments++;
        }

        // Count this week's appointments
        if (appointmentDate.isAfter(startOfWeek.subtract(const Duration(days: 1))) &&
            appointmentDate.isBefore(endOfWeek.add(const Duration(days: 1)))) {
          _weeklyAppointments++;
        }
      }
    }
  }

  void _calculateOrderStatistics(List<Map<String, dynamic>> orders) {
    // Reset counts
    _todayOrders = 0;
    _weeklyOrders = 0;
    _todayOrderAmount = 0;
    _weeklyOrderAmount = 0;

    // Get current date
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final startOfWeek = today.subtract(Duration(days: today.weekday - 1));
    final endOfWeek = startOfWeek.add(const Duration(days: 6));

    for (var order in orders) {
      final amount = double.tryParse(order['total_amount']?.toString() ?? '0') ?? 0.0;

      if (order['timeoforder'] != null) {
        final orderDate = DateTime.parse(order['timeoforder']);
        final orderDay = DateTime(orderDate.year, orderDate.month, orderDate.day);

        if (orderDay.isAtSameMomentAs(today)) {
          _todayOrders++;
          _todayOrderAmount += amount;
        }

        // Count this week's orders
        if (orderDay.isAfter(startOfWeek.subtract(const Duration(days: 1))) &&
            orderDay.isBefore(endOfWeek.add(const Duration(days: 1)))) {
          _weeklyOrders++;
          _weeklyOrderAmount += amount;
        }
      }
    }
  }

  Future<void> _deleteAppointment(String appointmentId) async {
    try {
      await _supabase
          .from('appointments')
          .delete()
          .eq('appointment_id', appointmentId);

      // Remove from local list and refresh stats
      setState(() {
        _appointmentNotifications.removeWhere((a) => a['appointment_id'] == appointmentId);
        _calculateAppointmentStatistics(_appointmentNotifications);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Appointment deleted successfully')),
      );
      setState(() {
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error deleting appointment: $e')),
      );
    }
  }

  Future<void> _confirmDelete(String appointmentId) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirm Delete'),
          content: const Text('Are you sure you want to delete this appointment?'),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text('Delete', style: TextStyle(color: Colors.red)),
              onPressed: () {
                Navigator.of(context).pop();
                _deleteAppointment(appointmentId);
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Notifications',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Image.asset(
                      'assets/images/logo.png',
                      height: 50,
                    ),
                  ],
                ),
              ),
              if (!_isLoading)
                _showAppointments
                    ? _buildAppointmentStatsSummary()
                    : _buildOrderStatsSummary(),
              Container(
                width: AppConstants.deviceWidth,
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                color: AppColors.teal.withOpacity(0.1),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildSwitchButton(
                      title: 'Appointments',
                      isActive: _showAppointments,
                      onTap: () => setState(() => _showAppointments = true),
                    ),
                    const SizedBox(width: 16),
                    _buildSwitchButton(
                      title: 'Orders',
                      isActive: !_showAppointments,
                      onTap: () => setState(() => _showAppointments = false),
                    ),
                  ],
                ),
              ),
              _isLoading
                  ? Container(
                height: AppConstants.deviceHeight * 0.5,
                alignment: Alignment.center,
                child: const CircularProgressIndicator(color: AppColors.teal),
              )
                  : _showAppointments
                  ? _buildAppointmentListNonScrollable()
                  : _buildOrderListNonScrollable(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOrderStatsSummary() {
    final formatCurrency = NumberFormat.currency(symbol: 'Rs. ', decimalDigits: 0);

    return Container(
      width: AppConstants.deviceWidth,
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Order Summary',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: AppColors.teal,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildStatCard(
                'Today',
                '$_todayOrders',
                Icons.today,
                AppColors.lightBlue,
                formatCurrency.format(_todayOrderAmount),
              ),
              const SizedBox(width: 8),
              _buildStatCard(
                'This Week',
                '$_weeklyOrders',
                Icons.date_range,
                AppColors.teal,
                formatCurrency.format(_weeklyOrderAmount),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Total Orders: ${_orderNotifications.length}',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppointmentStatsSummary() {
    final formatCurrency = NumberFormat.currency(symbol: 'Rs. ', decimalDigits: 0);

    return Container(
      width: AppConstants.deviceWidth,
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Appointment Summary',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: AppColors.teal,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildStatCard(
                'Today',
                _todayAppointments.toString(),
                Icons.today,
                AppColors.teal,
              ),
              const SizedBox(width: 8),
              _buildStatCard(
                'This Week',
                _weeklyAppointments.toString(),
                Icons.date_range,
                AppColors.lightBlue,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.teal.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Total Revenue (Confirmed)',
                        style: TextStyle(
                          color: Colors.grey[700],
                          fontSize: 12,
                        ),
                      ),
                      Text(
                        formatCurrency.format(_totalAppointmentAmount),
                        style: TextStyle(
                          color: AppColors.teal,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'Appointments by Doctor',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _doctorAppointmentCounts.entries.map((entry) {
              final doctorAmount = _doctorAmountTotals[entry.key] ?? 0;
              return _buildDoctorStatChip(
                'Dr. ${entry.key.split(' ').first}',
                entry.value.toString(),
                formatCurrency.format(doctorAmount),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String count, IconData icon, Color color, [String? amount]) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: Colors.grey[700],
                      fontSize: 12,
                    ),
                  ),
                  Text(
                    count,
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                  if (amount != null)
                    Text(
                      amount,
                      style: TextStyle(
                        color: color.withOpacity(0.8),
                        fontWeight: FontWeight.w500,
                        fontSize: 12,
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

  Widget _buildDoctorStatChip(String doctorName, String count, String amount) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.lightBlue.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.lightBlue.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                doctorName,
                style: TextStyle(
                  color: Colors.grey[800],
                  fontSize: 12,
                ),
              ),
              Text(
                amount,
                style: TextStyle(
                  color: AppColors.teal,
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(width: 4),
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: AppColors.teal,
              shape: BoxShape.circle,
            ),
            child: Text(
              count,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSwitchButton({
    required String title,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        decoration: BoxDecoration(
          color: isActive ? AppColors.teal : AppColors.lightBlue,
          borderRadius: BorderRadius.circular(25),
          boxShadow: isActive
              ? [
            BoxShadow(
              color: AppColors.teal.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 3),
            )
          ]
              : null,
        ),
        child: Text(
          title,
          style: TextStyle(
            color: isActive ? Colors.white : Colors.black87,
            fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
            fontSize: 15,
          ),
        ),
      ),
    );
  }

  Widget _buildOrderListNonScrollable() {
    if (_orderNotifications.isEmpty) {
      return Container(
        height: AppConstants.deviceHeight * 0.5,
        alignment: Alignment.center,
        child: const Text('No order notifications'),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      itemCount: _orderNotifications.length,
      itemBuilder: (context, index) {
        final order = _orderNotifications[index];
        final items = List<Map<String, dynamic>>.from(order['items'] ?? []);
        final userName = order['users']?['name'] ?? 'Unknown User';
        final timestamp = DateTime.parse(order['timeoforder']);
        final formattedDate = DateFormat('MMM dd, yyyy • hh:mm a').format(timestamp);
        final paymentType = order['payment_type'] ?? 'N/A';

        return _buildNotificationCard(
          title: 'New Order',
          subtitle: 'Order #${order['id']} - $userName',
          date: formattedDate,
          details: [
            'Total: Rs. ${order['total_amount']}',
            'Payment: $paymentType',
            'Items: ${items.map((item) => '${item['name']} x${item['quantity']}').join(', ')}',
          ],
          color: AppColors.teal,
          isPending: false,
        );
      },
    );
  }

  Widget _buildAppointmentListNonScrollable() {
    if (_appointmentNotifications.isEmpty) {
      return Container(
        height: AppConstants.deviceHeight * 0.5,
        alignment: Alignment.center,
        child: const Text('No appointment notifications'),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      itemCount: _appointmentNotifications.length,
      itemBuilder: (context, index) {
        final appointment = _appointmentNotifications[index];

        // Make sure id is not null, use a default if it is
        final appointmentId = appointment['appointment_id'] ;
        // Only offer delete if ID is valid
        final canDelete = appointmentId != -1;

        final patientName = appointment['patient']?['name'] ?? 'Unknown Patient';
        final doctorName = appointment['doctor_name'] ?? 'Unknown Doctor';
        final bookingDate = DateTime.parse(appointment['booking_date'] ?? DateTime.now().toString());
        final formattedDate = DateFormat('MMM dd, yyyy').format(bookingDate);
        final appointmentTime = appointment['appointment_time'] ?? 'N/A';
        final status = appointment['status'] ?? 'N/A';
        final isPending = status.toLowerCase() == 'pending';

        // Show payment status based on confirmation
        final isConfirmed = status.toLowerCase() == 'confirmed' || status.toLowerCase() == 'completed';
        final amountDisplay = isConfirmed
            ? 'Amount: Rs. ${appointment['amount']}'
            : 'Amount: Rs. ${appointment['amount']} (Pending)';

        return _buildNotificationCard(
          title: 'New Appointment',
          subtitle: '$patientName with Dr. $doctorName',
          date: formattedDate,
          details: [
            'Time: $appointmentTime',
            'Day: ${appointment['appointment_day'] ?? 'N/A'}',
            'Status: $status',
            amountDisplay,
            'Payment: ${appointment['payment_method'] ?? 'N/A'}',
            'Shift: ${appointment['shift_name'] ?? 'N/A'}'
          ],
          color: AppColors.teal,
          isPending: isPending,
          id: appointmentId,
          onDelete: canDelete ? () => _confirmDelete(appointmentId) : null,
        );
      },
    );
  }

  Widget _buildNotificationCard({
    required String title,
    required String subtitle,
    required String date,
    required List<String> details,
    required Color color,
    required bool isPending,
    String? id,
    VoidCallback? onDelete,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: isPending
            ? Border.all(color: Colors.red, width: 2)
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isPending
                  ? Colors.red.withOpacity(0.1)
                  : color.withOpacity(0.1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Icon(
                        _showAppointments ? Icons.calendar_today : Icons.shopping_bag,
                        color: isPending ? Colors.red : color,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        title,
                        style: TextStyle(
                          color: isPending ? Colors.red : color,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      if (isPending) ...[
                        const SizedBox(width: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'Pending',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Text(
                  date,
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 12),
                ...details.map((detail) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    detail,
                    style: TextStyle(
                      color: Colors.grey[700],
                      fontSize: 14,
                    ),
                  ),
                )),
              ],
            ),
          ),
          if (onDelete != null) ...[
            Container(
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 16, bottom: 12),
              child: ElevatedButton.icon(
                onPressed: onDelete,
                icon: const Icon(Icons.delete, color: Colors.white, size: 16),
                label: const Text('Delete'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}