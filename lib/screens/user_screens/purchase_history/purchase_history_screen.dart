import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'purchase_history_provider.dart';
import 'purchase_detail.dart';
import '../../../constants.dart';
import '../../../globals.dart';

class PurchaseHistoryScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final purchaseHistoryProvider = Provider.of<PurchaseHistoryProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Purchase History',
          style: TextStyle(
            color: AppColors.teal,
          ),
        ),
        iconTheme: const IconThemeData(
          color: AppColors.teal,
        ),
      ),
      body: purchaseHistoryProvider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : purchaseHistoryProvider.purchaseHistory.isEmpty
          ? const Center(child: Text('No purchase history found.'))
          : GridView.builder(
        padding: EdgeInsets.all(AppConstants.deviceWidth * 0.05),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 1,
          crossAxisSpacing: AppConstants.deviceWidth * 0.05,
          mainAxisSpacing: AppConstants.deviceWidth * 0.05,
          childAspectRatio: 2,
        ),
        itemCount: purchaseHistoryProvider.purchaseHistory.length,
        itemBuilder: (context, index) {
          final purchase = purchaseHistoryProvider.purchaseHistory[index];
          final date = purchase['timestamp'] != null
              ? DateTime.parse(purchase['timestamp']).toLocal()
              : null;
          final items = purchase['items'] ?? [];
          final firstItemName = items.isNotEmpty ? items[0]['name'] : 'N/A';
          final hasMoreItems = items.length > 1;

          return Card(
            color: AppColors.lightBlue,
            elevation: 0, // Remove shadow
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: InkWell(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        PurchaseDetailScreen(purchase: purchase),
                  ),
                );
              },
              child: Padding(
                padding: EdgeInsets.all(AppConstants.deviceWidth * 0.03),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Medicine Name
                    Text(
                      firstItemName,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                      maxLines: 1, // Prevent text overflow
                      overflow: TextOverflow.ellipsis, // Show "..." if text overflows
                    ),
                    if (hasMoreItems)
                      const Text(
                        '...',
                        style: TextStyle(fontSize: 18),
                      ),
                    SizedBox(height: AppConstants.deviceHeight * 0.01),
                    // Total Price
                    Text(
                      'Rs. ${purchase['total_amount'] ?? 'N/A'}',
                      style: const TextStyle(fontSize: 16),
                    ),
                    SizedBox(height: AppConstants.deviceHeight * 0.01),
                    // Date
                    Text(
                      date != null
                          ? 'Date: ${date.toLocal().toString().split(' ')[0]}' // Show only date
                          : 'N/A',
                      style: const TextStyle(fontSize: 14),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          print("Refreshing purchase history...");
          purchaseHistoryProvider.fetchPurchaseHistory();
        },
        backgroundColor: AppColors.teal,
        child: Icon(Icons.refresh, color: Colors.white),
      ),
    );
  }
}