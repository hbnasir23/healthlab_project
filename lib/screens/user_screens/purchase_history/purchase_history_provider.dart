import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../globals.dart';

import '../../login_screen.dart';


class PurchaseHistoryProvider extends ChangeNotifier {
  final SupabaseClient supabase;
  List<Map<String, dynamic>> _purchaseHistory = [];
  bool _isLoading = false;

  PurchaseHistoryProvider(this.supabase) {
    fetchPurchaseHistory(); // Automatically fetch data when initialized
  }

  List<Map<String, dynamic>> get purchaseHistory => _purchaseHistory;
  bool get isLoading => _isLoading;

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

  Future<void> fetchPurchaseHistory() async {
    _isLoading = true;
    notifyListeners();

    try {
      final userEmail = loggedInEmail;
      int? userId = await getUserIdByEmail(userEmail!);
      if (userId == null) {
        _purchaseHistory = [];
        _isLoading = false;
        notifyListeners();
        return;
      }

      final response = await supabase
          .from('orders')
          .select()
          .eq('user_id', userId)
          .order('timestamp', ascending: false);

      _purchaseHistory = List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print("Error fetching purchase history: $e");
    }

    _isLoading = false;
    notifyListeners();
  }

}
