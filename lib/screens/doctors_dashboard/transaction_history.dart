import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../constants.dart';

class PaymentDetailsScreen extends StatefulWidget {
  @override
  _PaymentDetailsScreenState createState() => _PaymentDetailsScreenState();
}

class _PaymentDetailsScreenState extends State<PaymentDetailsScreen> {
  final SupabaseClient supabase = Supabase.instance.client;
  List<Map<String, dynamic>> appointments = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchAppointments();
  }

  // Fetch appointments and join with users table to get user names
  Future<void> fetchAppointments() async {
    try {
      final response = await supabase
          .from('appointments')
          .select('*, users (name)') // Join with users table
          .order('appointment_date', ascending: false);
      print('response: $response');
      // Filter appointments where payment_status is 'paid'
      final paidAppointments = (response as List<dynamic>)
          .where((appointment) => appointment['payment_status'] == 'paid')
          .toList();
      print('paidAppointments: $paidAppointments');
      setState(() {
        appointments = List<Map<String, dynamic>>.from(paidAppointments);
        isLoading = false;
      });
    } catch (e) {
      print('Error fetching appointments: $e');
      setState(() {
        isLoading = false;
      });
    }
  }

  // Calculate total revenue from paid appointments
  double getTotalRevenue() {
    return appointments.fold(0, (sum, appointment) => sum + (appointment['amount'] as int));
  }

  // Calculate 10% monthly payment to admin
  double getMonthlyPaymentToAdmin() {
    return getTotalRevenue() * 0.10;
  }

  // Calculate weekly revenue from paid appointments
  double getWeeklyRevenue() {
    final now = DateTime.now();
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
    final endOfWeek = startOfWeek.add(Duration(days: 6));

    return appointments.fold(0, (sum, appointment) {
      final appointmentDate = DateTime.parse(appointment['appointment_date']);
      if (appointmentDate.isAfter(startOfWeek) && appointmentDate.isBefore(endOfWeek)) {
        return sum + (appointment['amount'] as int);
      }
      return sum;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Payment Details'),
        backgroundColor: AppColors.lightBlue,
      ),
      body: isLoading
          ? Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Revenue Overview Section
            Text('Revenue Overview', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.teal)),
            SizedBox(height: 16),
            _buildRevenueChart(),
            SizedBox(height: 24),

            // Payment Details Section
            Text('Payment Details', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.teal)),
            SizedBox(height: 16),
            ...appointments.map((appointment) => _buildPaymentCard(appointment)).toList(),

            // Admin Payment Section
            SizedBox(height: 24),
            Text('Admin Payment', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.teal)),
            SizedBox(height: 16),
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.lightBlue.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('10% Monthly Payment to Admin', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  SizedBox(height: 8),
                  Text('Amount: Rs. ${getMonthlyPaymentToAdmin().toStringAsFixed(2)}', style: TextStyle(fontSize: 14)),
                  Text('Due Date: 1st of Every Month', style: TextStyle(fontSize: 14)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Revenue Chart
  Widget _buildRevenueChart() {
    return SizedBox(
      height: 200,
      child: LineChart(
        LineChartData(
          lineBarsData: [
            LineChartBarData(
              spots: [
                FlSpot(0, 3),
                FlSpot(1, 5),
                FlSpot(2, 4),
                FlSpot(3, 7),
                FlSpot(4, 6),
              ],
              isCurved: true,
              color: AppColors.teal,
              dotData: FlDotData(show: false),
              belowBarData: BarAreaData(show: true, color: AppColors.teal.withOpacity(0.3)),
            )],
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(show: false),
          gridData: FlGridData(show: false),
        ),
      ),
    );
  }

  // Payment Card for Each Appointment

  Widget _buildPaymentCard(Map<String, dynamic> appointment) {
    final user = appointment['users'] as Map<String, dynamic>?;
    final userName = user?['name'] ?? 'Unknown User';

    return Card(
      margin: EdgeInsets.symmetric(vertical: 8),
      color: AppColors.lightBlue.withOpacity(0.1),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Appointment ID: ${appointment['appointment_id']}', style: TextStyle(fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            Text('User: $userName'),
            Text('Amount: Rs. ${appointment['amount']}'),
            Text('Payment Status: ${appointment['payment_status']}'),
            Text('Date: ${appointment['appointment_date']}'),
          ],
        ),
      ),
    );
  }
}