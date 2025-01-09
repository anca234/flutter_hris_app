import 'dart:io';
import 'dart:convert';
import '../config/api_config.dart';

class ApiClient {
  static final ApiClient _instance = ApiClient._internal();
  late HttpClient _client;

  // Factory constructor
  factory ApiClient() {
    return _instance;
  }

  // Private constructor
  ApiClient._internal() {
    _initializeClient();
  }

  void _initializeClient() {
    _client = HttpClient()
      ..badCertificateCallback = ((X509Certificate cert, String host, int port) => true);
  }

  // Generic GET request
  Future<Map<String, dynamic>> get(String endpoint, {Map<String, String>? headers}) async {
    try {
      final request = await _client.getUrl(Uri.parse('${ApiConfig.baseUrl}/$endpoint'));
      _addHeaders(request, headers);
      
      final response = await request.close();
      return _handleResponse(response);
    } catch (e) {
      throw _handleError(e);
    }
  }

  // Generic POST request
  Future<Map<String, dynamic>> post(String endpoint, {
    Map<String, dynamic>? body,
    Map<String, String>? headers,
  }) async {
    try {
      final request = await _client.postUrl(Uri.parse('${ApiConfig.baseUrl}/$endpoint'));
      _addHeaders(request, headers);
      
      if (body != null) {
        request.write(json.encode(body));
      }
      
      final response = await request.close();
      return _handleResponse(response);
    } catch (e) {
      throw _handleError(e);
    }
  }

  // Generic PUT request
  Future<Map<String, dynamic>> put(String endpoint, {
    Map<String, dynamic>? body,
    Map<String, String>? headers,
  }) async {
    try {
      final request = await _client.putUrl(Uri.parse('${ApiConfig.baseUrl}/$endpoint'));
      _addHeaders(request, headers);
      
      if (body != null) {
        request.write(json.encode(body));
      }
      
      final response = await request.close();
      return _handleResponse(response);
    } catch (e) {
      throw _handleError(e);
    }
  }

  // Generic DELETE request
  Future<Map<String, dynamic>> delete(String endpoint, {Map<String, String>? headers}) async {
    try {
      final request = await _client.deleteUrl(Uri.parse('${ApiConfig.baseUrl}/$endpoint'));
      _addHeaders(request, headers);
      
      final response = await request.close();
      return _handleResponse(response);
    } catch (e) {
      throw _handleError(e);
    }
  }

  // Helper method to add headers
  void _addHeaders(HttpClientRequest request, Map<String, String>? additionalHeaders) {
    request.headers.set('content-type', 'application/json');
    
    // Add default headers from ApiConfig
    ApiConfig.headers.forEach((key, value) {
      request.headers.set(key, value);
    });

    // Add any additional headers
    if (additionalHeaders != null) {
      additionalHeaders.forEach((key, value) {
        request.headers.set(key, value);
      });
    }
  }

  // Helper method to handle response
  Future<Map<String, dynamic>> _handleResponse(HttpClientResponse response) async {
    final responseBody = await response.transform(utf8.decoder).join();
    final jsonResponse = json.decode(responseBody);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return jsonResponse;
    } else {
      throw HttpException('${response.statusCode}: ${jsonResponse['message'] ?? 'Unknown error'}');
    }
  }

  // Helper method to handle errors
  Exception _handleError(dynamic error) {
    if (error is HandshakeException) {
      return Exception('Connection security error. Please check your network settings or contact support.');
    } else if (error is SocketException) {
      return Exception('Network error. Please check your internet connection.');
    } else if (error is HttpException) {
      return error;
    } else {
      return Exception('An unexpected error occurred: $error');
    }
  }
}