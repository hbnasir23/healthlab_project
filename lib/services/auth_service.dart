import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:crypt/crypt.dart';
import 'package:healthlab/globals.dart';

class AuthService {
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  final String _emailKey = 'user_email';
  final String _passwordKey = 'user_password';
  final String _stayLoggedInKey = 'stay_logged_in';
  final String _userRoleKey = 'user_role'; // Add role storage key

  // Save credentials if stay logged in is selected
  Future<void> saveCredentials(String email, String password, bool stayLoggedIn, String role) async {
    if (stayLoggedIn) {
      await _secureStorage.write(key: _emailKey, value: email);
      await _secureStorage.write(key: _passwordKey, value: password);
      await _secureStorage.write(key: _stayLoggedInKey, value: stayLoggedIn.toString());
      await _secureStorage.write(key: _userRoleKey, value: role); // Save the user role
    } else {
      await clearCredentials();
    }
  }

  // Get saved credentials
  Future<Map<String, String?>> getSavedCredentials() async {
    final email = await _secureStorage.read(key: _emailKey);
    final password = await _secureStorage.read(key: _passwordKey);
    final stayLoggedIn = await _secureStorage.read(key: _stayLoggedInKey);
    final role = await _secureStorage.read(key: _userRoleKey);

    return {
      'email': email,
      'password': password,
      'stayLoggedIn': stayLoggedIn,
      'role': role,
    };
  }

  // Check if user should stay logged in
  Future<bool> shouldStayLoggedIn() async {
    final stayLoggedIn = await _secureStorage.read(key: _stayLoggedInKey);
    return stayLoggedIn == 'true';
  }

  // Clear saved credentials
  Future<void> clearCredentials() async {
    final email = loggedInEmail;
    print('Email: $loggedInEmail');
    if (email != null) {
      await Supabase.instance.client
          .from('users')
          .update({'fcm_token': null})
          .eq('email', email);
    }

    await _secureStorage.delete(key: _emailKey);
    await _secureStorage.delete(key: _passwordKey);
    await _secureStorage.delete(key: _stayLoggedInKey);
    await _secureStorage.delete(key: _userRoleKey);

    // Unsubscribe from all topics
    await FirebaseMessaging.instance.unsubscribeFromTopic('admin');
    await FirebaseMessaging.instance.unsubscribeFromTopic('user');
    await FirebaseMessaging.instance.unsubscribeFromTopic('doctor');
  }

  // Auto login using saved credentials
  Future<Map<String, dynamic>> autoLogin() async {
    if (await shouldStayLoggedIn()) {
      final credentials = await getSavedCredentials();
      print('Retrieved credentials: ${await getSavedCredentials()}');

      if (credentials['email'] != null && credentials['password'] != null) {
        try {
          var res = await Supabase.instance.client
              .from('users')
              .select()
              .eq('email', credentials['email']!);
          print('Database Response: $res');

          if (res.isNotEmpty) {
            print('Role from DB: ${res[0]['role']}');

            if (res[0]['role'] == 'admin' &&
                res[0]['password'] == credentials['password']) {
              return {
                'success': true,
                'role': 'admin',
              };
            } else if (Crypt(res[0]['password']).match(credentials['password']!) &&
                res[0]['role'] == 'user') {
              loggedInUsername = res[0]['name'];
              loggedInEmail = res[0]['email'];
              return {
                'success': true,
                'role': 'user',
              };
            } else if (Crypt(res[0]['password']).match(credentials['password']!) &&
                res[0]['role'] == 'doctor') {
              loggedInUsername = res[0]['name'];
              loggedInEmail = res[0]['email'];
              return {
                'success': true,
                'role': 'doctor',
              };
            }
          }
        } catch (e) {
          print('Auto login error: $e');
        }
      }
    }
    return {
      'success': false,
      'role': null,
    };
  }
}