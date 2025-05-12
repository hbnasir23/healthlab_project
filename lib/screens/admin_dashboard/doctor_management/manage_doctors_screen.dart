import 'package:flutter/material.dart';
import 'add_doctor.dart';
import '../../../constants.dart';
import 'package:modal_bottom_sheet/modal_bottom_sheet.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ManageDoctorsScreen extends StatefulWidget {
  const ManageDoctorsScreen({super.key});

  @override
  State<ManageDoctorsScreen> createState() => _ManageDoctorsScreenState();
}

class _ManageDoctorsScreenState extends State<ManageDoctorsScreen> {

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AddDoctorsScreen()),
          );
          setState(() {}); // Refresh the list after adding
        },
        backgroundColor: Colors.teal,
        child: const Icon(Icons.add),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Doctors List',
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
              const SizedBox(height: 20),
              Expanded(
                child: FutureBuilder<List<Map<String, dynamic>>>(
                  future: Supabase.instance.client
                      .from('doctors')
                      .select('*, users(name, email)'),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (!snapshot.hasData || snapshot.data!.isEmpty) {
                      return const Center(child: Text('No doctors found'));
                    }
                    return GridView.builder(
                      gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                        childAspectRatio: 0.85,
                      ),
                      itemCount: snapshot.data!.length,
                      itemBuilder: (context, index) {
                        final doctor = snapshot.data![index];
                        return _buildDoctorCard(doctor);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDoctorCard(Map<String, dynamic> doctor) {
    bool isPending = doctor['status'] == 'pending';
    var user = doctor['users'];

    return GestureDetector(
      onTap: () => _showDoctorDetails(doctor),
      child: Card(
        elevation: 5,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: isPending ? Colors.red : Colors.transparent, // Red border for pending doctors
            width: 2,
          ),
        ),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: Colors.teal[50],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 12),
              CircleAvatar(
                radius: 40,
                backgroundColor: Colors.teal[100],
                child: doctor['photo'] != null
                    ? ClipOval(
                  child: Image.network(
                    doctor['photo'],
                    width: 80,
                    height: 80,
                    fit: BoxFit.cover,
                  ),
                )
                    : const Icon(Icons.person, size: 40, color: Colors.teal),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  user['name'] ?? 'N/A',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.teal,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                doctor['specialization'],
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.teal[700],
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDoctorDetails(Map<String, dynamic> doctor) {
    var user = doctor['users'];

    showMaterialModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Doctor Details',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.teal,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.grey),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 20),
            // Doctor image
            Center(
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.teal, width: 2),
                ),
                child: ClipOval(
                  child: doctor['photo'] != null
                      ? Image.network(
                    doctor['photo'],
                    fit: BoxFit.cover,
                  )
                      : Container(
                    color: Colors.teal[50],
                    child: const Icon(
                      Icons.person,
                      size: 80,
                      color: Colors.teal,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            _buildDetailRow('Name', user['name']),

            _buildDetailRow('Email', user['email']),
            _buildDetailRow('Phone', doctor['phone']),
            _buildDetailRow('Specialization', doctor['specialization']),
            _buildDetailRow('Area', doctor['area']),
            _buildDetailRow('Hospital', doctor['hospital']),
            _buildDetailRow('Fees', doctor['fees']?.toString()),
            _buildDetailRow('Experience', doctor['experience']?.toString()),
            _buildDetailRow('Age', doctor['age']?.toString()),
            _buildDetailRow('Gender', doctor['gender']),
            const SizedBox(height: 20),

            if (doctor['status'] == 'pending') ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton(
                    onPressed: () => _approveDoctor(doctor['user_id']),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                    child: const Text('Approve'),
                  ),
                  ElevatedButton(
                    onPressed: () => _rejectDoctor(doctor['user_id']),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                    child: const Text('Reject'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _approveDoctor(int doctorId) async {
    await Supabase.instance.client
        .from('doctors')
        .update({'status': 'approved'})
        .eq('user_id', doctorId);

    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Doctor Approved')));
    setState(() {}); // Refresh UI
    Navigator.pop(context);
  }

  void _rejectDoctor(int doctorId) async {
    await Supabase.instance.client.from('doctors').delete().eq('user_id', doctorId);

    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Doctor Rejected')));
    setState(() {}); // Refresh UI
    Navigator.pop(context);
  }

  Widget _buildDetailRow(String label, String? value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Text(
        '$label: ${value ?? 'N/A'}',
        style: const TextStyle(fontSize: 16),
      ),
    );
  }
}