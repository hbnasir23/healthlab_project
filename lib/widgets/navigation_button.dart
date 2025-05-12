import 'package:flutter/material.dart';
import '../constants.dart';

class NavigationButton extends StatelessWidget {
  final String title;
  final int screenIndex;
  final VoidCallback onTap; // Required onTap function

  const NavigationButton({
    required this.title,
    required this.screenIndex,
    required this.onTap, // Ensure it's required
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap, // Call the provided function when tapped
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.lightBlue,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Center(
          child: Text(
            title,
            style: TextStyle(
              color: AppColors.teal,
              fontSize: AppConstants.deviceWidth * 0.04,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}
