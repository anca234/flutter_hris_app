import 'dart:convert';
import 'package:secondly/service/api_client.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/user_data.dart';
import '../models/login_response.dart';
import '../config/api_config.dart';

class AuthService {
  static const String _tokenKey = 'auth_token';
  static const String _userDataKey = 'user_data';
  static final _apiClient = ApiClient();

  // Private constructor to prevent instantiation
  AuthService._();
  
  static UserData? _currentUser;
  static String? _authToken;

  // Getter for current user
  static UserData? get currentUser => _currentUser;
  
  // Getter for auth token
  static String? get authToken => _authToken;

  /// Initialize auth state with error handling
  static Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Safely get token
      try {
        _authToken = prefs.getString(_tokenKey);
      } catch (e) {
        print('Error reading token: $e');
        _authToken = null;
      }
      
      // Safely get user data
      try {
        final userDataString = prefs.getString(_userDataKey);
        if (userDataString != null) {
          _currentUser = UserData.fromJson(jsonDecode(userDataString));
        }
      } catch (e) {
        print('Error reading user data: $e');
        _currentUser = null;
        // Clean up potentially corrupted data
        await prefs.remove(_userDataKey);
      }
    } catch (e) {
      print('Critical initialization error: $e');
      // Reset state if initialization fails
      _authToken = null;
      _currentUser = null;
      rethrow;
    }
  }

  /// Login method with enhanced error handling
  static Future<LoginResponse> login(String username, String password) async {
    // Admin bypass for development/testing
    if (ApiConfig.isDevelopment && username == 'admin' && password == 'admin') {
      return _handleAdminLogin();
    }

    try {
      final response = await _apiClient.post(
        'auth.php?action=login',
        body: {
          'username': username,
          'password': password,
        },
      );

      final loginResponse = LoginResponse.fromJson(response);

      if (loginResponse.success) {
        await _saveAuthData(loginResponse);
      }

      return loginResponse;
    } catch (e) {
      throw _handleAuthError(e);
    }
  }

  /// Validate token
  static Future<bool> validateToken() async {
    if (_authToken == null) return false;

    try {
      final response = await _apiClient.post(
        'auth.php?action=validate',
        headers: {'Authorization': 'Bearer $_authToken'},
      );
      
      return response['success'] ?? false;
    } catch (e) {
      await logout();
      return false;
    }
  }

  /// Check if user is logged in with safe error handling
  static Future<bool> isLoggedIn() async {
    try {
      if (_authToken == null) return false;
      return await validateToken();
    } catch (e) {
      print('Error checking login state: $e');
      return false;
    }
  }

  /// Get current user data
  static Future<UserData?> getCurrentUser() async {
    if (_currentUser != null) return _currentUser;
    return await getStoredUserData();
  }

  /// Get stored user data
  static Future<UserData?> getStoredUserData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userDataString = prefs.getString(_userDataKey);
      
      if (userDataString != null) {
        _currentUser = UserData.fromJson(jsonDecode(userDataString));
        return _currentUser;
      }
    } catch (e) {
      await logout();
    }
    return null;
  }

  /// Update user data
  static Future<void> updateUserData(UserData userData) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_userDataKey, jsonEncode(userData.toJson()));
      _currentUser = userData;
    } catch (e) {
      throw Exception('Failed to update user data: $e');
    }
  }

  /// Logout
  static Future<void> logout() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_tokenKey);
      await prefs.remove(_userDataKey);
      _authToken = null;
      _currentUser = null;
    } catch (e) {
      throw Exception('Failed to logout: $e');
    }
  }

  /// Handle admin login for development
  static Future<LoginResponse> _handleAdminLogin() async {
    final dummyUserData = UserData(
      userId: 1,
      username: 'admin',
      email: 'admin@example.com',
      fullName: 'Admin User',
      permissions: ['all_access', 'admin'],
      jobTitle: 'DEVELOPER',
      employeeId: 0,
    );

    final dummyResponse = LoginResponse(
      success: true,
      token: 'dummy_admin_token',
      user: dummyUserData,
    );

    await _saveAuthData(dummyResponse);
    return dummyResponse;
  }

  /// Save authentication data
  static Future<void> _saveAuthData(LoginResponse loginResponse) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_tokenKey, loginResponse.token);
      await prefs.setString(_userDataKey, jsonEncode(loginResponse.user.toJson()));
      
      _authToken = loginResponse.token;
      _currentUser = loginResponse.user;
    } catch (e) {
      throw Exception('Failed to save auth data: $e');
    }
  }

  /// Handle authentication errors
  static Exception _handleAuthError(dynamic error) {
    if (error is Exception) {
      if (error.toString().contains('Connection refused') || 
          error.toString().contains('SocketException')) {
        return Exception('Unable to connect to server. Please check your internet connection.');
      }
      if (error.toString().contains('401')) {
        return Exception('Invalid username or password.');
      }
    }
    return Exception('Authentication failed: ${error.toString()}');
  }
}