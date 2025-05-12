import 'package:flutter/material.dart';
import '../../../constants.dart';
import '../../../globals.dart';

class PurchaseDetailScreen extends StatelessWidget {
  final Map<String, dynamic> purchase;

  const PurchaseDetailScreen({Key? key, required this.purchase}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    List items = purchase['items'] ?? [];
    final dateTime = purchase['timestamp'] != null
        ? DateTime.parse(purchase['timestamp']).toLocal()
        : null;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Purchase Details',
          style: TextStyle(
            color: AppColors.teal,
          ),
        ),
        iconTheme: const IconThemeData(
          color: AppColors.teal,
        ),
      ),
      body: Padding(
        padding: EdgeInsets.all(AppConstants.deviceWidth * 0.05),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              title: Text(
                'Rs. ${purchase['total_amount'] ?? 'N/A'}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              subtitle: Text(
                dateTime != null
                    ? 'Date: ${dateTime.toString().split('.')[0]}' // Show date and time without seconds
                    : 'N/A',
                style: const TextStyle(fontSize: 16),
              ),
            ),
            const Divider(color: AppColors.teal),
            Text(
              'Address: ${purchase['address'] ?? 'N/A'}',
              style: const TextStyle(fontSize: 16),
            ),
            SizedBox(height: AppConstants.deviceHeight * 0.02),
            Text(
              'Payment Type: ${purchase['payment_type'] ?? 'N/A'}',
              style: const TextStyle(fontSize: 16),
            ),
            SizedBox(height: AppConstants.deviceHeight * 0.02),
            const Text(
              'Items:',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final item = items[index];
                  return Card(
                    color: AppColors.lightBlue,
                    elevation: 0, // Remove shadow
                    margin: EdgeInsets.symmetric(vertical: AppConstants.deviceHeight * 0.01),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ListTile(
                      title: Text(item['name'] ?? 'N/A'),
                      subtitle: Text(
                          'Quantity: ${item['quantity'] ?? 'N/A'} - Price: Rs. ${item['price'] ?? 'N/A'}'),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}