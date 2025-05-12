import 'package:flutter/material.dart';
import 'package:healthlab/globals.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:table_calendar/table_calendar.dart';
import '../../../constants.dart';
import 'package:intl/intl.dart';

class DoctorScheduleScreen extends StatefulWidget {
  const DoctorScheduleScreen({super.key});

  @override
  DoctorScheduleScreenState createState() => DoctorScheduleScreenState();
}

class DoctorScheduleScreenState extends State<DoctorScheduleScreen> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  List<Map<String, dynamic>> _schedules = [];
  List<Map<String, dynamic>> _activeSchedules = [];

  // Calendar format
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  // Time slots for weekly schedule
  final Map<String, Map<String, dynamic>> _weeklyShifts = {
    'Morning': {
      'selected': false,
      'startTime': null,
      'endTime': null,
      'totalSlots': 4,
      'bookedSlots': 0,
      'description': '8:00 AM - 12:00 PM',
    },
    'Afternoon': {
      'selected': false,
      'startTime': null,
      'endTime': null,
      'totalSlots': 4,
      'bookedSlots': 0,
      'description': '12:00 PM - 4:00 PM',
    },
    'Evening': {
      'selected': false,
      'startTime': null,
      'endTime': null,
      'totalSlots': 4,
      'bookedSlots': 0,
      'description': '4:00 PM - 8:00 PM',
    },
    'Night': {
      'selected': false,
      'startTime': null,
      'endTime': null,
      'totalSlots': 4,
      'bookedSlots': 0,
      'description': '8:00 PM - 12:00 AM',
    },
  };

  // Days of the week
  final List<String> _daysOfWeek = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];

  // For new schedule
  List<String> _selectedDays = [];
  int _editingScheduleIndex = -1;

  final DateFormat _dateFormatter = DateFormat('yyyy-MM-dd');

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

  @override
  void initState() {
    super.initState();
    _fetchSchedule();
  }

  // Fetch existing schedule from Supabase
  Future<void> _fetchSchedule() async {
    setState(() => _isLoading = true);

    try {
      final doctorId = await getUserIdByEmail(loggedInEmail!);
      if (doctorId == null) {
        setState(() => _isLoading = false);
        return;
      }

      final response = await _supabase
          .from('schedule')
          .select()
          .eq('doctor_id', doctorId)
          .order('day_of_week', ascending: true);

      if (response.isNotEmpty) {
        setState(() {
          _schedules = List<Map<String, dynamic>>.from(response);
          _organizeSchedules();
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error fetching schedule: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _organizeSchedules() {
    // Group schedules by day
    Map<String, List<Map<String, dynamic>>> schedulesByDay = {};

    for (var schedule in _schedules) {
      String day = schedule['day_of_week'] ?? '';

      if (!schedulesByDay.containsKey(day)) {
        schedulesByDay[day] = [];
      }
      schedulesByDay[day]!.add(schedule);
    }

    // Create active schedules list for display
    _activeSchedules = [];
    schedulesByDay.forEach((day, schedules) {
      _activeSchedules.add({
        'day_of_week': day,
        'schedules': schedules,
      });
    });
  }

  // Save schedule to Supabase
  Future<void> _saveSchedule() async {
    try {
      final doctorId = await getUserIdByEmail(loggedInEmail!);
      if (doctorId == null) return;

      // Insert new schedule
      List<Map<String, dynamic>> newSchedules = [];

      for (var day in _selectedDays) {
        for (var entry in _weeklyShifts.entries) {
          final shiftName = entry.key;
          final shift = entry.value;

          if (shift['selected'] &&
              shift['startTime'] != null &&
              shift['endTime'] != null) {
            newSchedules.add({
              'doctor_id': doctorId,
              'day_of_week': day,
              'shift_name': shiftName,
              'start_time': '${shift['startTime']}:00',
              'end_time': '${shift['endTime']}:00',
              'total_slots': shift['totalSlots'],
              'booked_slots': shift['bookedSlots'],
            });
          }
        }
      }

      if (newSchedules.isNotEmpty) {
        await _supabase.from('schedule').insert(newSchedules);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Schedule saved successfully!')),
        );

        // Refresh schedules
        await _fetchSchedule();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving schedule: $e')),
      );
    }
  }

  // Edit existing schedule
  Future<void> _updateSchedule(int index) async {
    if (index < 0 || index >= _activeSchedules.length) return;

    try {
      final doctorId = await getUserIdByEmail(loggedInEmail!);
      if (doctorId == null) return;

      // Get all schedule IDs in this day
      List<Map<String, dynamic>> schedulesToUpdate = _activeSchedules[index]['schedules'];
      List<int> scheduleIds = schedulesToUpdate.map<int>((s) => s['id'] as int).toList();

      // Delete existing schedule entries
      await _supabase.from('schedule').delete().inFilter('id', scheduleIds);

      // Create updated schedules
      List<Map<String, dynamic>> updatedSchedules = [];

      for (var day in _selectedDays) {
        for (var entry in _weeklyShifts.entries) {
          final shiftName = entry.key;
          final shift = entry.value;

          if (shift['selected'] &&
              shift['startTime'] != null &&
              shift['endTime'] != null) {
            updatedSchedules.add({
              'doctor_id': doctorId,
              'day_of_week': day,
              'shift_name': shiftName,
              'start_time': '${shift['startTime']}:00',
              'end_time': '${shift['endTime']}:00',
              'total_slots': shift['totalSlots'],
              'booked_slots': shift['bookedSlots'],
            });
          }
        }
      }

      if (updatedSchedules.isNotEmpty) {
        await _supabase.from('schedule').insert(updatedSchedules);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Schedule updated successfully!')),
        );

        // Refresh schedules
        await _fetchSchedule();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating schedule: $e')),
      );
    }
  }

  // Delete schedule
  Future<void> _deleteSchedule(int index) async {
    if (index < 0 || index >= _activeSchedules.length) return;

    try {
      // Get all schedule IDs in this day
      List<Map<String, dynamic>> schedulesToDelete = _activeSchedules[index]['schedules'];
      List<int> scheduleIds = schedulesToDelete.map<int>((s) => s['id'] as int).toList();

      // Delete existing schedule entries
      await _supabase.from('schedule').delete().inFilter('id', scheduleIds);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Schedule deleted successfully!')),
      );

      // Refresh schedules
      await _fetchSchedule();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error deleting schedule: $e')),
      );
    }
  }

  // Function to show time picker
  Future<void> _selectTime(
      BuildContext context,
      bool isStartTime,
      String shiftName,
      ) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );

    if (picked != null) {
      setState(() {
        // Format time as a string in HH:MM format
        final hour = picked.hour.toString().padLeft(2, '0');
        final minute = picked.minute.toString().padLeft(2, '0');
        final timeString = '$hour:$minute';

        if (isStartTime) {
          _weeklyShifts[shiftName]!['startTime'] = timeString;
        } else {
          _weeklyShifts[shiftName]!['endTime'] = timeString;
        }
      });
    }
  }

  // Reset form for new schedule
  void _resetScheduleForm() {
    setState(() {
      _selectedDays = [];
      _editingScheduleIndex = -1;

      // Reset shifts
      for (var entry in _weeklyShifts.entries) {
        _weeklyShifts[entry.key]!['selected'] = false;
        _weeklyShifts[entry.key]!['startTime'] = null;
        _weeklyShifts[entry.key]!['endTime'] = null;
        _weeklyShifts[entry.key]!['totalSlots'] = 4;
        _weeklyShifts[entry.key]!['bookedSlots'] = 0;
      }
    });
  }

  // Load existing schedule data for editing
  void _loadScheduleData(int index) {
    if (index < 0 || index >= _activeSchedules.length) return;

    final scheduleGroup = _activeSchedules[index];
    final schedules = scheduleGroup['schedules'];

    // Reset form first
    _resetScheduleForm();

    setState(() {
      _editingScheduleIndex = index;

      // Set selected days
      Set<String> days = {};
      for (var schedule in schedules) {
        days.add(schedule['day_of_week']);
      }
      _selectedDays = days.toList();

      // Set shift data
      for (var schedule in schedules) {
        final shiftName = schedule['shift_name'];

        if (_weeklyShifts.containsKey(shiftName)) {
          _weeklyShifts[shiftName]!['selected'] = true;

          // Ensure time is properly formatted and handles null values
          final startTime = schedule['start_time'] ?? '00:00:00';
          final endTime = schedule['end_time'] ?? '00:00:00';

          _weeklyShifts[shiftName]!['startTime'] = startTime.substring(0, 5);
          _weeklyShifts[shiftName]!['endTime'] = endTime.substring(0, 5);
          _weeklyShifts[shiftName]!['totalSlots'] = schedule['total_slots'];
          _weeklyShifts[shiftName]!['bookedSlots'] = schedule['booked_slots'];
        }
      }
    });
  }

  // Helper function to format TimeOfDay for display
  String _formatTime(dynamic time) {
    if (time == null) return 'Not set';
    if (time is String) return time.substring(0, 5); // Extract HH:MM
    return time.toString();
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
                'Doctor Schedule',
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
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(
        child: CircularProgressIndicator(color: AppColors.teal),
      )
          : _activeSchedules.isEmpty
          ? _buildEmptyScheduleView()
          : _buildScheduleView(),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          _resetScheduleForm();
          _showAddScheduleDialog();
        },
        backgroundColor: AppColors.teal,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildEmptyScheduleView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.calendar_today,
            size: AppConstants.deviceWidth * 0.2,
            color: AppColors.lightBlue,
          ),
          SizedBox(height: AppConstants.deviceHeight * 0.02),
          Text(
            "You haven't set your schedule yet",
            style: TextStyle(
              fontSize: AppConstants.deviceWidth * 0.05,
              fontWeight: FontWeight.bold,
              color: AppColors.teal,
            ),
          ),
          SizedBox(height: AppConstants.deviceHeight * 0.02),
          Text(
            "Add your availability by tapping the + button",
            style: TextStyle(
              fontSize: AppConstants.deviceWidth * 0.04,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScheduleView() {
    return ListView(
      padding: EdgeInsets.all(AppConstants.deviceWidth * 0.04),
      children: [
        // Summary card
        Container(
          padding: EdgeInsets.all(AppConstants.deviceWidth * 0.04),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [AppColors.teal, AppColors.lightBlue],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.3),
                spreadRadius: 2,
                blurRadius: 5,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Your Schedule',
                    style: TextStyle(
                      fontSize: AppConstants.deviceWidth * 0.05,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: AppConstants.deviceWidth * 0.02,
                      vertical: AppConstants.deviceHeight * 0.005,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.calendar_today,
                          size: AppConstants.deviceWidth * 0.04,
                          color: AppColors.teal,
                        ),
                        SizedBox(width: AppConstants.deviceWidth * 0.01),
                        Text(
                          '${_activeSchedules.length} schedules',
                          style: TextStyle(
                            fontSize: AppConstants.deviceWidth * 0.03,
                            fontWeight: FontWeight.bold,
                            color: AppColors.teal,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: AppConstants.deviceHeight * 0.01),
              Text(
                'Tap on a schedule to view details',
                style: TextStyle(
                  fontSize: AppConstants.deviceWidth * 0.035,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: AppConstants.deviceHeight * 0.02),

        // Statistics row
        Row(
          children: [
            _buildStatCard(
              'Total Schedules',
              '${_activeSchedules.length}',
              Icons.calendar_month,
              AppColors.teal,
            ),
            SizedBox(width: AppConstants.deviceWidth * 0.02),
            _buildStatCard(
              'Total Shifts',
              '${_schedules.length}',
              Icons.access_time,
              AppColors.lightBlue,
            ),
            SizedBox(width: AppConstants.deviceWidth * 0.02),
            _buildStatCard(
              'Booked Slots',
              '${_schedules.fold(0, (sum, item) => sum + (item['booked_slots'] as int))}',
              Icons.people,
              Colors.orange,
            ),
          ],
        ),
        SizedBox(height: AppConstants.deviceHeight * 0.02),

        // Schedule cards
        ...List.generate(_activeSchedules.length, (index) {
          final scheduleGroup = _activeSchedules[index];
          final schedules = scheduleGroup['schedules'];

          // Group schedules by day
          Map<String, List<Map<String, dynamic>>> schedulesByDay = {};
          for (var schedule in schedules) {
            final day = schedule['day_of_week'];
            if (!schedulesByDay.containsKey(day)) {
              schedulesByDay[day] = [];
            }
            schedulesByDay[day]!.add(schedule);
          }

          // Count total slots and booked slots
          int totalSlots = 0;
          int bookedSlots = 0;
          for (var schedule in schedules) {
            totalSlots += schedule['total_slots'] as int;
            bookedSlots += schedule['booked_slots'] as int;
          }

          return Card(
            margin: EdgeInsets.only(bottom: AppConstants.deviceHeight * 0.02),
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.symmetric(
                    vertical: AppConstants.deviceHeight * 0.015,
                    horizontal: AppConstants.deviceWidth * 0.04,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.teal,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(12),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Schedule #${index + 1}',
                              style: TextStyle(
                                fontSize: AppConstants.deviceWidth * 0.045,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit, color: Colors.white),
                            onPressed: () {
                              _loadScheduleData(index);
                              _showAddScheduleDialog();
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.white),
                            onPressed: () {
                              showDialog(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: const Text('Delete Schedule'),
                                  content: const Text('Are you sure you want to delete this schedule?'),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(context),
                                      child: const Text('Cancel'),
                                    ),
                                    TextButton(
                                      onPressed: () {
                                        Navigator.pop(context);
                                        _deleteSchedule(index);
                                      },
                                      child: const Text('Delete', style: TextStyle(color: Colors.red)),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                Padding(
                  padding: EdgeInsets.all(AppConstants.deviceWidth * 0.04),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Working days and shifts
                      Text(
                        'Working Days & Shifts:',
                        style: TextStyle(
                          fontSize: AppConstants.deviceWidth * 0.04,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      SizedBox(height: AppConstants.deviceHeight * 0.01),
                      Wrap(
                        spacing: AppConstants.deviceWidth * 0.02,
                        children: schedulesByDay.entries.map((entry) {
                          final day = entry.key;
                          final shifts = entry.value;
                          return Wrap(
                            spacing: AppConstants.deviceWidth * 0.02,
                            children: shifts.map((shift) {
                              final shiftName = shift['shift_name'];
                              return Chip(
                                label: Text('$day - $shiftName'),
                                backgroundColor: AppColors.lightBlue.withOpacity(0.1),
                                labelStyle: TextStyle(
                                  color: AppColors.teal,
                                  fontSize: AppConstants.deviceWidth * 0.035,
                                ),
                              );
                            }).toList(),
                          );
                        }).toList(),
                      ),
                      SizedBox(height: AppConstants.deviceHeight * 0.01),
                      // Booking stats
                      Row(
                        children: [
                          Icon(
                            Icons.people,
                            size: AppConstants.deviceWidth * 0.045,
                            color: AppColors.lightBlue,
                          ),
                          SizedBox(width: AppConstants.deviceWidth * 0.01),
                          Text(
                            'Total Slots: $totalSlots slots',
                            style: TextStyle(
                              fontSize: AppConstants.deviceWidth * 0.035,
                              color: Colors.grey.shade700,
                            ),
                          ),
                        ],
                      ),

                      SizedBox(height: AppConstants.deviceHeight * 0.01),
                      // // Progress bar
                      // ClipRRect(
                      //   borderRadius: BorderRadius.circular(8),
                      //   child: LinearProgressIndicator(
                      //     value: totalSlots > 0 ? bookedSlots / totalSlots : 0,
                      //     backgroundColor: Colors.grey.shade200,
                      //     color: _getStatusColor((totalSlots > 0 ? bookedSlots / totalSlots : 0) * 100),
                      //     minHeight: AppConstants.deviceHeight * 0.01,
                      //   ),
                      // ),

                      SizedBox(height: AppConstants.deviceHeight * 0.02),
                      // Expand button
                      Center(
                        child: ElevatedButton(
                          onPressed: () {
                            _showScheduleDetailsDialog(scheduleGroup);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.lightBlue,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                            elevation: 0,
                          ),
                          child: Text(
                            'View Details',
                            style: TextStyle(
                              fontSize: AppConstants.deviceWidth * 0.035,
                              color: Colors.black,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  void _showScheduleDetailsDialog(Map<String, dynamic> scheduleGroup) {
    final schedules = scheduleGroup['schedules'];

    // Group schedules by day
    Map<String, List<Map<String, dynamic>>> schedulesByDay = {};
    for (var schedule in schedules) {
      final day = schedule['day_of_week'];
      if (!schedulesByDay.containsKey(day)) {
        schedulesByDay[day] = [];
      }
      schedulesByDay[day]!.add(schedule);
    }

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          width: double.infinity,
          constraints: BoxConstraints(
            maxHeight: AppConstants.deviceHeight * 0.8,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: EdgeInsets.all(AppConstants.deviceWidth * 0.04),
                decoration: BoxDecoration(
                  color: AppColors.teal,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Schedule Details',
                          style: TextStyle(
                            fontSize: AppConstants.deviceWidth * 0.045,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: EdgeInsets.all(AppConstants.deviceWidth * 0.04),
                  children: schedulesByDay.entries.map((entry) {
                    final day = entry.key;
                    final daySchedules = entry.value;

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: EdgeInsets.symmetric(
                            vertical: AppConstants.deviceHeight * 0.01,
                            horizontal: AppConstants.deviceWidth * 0.02,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.lightBlue.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            day,
                            style: TextStyle(
                              fontSize: AppConstants.deviceWidth * 0.04,
                              fontWeight: FontWeight.bold,
                              color: AppColors.teal,
                            ),
                          ),
                        ),
                        SizedBox(height: AppConstants.deviceHeight * 0.01),
                        ...daySchedules.map((schedule) {
                          final bookedPercentage = (schedule['booked_slots'] / schedule['total_slots']) * 100;

                          return Card(
                            margin: EdgeInsets.only(bottom: AppConstants.deviceHeight * 0.01),
                            elevation: 2,
                            child: Padding(
                              padding: EdgeInsets.all(AppConstants.deviceWidth * 0.03),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            schedule['shift_name'],
                                            style: TextStyle(
                                              fontSize: AppConstants.deviceWidth * 0.04,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.grey.shade800,
                                            ),
                                          ),
                                          SizedBox(height: AppConstants.deviceHeight * 0.005),
                                          Row(
                                            children: [
                                              Icon(
                                                Icons.access_time,
                                                size: AppConstants.deviceWidth * 0.035,
                                                color: AppColors.lightBlue,
                                              ),
                                              SizedBox(width: AppConstants.deviceWidth * 0.01),
                                              Text(
                                                '${_formatTime(schedule['start_time'])} - ${_formatTime(schedule['end_time'])}',
                                                style: TextStyle(
                                                  fontSize: AppConstants.deviceWidth * 0.035,
                                                  color: Colors.grey.shade600,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                      Container(
                                        padding: EdgeInsets.symmetric(
                                          horizontal: AppConstants.deviceWidth * 0.02,
                                          vertical: AppConstants.deviceHeight * 0.005,
                                        ),
                                        decoration: BoxDecoration(
                                          color: _getStatusColor(bookedPercentage).withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(20),
                                        ),
                                        child: Text(
                                          '${schedule['total_slots']} slots',
                                          style: TextStyle(
                                            fontSize: AppConstants.deviceWidth * 0.035,
                                            fontWeight: FontWeight.bold,
                                            color: _getStatusColor(bookedPercentage),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: AppConstants.deviceHeight * 0.01),
                                  // ClipRRect(
                                  //   borderRadius: BorderRadius.circular(8),
                                  //   child: LinearProgressIndicator(
                                  //     value: schedule['total_slots'] > 0
                                  //         ? schedule['booked_slots'] / schedule['total_slots']
                                  //         : 0,
                                  //     backgroundColor: Colors.grey.shade200,
                                  //     color: _getStatusColor(bookedPercentage),
                                  //     minHeight: AppConstants.deviceHeight * 0.008,
                                  //   ),
                                  // ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                        SizedBox(height: AppConstants.deviceHeight * 0.02),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard(
      String title,
      String value,
      IconData icon,
      Color color,
      ) {
    return Expanded(
      child: Container(
        padding: EdgeInsets.all(AppConstants.deviceWidth * 0.03),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withAlpha(51),
              spreadRadius: 1,
              blurRadius: 3,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  icon,
                  color: color,
                  size: AppConstants.deviceWidth * 0.045,
                ),
                SizedBox(width: AppConstants.deviceWidth * 0.02),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: AppConstants.deviceWidth * 0.03,
                      color: Colors.grey.shade600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            SizedBox(height: AppConstants.deviceHeight * 0.01),
            Text(
              value,
              style: TextStyle(
                fontSize: AppConstants.deviceWidth * 0.045,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade800,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(double percentage) {
    if (percentage < 50) {
      return Colors.green;
    } else if (percentage < 80) {
      return Colors.orange;
    } else {
      return Colors.red;
    }
  }

  // Dialog to add or edit schedule
  void _showAddScheduleDialog() {
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return Dialog(
            insetPadding: EdgeInsets.symmetric(
              horizontal: AppConstants.deviceWidth * 0.05,
              vertical: AppConstants.deviceHeight * 0.05,
            ),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Container(
              width: double.infinity,
              constraints: BoxConstraints(
                maxHeight: AppConstants.deviceHeight * 0.9,
                maxWidth: AppConstants.deviceWidth * 0.9,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header
                  Container(
                    padding: EdgeInsets.all(AppConstants.deviceWidth * 0.04),
                    decoration: BoxDecoration(
                      color: AppColors.teal,
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _editingScheduleIndex >= 0 ? 'Edit Schedule' : 'Add New Schedule',
                          style: TextStyle(
                            fontSize: AppConstants.deviceWidth * 0.045,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                  ),
                  // Content
                  Expanded(
                    child: ListView(
                      padding: EdgeInsets.all(AppConstants.deviceWidth * 0.04),
                      children: [
                        // Days selection
                        Text(
                          'Select Working Days',
                          style: TextStyle(
                            fontSize: AppConstants.deviceWidth * 0.04,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey.shade800,
                          ),
                        ),
                        SizedBox(height: AppConstants.deviceHeight * 0.01),
                        Wrap(
                          spacing: AppConstants.deviceWidth * 0.02,
                          runSpacing: AppConstants.deviceHeight * 0.01,
                          children: _daysOfWeek.map((day) {
                            final isSelected = _selectedDays.contains(day);
                            return InkWell(
                              onTap: () {
                                setState(() {
                                  if (isSelected) {
                                    _selectedDays.remove(day);
                                  } else {
                                    _selectedDays.add(day);
                                  }
                                });
                              },
                              child: Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: AppConstants.deviceWidth * 0.03,
                                  vertical: AppConstants.deviceHeight * 0.01,
                                ),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? AppColors.teal
                                      : Colors.grey.shade200,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  day,
                                  style: TextStyle(
                                    fontSize: AppConstants.deviceWidth * 0.035,
                                    color: isSelected ? Colors.white : Colors.black,
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                        SizedBox(height: AppConstants.deviceHeight * 0.02),

                        // Shifts selection
                        Text(
                          'Select Shifts',
                          style: TextStyle(
                            fontSize: AppConstants.deviceWidth * 0.04,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey.shade800,
                          ),
                        ),
                        SizedBox(height: AppConstants.deviceHeight * 0.01),
                        ..._weeklyShifts.entries.map((entry) {
                          final shiftName = entry.key;
                          final shift = entry.value;
                          final isSelected = shift['selected'] as bool;

                          return Container(
                            margin: EdgeInsets.only(bottom: AppConstants.deviceHeight * 0.01),
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: isSelected
                                    ? AppColors.teal
                                    : Colors.grey.shade300,
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Column(
                              children: [
                                ListTile(
                                  title: Text(
                                    shiftName,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: isSelected
                                          ? AppColors.teal
                                          : Colors.grey.shade800,
                                    ),
                                  ),
                                  subtitle: Text(
                                    shift['description'] as String,
                                    style: TextStyle(
                                      fontSize: AppConstants.deviceWidth * 0.035,
                                    ),
                                  ),
                                  trailing: Switch(
                                    value: isSelected,
                                    activeColor: AppColors.teal,
                                    onChanged: (value) {
                                      setState(() {
                                        shift['selected'] = value;
                                      });
                                    },
                                  ),
                                ),
                                if (isSelected)
                                  Padding(
                                    padding: EdgeInsets.all(AppConstants.deviceWidth * 0.03),
                                    child: Column(
                                      children: [
                                        // Time selection
                                        Row(
                                          children: [
                                            Expanded(
                                              child: InkWell(
                                                onTap: () => _selectTime(
                                                  context,
                                                  true,
                                                  shiftName,
                                                ).then((_) => setState(() {})),
                                                child: Container(
                                                  padding: EdgeInsets.all(AppConstants.deviceWidth * 0.03),
                                                  decoration: BoxDecoration(
                                                    border: Border.all(color: Colors.grey.shade300),
                                                    borderRadius: BorderRadius.circular(8),
                                                  ),
                                                  child: Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      Text(
                                                        'Start Time',
                                                        style: TextStyle(
                                                          fontSize: AppConstants.deviceWidth * 0.03,
                                                          color: Colors.grey.shade600,
                                                        ),
                                                      ),
                                                      SizedBox(height: AppConstants.deviceHeight * 0.005),
                                                      Text(
                                                        _formatTime(shift['startTime']),
                                                        style: TextStyle(
                                                          fontSize: AppConstants.deviceWidth * 0.035,
                                                          fontWeight: FontWeight.bold,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            ),
                                            SizedBox(width: AppConstants.deviceWidth * 0.02),
                                            Expanded(
                                              child: InkWell(
                                                onTap: () => _selectTime(
                                                  context,
                                                  false,
                                                  shiftName,
                                                ).then((_) => setState(() {})),
                                                child: Container(
                                                  padding: EdgeInsets.all(AppConstants.deviceWidth * 0.03),
                                                  decoration: BoxDecoration(
                                                    border: Border.all(color: Colors.grey.shade300),
                                                    borderRadius: BorderRadius.circular(8),
                                                  ),
                                                  child: Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      Text(
                                                        'End Time',
                                                        style: TextStyle(
                                                          fontSize: AppConstants.deviceWidth * 0.03,
                                                          color: Colors.grey.shade600,
                                                        ),
                                                      ),
                                                      SizedBox(height: AppConstants.deviceHeight * 0.005),
                                                      Text(
                                                        _formatTime(shift['endTime']),
                                                        style: TextStyle(
                                                          fontSize: AppConstants.deviceWidth * 0.035,
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
                                        SizedBox(height: AppConstants.deviceHeight * 0.01),
                                        // Slots
                                        Row(
                                          children: [
                                            Text(
                                              'Total Slots:',
                                              style: TextStyle(
                                                fontSize: AppConstants.deviceWidth * 0.035,
                                              ),
                                            ),
                                            SizedBox(width: AppConstants.deviceWidth * 0.02),
                                            Expanded(
                                              child: Slider(
                                                value: (shift['totalSlots'] as int).toDouble(),
                                                min: 1,
                                                max: 10,
                                                divisions: 9,
                                                activeColor: AppColors.teal,
                                                label: shift['totalSlots'].toString(),
                                                onChanged: (value) {
                                                  setState(() {
                                                    shift['totalSlots'] = value.toInt();
                                                    // Ensure booked slots don't exceed total
                                                    if ((shift['bookedSlots'] as int) > value.toInt()) {
                                                      shift['bookedSlots'] = value.toInt();
                                                    }
                                                  });
                                                },
                                              ),
                                            ),
                                            SizedBox(width: AppConstants.deviceWidth * 0.02),
                                            Text(
                                              shift['totalSlots'].toString(),
                                              style: TextStyle(
                                                fontSize: AppConstants.deviceWidth * 0.035,
                                                fontWeight: FontWeight.bold,
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
                        }).toList(),
                        SizedBox(height: AppConstants.deviceHeight * 0.02),
                      ],
                    ),
                  ),
                  // Footer
                  Container(
                    padding: EdgeInsets.all(AppConstants.deviceWidth * 0.04),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: Text(
                            'Cancel',
                            style: TextStyle(
                              color: Colors.grey.shade700,
                            ),
                          ),
                        ),
                        SizedBox(width: AppConstants.deviceWidth * 0.02),
                        ElevatedButton(
                          onPressed: () {
                            Navigator.pop(context);
                            if (_selectedDays.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Please select at least one day')),
                              );
                              return;
                            }

                            bool hasSelectedShift = false;
                            for (var shift in _weeklyShifts.values) {
                              if (shift['selected'] == true) {
                                if (shift['startTime'] == null || shift['endTime'] == null) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Please set time for all selected shifts')),
                                  );
                                  return;
                                }
                                hasSelectedShift = true;
                              }
                            }

                            if (!hasSelectedShift) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Please select at least one shift')),
                              );
                              return;
                            }

                            if (_editingScheduleIndex >= 0) {
                              _updateSchedule(_editingScheduleIndex);
                            } else {
                              _saveSchedule();
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.teal,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: Text(
                            _editingScheduleIndex >= 0 ? 'Update' : 'Save',
                            style: TextStyle(
                              fontSize: AppConstants.deviceWidth * 0.035,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}