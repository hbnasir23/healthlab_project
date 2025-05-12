import 'package:flutter/material.dart';
import 'package:modal_bottom_sheet/modal_bottom_sheet.dart';
import '../../constants.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../globals.dart';

class DoctorScreen extends StatefulWidget {
  const DoctorScreen({super.key});

  @override
  State<DoctorScreen> createState() => _DoctorScreenState();
}

class _DoctorScreenState extends State<DoctorScreen> {
  List<Map<String, dynamic>> _doctors = [];
  bool _isLoading = true;
  DateTime _focusedDay = DateTime.now(); // Add this line

  @override
  void initState() {
    super.initState();
    _loadDoctors();
  }

  Future<void> _loadDoctors() async {
    try {
      final doctors = await Supabase.instance.client.from('doctors').select().eq('status', 'approved');
      for (var doctor in doctors) {
        final doctorName =
        await Supabase.instance.client
            .from('users')
            .select('name')
            .eq('id', doctor['user_id'])
            .single();
        doctor['name'] = doctorName['name'];
      }
      setState(() {
        _doctors = doctors;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      print('Error loading doctors: $e');
    }
  }

  Widget _buildDetailRow(String label, String? value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Text(
        "$label: ${value ?? 'N/A'}",
        style: const TextStyle(fontSize: 16, color: Colors.black87),
      ),
    );
  }

  void _showDoctorDetails(Map<String, dynamic> doctor) {
    showCupertinoModalBottomSheet(
      context: context,
      builder: (context) =>
          Material(
            child: SafeArea(
              child: Container(
                padding: const EdgeInsets.all(20),
                height: MediaQuery
                    .of(context)
                    .size
                    .height * 0.75,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Close Button
                      Align(
                        alignment: Alignment.topRight,
                        child: IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ),
                      // Doctor Image
                      Center(
                        child: Container(
                          width: 150,
                          height: 150,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(75),
                            border: Border.all(color: Colors.teal, width: 2),
                            image: doctor['photo'] != null &&
                                doctor['photo'].isNotEmpty
                                ? DecorationImage(
                              image: NetworkImage(doctor['photo']),
                              fit: BoxFit.cover,
                            )
                                : const DecorationImage(
                              image: AssetImage(
                                'assets/images/default_doctor.png',
                              ),
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      // Doctor Details
                      Text(
                        doctor['name'] ?? 'N/A',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.teal,
                        ),
                      ),
                      const SizedBox(height: 10),
                      _buildDetailRow(
                        "Specialization",
                        doctor['specialization'],
                      ),
                      _buildDetailRow("Age", doctor['age']?.toString()),
                      _buildDetailRow("Gender", doctor['gender']),
                      _buildDetailRow(
                        "Experience",
                        "${doctor['experience']} years",
                      ),
                      _buildDetailRow("Area", doctor['area']),
                      _buildDetailRow("Hospital/Clinic", doctor['hospital']),
                      _buildDetailRow(
                        "Consultation Fees",
                        "Rs. ${doctor['fees']}",
                      ),
                      const SizedBox(height: 20),
                      // Action Button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.pop(context);
                            _showDoctorCalendar(doctor);
                          },
                          child: const Text('View Schedule & Book Appointment'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.teal,
                            padding: const EdgeInsets.symmetric(vertical: 15),
                            textStyle: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ),
          ),
    );
  }

  Future<void> _showDoctorCalendar(Map<String, dynamic> doctor) async {
    final doctorId = doctor['user_id'];
    try {
      // Get all available schedules for the doctor
      final schedules = await Supabase.instance.client
          .from('schedule')
          .select()
          .eq('doctor_id', doctorId);

      if (schedules.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No schedules available for this doctor'),
          ),
        );
        return;
      }

      // Create a map of day of week to schedule information
      final Map<String, List<Map<String, dynamic>>> schedulesMap = {};
      for (var schedule in schedules) {
        String dayOfWeek = schedule['day_of_week'];
        if (!schedulesMap.containsKey(dayOfWeek)) {
          schedulesMap[dayOfWeek] = [];
        }
        schedulesMap[dayOfWeek]!.add(schedule);
      }

      // Create a set of days for which the doctor is available
      final Set<int> availableDays = {};
      schedulesMap.forEach((day, _) {
        switch (day.toLowerCase()) {
          case 'monday':
            availableDays.add(DateTime.monday);
            break;
          case 'tuesday':
            availableDays.add(DateTime.tuesday);
            break;
          case 'wednesday':
            availableDays.add(DateTime.wednesday);
            break;
          case 'thursday':
            availableDays.add(DateTime.thursday);
            break;
          case 'friday':
            availableDays.add(DateTime.friday);
            break;
          case 'saturday':
            availableDays.add(DateTime.saturday);
            break;
          case 'sunday':
            availableDays.add(DateTime.sunday);
            break;
        }
      });

      // Show calendar picker
      DateTime? selectedDate;
      DateTime focusedDay = DateTime.now();
      CalendarFormat calendarFormat = CalendarFormat.month;

      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => DraggableScrollableSheet(
          initialChildSize: 0.9,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          builder: (context, scrollController) => Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: 20 + MediaQuery.of(context).viewInsets.bottom,
              ),
              child: StatefulBuilder(
                builder: (context, setState) => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            'Dr. ${doctor['name']} Availability',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.teal,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    const Center(
                      child: Text(
                        'Select an available date to view appointment slots:',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 15),
                    Expanded(
                      child: SingleChildScrollView(
                        controller: scrollController,
                        child: Column(
                          children: [
                            TableCalendar(
                              firstDay: DateTime.now(),
                              lastDay: DateTime.now().add(const Duration(days: 180)), // Extended to 6 months
                              focusedDay: focusedDay,
                              calendarFormat: calendarFormat,
                              selectedDayPredicate: (day) {
                                return selectedDate != null &&
                                    isSameDay(selectedDate!, day);
                              },
                              onDaySelected: (selectedDay, focusedDay) {
                                // Only allow selection if the day is available
                                if (availableDays.contains(selectedDay.weekday)) {
                                  setState(() {
                                    selectedDate = selectedDay;
                                    focusedDay = focusedDay;
                                  });
                                } else {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                          'Doctor is not available on this day'),
                                    ),
                                  );
                                }
                              },
                              onFormatChanged: (format) {
                                if (calendarFormat != format) {
                                  setState(() {
                                    calendarFormat = format;
                                  });
                                }
                              },
                              onPageChanged: (focusedDayNew) {
                                setState(() {
                                  focusedDay = focusedDayNew;
                                });
                              },
                              calendarStyle: CalendarStyle(
                                defaultDecoration: BoxDecoration(
                                  color: Colors.red.withOpacity(0.2),
                                  shape: BoxShape.circle,
                                ),
                                weekendDecoration: BoxDecoration(
                                  color: Colors.red.withOpacity(0.2),
                                  shape: BoxShape.circle,
                                ),
                                outsideDecoration: BoxDecoration(
                                  color: Colors.red.withOpacity(0.2),
                                  shape: BoxShape.circle,
                                ),
                                selectedDecoration: const BoxDecoration(
                                  color: Colors.teal,
                                  shape: BoxShape.circle,
                                ),
                                todayDecoration: BoxDecoration(
                                  color: Colors.teal.withOpacity(0.5),
                                  shape: BoxShape.circle,
                                ),
                                defaultTextStyle: const TextStyle(color: Colors.black),
                                weekendTextStyle: const TextStyle(color: Colors.black),
                              ),
                              calendarBuilders: CalendarBuilders(
                                defaultBuilder: (context, day, focusedDay) {
                                  if (availableDays.contains(day.weekday)) {
                                    return Container(
                                      margin: const EdgeInsets.all(4.0),
                                      alignment: Alignment.center,
                                      decoration: BoxDecoration(
                                        color: AppColors.lightBlue,
                                        shape: BoxShape.circle,
                                      ),
                                      child: Text(
                                        '${day.day}',
                                        style: const TextStyle(color: Colors.black),
                                      ),
                                    );
                                  }
                                  return Container(
                                    margin: const EdgeInsets.all(4.0),
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      color: Colors.red.withOpacity(0.2),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Text(
                                      '${day.day}',
                                      style: const TextStyle(color: Colors.black),
                                    ),
                                  );
                                },
                              ),
                              headerStyle: HeaderStyle(
                                formatButtonVisible: true,
                                titleCentered: true,
                                formatButtonShowsNext: false,
                                leftChevronIcon: const Icon(Icons.chevron_left, color: Colors.teal),
                                rightChevronIcon: const Icon(Icons.chevron_right, color: Colors.teal),
                                titleTextStyle: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.teal,
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),
                            // Add month navigation buttons
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                ElevatedButton.icon(
                                  onPressed: () {
                                    setState(() {
                                      focusedDay = DateTime(
                                        focusedDay.year,
                                        focusedDay.month - 1,
                                        focusedDay.day,
                                      );
                                    });
                                  },
                                  icon: const Icon(Icons.arrow_back),
                                  label: const Text('Previous Month'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.grey[300],
                                    foregroundColor: Colors.black,
                                  ),
                                ),
                                ElevatedButton.icon(
                                  onPressed: () {
                                    setState(() {
                                      focusedDay = DateTime(
                                        focusedDay.year,
                                        focusedDay.month + 1,
                                        focusedDay.day,
                                      );
                                    });
                                  },
                                  icon: const Icon(Icons.arrow_forward),
                                  label: const Text('Next Month'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.teal[100],
                                    foregroundColor: Colors.teal[800],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: selectedDate == null
                            ? null
                            : () {
                          Navigator.pop(context);
                          String selectedDay = '';
                          switch (selectedDate!.weekday) {
                            case DateTime.monday:
                              selectedDay = 'Monday';
                              break;
                            case DateTime.tuesday:
                              selectedDay = 'Tuesday';
                              break;
                            case DateTime.wednesday:
                              selectedDay = 'Wednesday';
                              break;
                            case DateTime.thursday:
                              selectedDay = 'Thursday';
                              break;
                            case DateTime.friday:
                              selectedDay = 'Friday';
                              break;
                            case DateTime.saturday:
                              selectedDay = 'Saturday';
                              break;
                            case DateTime.sunday:
                              selectedDay = 'Sunday';
                              break;
                          }

                          List<Map<String, dynamic>> daySchedules =
                              schedulesMap[selectedDay] ?? [];

                          _showScheduleSlotsForDate(
                              doctor,
                              daySchedules,
                              selectedDate!
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.teal,
                          padding: const EdgeInsets.symmetric(vertical: 15),
                        ),
                        child: const Text(
                          'View Available Slots',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading doctor schedule: $e')),
      );
    }
  }
  void _showScheduleSlotsForDate(Map<String, dynamic> doctor,
      List<Map<String, dynamic>> schedules,
      DateTime selectedDate) {
    // Filter schedules where booked_slots < total_slots
    final availableSchedules = schedules
        .where((slot) => slot['booked_slots'] < slot['total_slots'])
        .toList();

    if (availableSchedules.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No available slots for the selected date'),
        ),
      );
      return;
    }

    Map<String, dynamic>? selectedSlot;
    String? selectedPaymentMethod;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) =>
          StatefulBuilder(
            builder: (context, setState) =>
            Container(
          padding: EdgeInsets.only(
          left: 20,
            right: 20,
            top: 20,
            bottom: 20 + MediaQuery.of(context).viewInsets.bottom,
          ),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.8,
      ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              'Dr. ${doctor['name']} - ${DateFormat(
                                  'EEEE, MMM dd, yyyy').format(selectedDate)}',
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.teal,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Select an appointment slot:',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 15),
                      Expanded(
                        child: SingleChildScrollView(
                          child: Column(
                            children: availableSchedules.map((schedule) {
                              final bool isSelected = selectedSlot != null &&
                                  selectedSlot!['id'] == schedule['id'];

                              // Add the selected date to the schedule for booking
                              schedule['actual_date'] =
                                  DateFormat('yyyy-MM-dd').format(selectedDate);

                              return GestureDetector(
                                onTap: () {
                                  setState(() {
                                    if (isSelected) {
                                      selectedSlot = null;
                                    } else {
                                      selectedSlot = schedule;
                                    }
                                  });
                                },
                                child: Container(
                                  margin: const EdgeInsets.only(bottom: 10),
                                  padding: const EdgeInsets.all(15),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? Colors.teal.withOpacity(0.2)
                                        : Colors.grey.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: isSelected
                                          ? Colors.teal
                                          : Colors.transparent,
                                      width: 2,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.access_time,
                                        color: isSelected ? Colors.teal : Colors
                                            .grey,
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment
                                              .start,
                                          children: [
                                            Text(
                                              '${schedule['shift_name']} (${schedule['start_time']} - ${schedule['end_time']})',
                                              style: TextStyle(
                                                fontSize: 16,
                                                fontWeight: isSelected
                                                    ? FontWeight.bold
                                                    : FontWeight.normal,
                                                color: isSelected
                                                    ? Colors.teal
                                                    : Colors.black87,
                                              ),
                                            ),
                                            const SizedBox(height: 5),
                                            Text(
                                              'Available slots: ${schedule['total_slots'] -
                                                  schedule['booked_slots']}/${schedule['total_slots']}',
                                              style: TextStyle(
                                                fontSize: 14,
                                                color: isSelected
                                                    ? Colors.teal
                                                    : Colors.grey,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      if (isSelected)
                                        const Icon(
                                          Icons.check_circle,
                                          color: Colors.teal,
                                        ),
                                    ],
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ),

                      // Payment method selection section
                      if (selectedSlot != null)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Divider(color: Colors.teal),
                            const SizedBox(height: 10),
                            const Text(
                              'Select Payment Method:',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(
                                  child: GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        selectedPaymentMethod = 'Card';
                                      });
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: selectedPaymentMethod == 'Card'
                                            ? Colors.teal.withOpacity(0.2)
                                            : Colors.grey.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                          color: selectedPaymentMethod == 'Card'
                                              ? Colors.teal
                                              : Colors.transparent,
                                          width: 2,
                                        ),
                                      ),
                                      child: Column(
                                        children: [
                                          Icon(
                                            Icons.credit_card,
                                            color: selectedPaymentMethod ==
                                                'Card'
                                                ? Colors.teal
                                                : Colors.grey,
                                            size: 28,
                                          ),
                                          const SizedBox(height: 5),
                                          Text(
                                            'Card',
                                            style: TextStyle(
                                              color: selectedPaymentMethod ==
                                                  'Card'
                                                  ? Colors.teal
                                                  : Colors.grey[700],
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        selectedPaymentMethod = 'Cash';
                                      });
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: selectedPaymentMethod == 'Cash'
                                            ? Colors.teal.withOpacity(0.2)
                                            : Colors.grey.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                          color: selectedPaymentMethod == 'Cash'
                                              ? Colors.teal
                                              : Colors.transparent,
                                          width: 2,
                                        ),
                                      ),
                                      child: Column(
                                        children: [
                                          Icon(
                                            Icons.money,
                                            color: selectedPaymentMethod ==
                                                'Cash'
                                                ? Colors.teal
                                                : Colors.grey,
                                            size: 28,
                                          ),
                                          const SizedBox(height: 5),
                                          Text(
                                            'Cash',
                                            style: TextStyle(
                                              color: selectedPaymentMethod ==
                                                  'Cash'
                                                  ? Colors.teal
                                                  : Colors.grey[700],
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                          ],
                        ),

                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: selectedSlot == null ||
                              (selectedSlot != null &&
                                  selectedPaymentMethod == null)
                              ? null
                              : () =>
                              _bookAppointment(
                                doctor,
                                selectedSlot!,
                                selectedPaymentMethod!,
                                selectedDate,
                              ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.teal,
                            padding: const EdgeInsets.symmetric(vertical: 15),
                          ),
                          child: const Text(
                            'Book Appointment',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
          ),
    );
  }

  Future<int?> getUserIdByEmail(String email) async {
    final supabase = Supabase.instance.client;
    final response =
    await supabase.from('users').select('id').eq('email', email).single();

    if (response != null) {
      return response['id'];
    } else {
      return null;
    }
  }

  Future<void> _bookAppointment(Map<String, dynamic> doctor,
      Map<String, dynamic> slot,
      String paymentMethod,
      DateTime selectedDate,) async {
    try {
      print("🔹 Booking started...");

      var userId = await getUserIdByEmail(loggedInEmail!);
      print("🔹 User ID: $userId");

      final appointmentId = DateTime
          .now()
          .millisecondsSinceEpoch
          .toString();
      print("🔹 Appointment ID: $appointmentId");

      // Fetch the current slot details
      final currentSlot =
      await Supabase.instance.client
          .from('schedule')
          .select()
          .eq('id', slot['id'])
          .single();

      // Ensure booked_slots and total_slots are integers
      final bookedSlots = int.parse(currentSlot['booked_slots'].toString());
      final totalSlots = int.parse(currentSlot['total_slots'].toString());

      print("🔹 Booked Slots: $bookedSlots");
      print("🔹 Total Slots: $totalSlots");

      // Check if the slot is still available
      if (bookedSlots >= totalSlots) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('This slot is already fully booked.')),
        );
        return;
      }

      // Update booked slots in schedule
      final updateResponse = await Supabase.instance.client
          .from('schedule')
          .update({'booked_slots': bookedSlots + 1})
          .eq('id', slot['id'])
          .gte(
        'total_slots',
        bookedSlots + 1,
      ); // Ensure the slot is still available

      // Format the selected date
      final appointmentDate = DateFormat('yyyy-MM-dd').format(selectedDate);

      // Insert appointment record
      final insertResponse = await Supabase.instance.client
          .from('appointments')
          .insert({
        'appointment_id': appointmentId,
        'user_id': userId,
        'doctor_id': doctor['user_id'],
        'schedule_id': slot['id'],
        'booking_date': DateFormat('yyyy-MM-dd').format(DateTime.now()),
        'appointment_day': slot['day_of_week'],
        'appointment_date': appointmentDate, // Added appointment_date field
        'appointment_time': '${slot['start_time']} - ${slot['end_time']}',
        'shift_name': slot['shift_name'],
        'status': 'pending', // Status is pending until doctor confirms
        'payment_status': 'pending',
        'payment_method': paymentMethod,
        'amount': doctor['fees'],
      });
      print("🔹 Appointment inserted: $insertResponse");

      Navigator.pop(context);
      print("🔹 Modal closed");

      _showAppointmentConfirmation(
        doctor,
        slot,
        appointmentId,
        appointmentDate,
      );
      print("🔹 Confirmation displayed");
    } catch (e) {
      print("❌ Error: $e");
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error booking appointment: $e')));
    }
  }

  void _showAppointmentConfirmation(Map<String, dynamic> doctor,
      Map<String, dynamic> slot,
      String appointmentId,
      String appointmentDate,) {
    showDialog(
      context: context,
      builder: (context) =>
          Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            child: Container(
              padding: const EdgeInsets.all(20),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(15),
                      decoration: BoxDecoration(
                        color: Colors.teal.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check_circle_outline,
                        color: Colors.teal,
                        size: 60,
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Appointment Request Sent!',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.teal,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Your request to book an appointment with Dr. ${doctor['name']} has been sent.',
                      style: const TextStyle(
                        fontSize: 16,
                        color: Colors.black87,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 5),
                    const Text(
                      'The doctor will confirm your appointment within 24 hours.',
                      style: TextStyle(fontSize: 16, color: Colors.black87),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(15),
                      decoration: BoxDecoration(
                        color: Colors.grey.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        children: [
                          _confirmationDetail('Appointment ID', appointmentId),
                          _confirmationDetail(
                            'Date',
                            DateFormat('MMM dd, yyyy').format(
                                DateTime.parse(appointmentDate)
                            ),
                          ),
                          _confirmationDetail(
                            'Time',
                            '${slot['start_time']} - ${slot['end_time']}',
                          ),
                          _confirmationDetail(
                            'Doctor',
                            'Dr. ${doctor['name']}',
                          ),
                          _confirmationDetail('Status', 'Pending Confirmation'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'You will receive a notification once the doctor confirms your appointment.',
                      style: TextStyle(
                        fontSize: 14,
                        fontStyle: FontStyle.italic,
                        color: Colors.grey,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.teal,
                          padding: const EdgeInsets.symmetric(vertical: 15),
                        ),
                        child: const Text(
                          'OK',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
    );
  }

  Widget _confirmationDetail(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              color: Colors.grey,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          SizedBox(height: AppConstants.deviceHeight * .055),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Available Doctors',
                  style: TextStyle(
                    fontSize: AppConstants.deviceWidth * 0.06,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                Image.asset(
                  'assets/images/logo.png',
                  height: AppConstants.deviceHeight * 0.08,
                ),
              ],
            ),
          ),
          _isLoading
              ? const Expanded(
            child: Center(
              child: CircularProgressIndicator(color: Colors.teal),
            ),
          )
              : _doctors.isEmpty
              ? const Expanded(
            child: Center(
              child: Text(
                'No Doctors available',
                style: TextStyle(fontSize: 18, color: Colors.black87),
              ),
            ),
          )
              : Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: .65,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
              ),
              itemCount: _doctors.length,
              itemBuilder: (context, index) {
                final doctor = _doctors[index];
                return GestureDetector(
                  onTap: () => _showDoctorDetails(doctor),
                  child: Card(
                    elevation: 4,
                    shadowColor: Colors.teal.withOpacity(0.3),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Doctor Image
                        Flexible(
                          flex: 3,
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(12),
                              ),
                              image:
                              doctor['photo'] != null &&
                                  doctor['photo'].isNotEmpty
                                  ? DecorationImage(
                                image: NetworkImage(
                                  doctor['photo'],
                                ),
                                fit: BoxFit.cover,
                              )
                                  : const DecorationImage(
                                image: AssetImage(
                                  'assets/images/default_doctor.png',
                                ),
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                        ),
                        // Doctor Info
                        Expanded(
                          flex: 2,
                          child: Container(
                            padding: const EdgeInsets.fromLTRB(
                              12,
                              12,
                              12,
                              8,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  doctor['name'] ?? 'N/A',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.teal,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  doctor['specialization'] ?? 'N/A',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.black87,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  "${doctor['area']} ",
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.teal,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        // View Button
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}