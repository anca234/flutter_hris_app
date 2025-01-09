import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:secondly/models/user_data.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';
import '../models/login_response.dart';

class AuthService {
  static const String TOKEN_KEY = 'auth_token';
  static const String USER_DATA_KEY = 'user_data';

  static Future<LoginResponse> login(String username, String password) async {
    // Admin bypass check
    if (username == 'admin' && password == 'admin') {
      // Create dummy user data
      final dummyUserData = UserData(
        userId: 1,
        username: 'admin',
        email: 'admin@example.com',
        fullName: 'Admin User',
        permissions: ['all_access', 'admin'],
      );

      // Create dummy response
      final dummyResponse = LoginResponse(
        success: true,
        token: 'dummy_admin_token',
        user: dummyUserData,
      );

      // Store in SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(TOKEN_KEY, dummyResponse.token);
      await prefs.setString(USER_DATA_KEY, jsonEncode({
        'user_id': dummyResponse.user.userId,
        'username': dummyResponse.user.username,
        'email': dummyResponse.user.email,
        'full_name': dummyResponse.user.fullName,
        'permissions': dummyResponse.user.permissions,
      }));

      return dummyResponse;
    }

    // Regular authentication flow
    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/auth.php?action=login'),
        headers: ApiConfig.headers,
        body: jsonEncode({
          'username': username,
          'password': password,
        }),
      );

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        final loginResponse = LoginResponse.fromJson(jsonResponse);

        // Store in SharedPreferences if login successful
        if (loginResponse.success) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(TOKEN_KEY, loginResponse.token);
          await prefs.setString(USER_DATA_KEY, jsonEncode({
            'user_id': loginResponse.user.userId,
            'username': loginResponse.user.username,
            'email': loginResponse.user.email,
            'full_name': loginResponse.user.fullName,
            'permissions': loginResponse.user.permissions,
          }));
        }

        return loginResponse;
      } else {
        throw Exception('Failed to login: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to login: $e');
    }
  }

  // Helper method to check if user is logged in
  static Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(TOKEN_KEY) != null;
  }

  // Helper method to get stored user data
  static Future<UserData?> getStoredUserData() async {
    final prefs = await SharedPreferences.getInstance();
    final userDataString = prefs.getString(USER_DATA_KEY);
    if (userDataString != null) {
      final userDataJson = jsonDecode(userDataString);
      return UserData.fromJson(userDataJson);
    }
    return null;
  }

  // Helper method to logout
  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(TOKEN_KEY);
    await prefs.remove(USER_DATA_KEY);
  }
}