import 'package:flutter/material.dart';

class AppColors {
  static const teal = Color(0xFF008A8A);
  static get lightBlue => const Color(0xFF008A8A).withOpacity(0.22);
}

class AppConstants {
  static late double deviceWidth;
  static late double deviceHeight;

  static void init(BuildContext context) {
    deviceWidth = MediaQuery.of(context).size.width;
    deviceHeight = MediaQuery.of(context).size.height;
  }
}
