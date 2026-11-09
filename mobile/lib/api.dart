import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

class ApiException implements Exception {
  final String message;
  final int? statusCode;
  const ApiException(this.message, {this.statusCode});
  @override
  String toString() => message;
}

class ServerReport {
  final bool online;
  final String address;
  final String message;
  final int? statusCode;
  final Duration elapsed;
  const ServerReport({required this.online, required this.address,
    required this.message, required this.elapsed, this.statusCode});
}

class Api {
  // This URL is inserted by the GitHub Actions workflow when building the APK.
  static const configuredBase = String.fromEnvironment(
    'API_BASE_URL', defaultValue: 'https://YOUR-RENDER-SERVICE.onrender.com');
  static String get base => configuredBase.trim().replaceFirst(RegExp(r'/+$'), '');
  static const storage = FlutterSecureStorage();
  String? _token;
  String? get token => _token;

  bool get hasValidUrl => base.startsWith('https://') &&
      !base.contains('YOUR-RENDER-SERVICE') &&
      Uri.tryParse(base)?.host.isNotEmpty == true;

  // Health is publicly accessible and is intentionally independent of login.
  Future<ServerReport> checkServer() async {
    final sw = Stopwatch()..start();
    final address = '$base/health';
    if (!hasValidUrl) {
      return ServerReport(online: false, address: address, elapsed: sw.elapsed,
        message: 'অ্যাপের API_BASE_URL সঠিকভাবে দেওয়া হয়নি। GitHub Actions Variable দেখুন।');
    }
    try {
      final response = await http.get(Uri.parse(address),
          headers: {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 85));
      final body = jsonDecode(response.body);
      if (response.statusCode == 200 && body is Map && body['ok'] == true) {
        return ServerReport(online: true, address: address, elapsed: sw.elapsed,
          statusCode: response.statusCode, message: 'Server Online: NovaLive API কাজ করছে।');
      }
      return ServerReport(online: false, address: address, elapsed: sw.elapsed,
        statusCode: response.statusCode,
        message: 'সার্ভার উত্তর দিয়েছে, কিন্তু Health Check সফল হয়নি (HTTP ${response.statusCode})।');
    } on TimeoutException {
      return ServerReport(online: false, address: address, elapsed: sw.elapsed,
        message: 'সার্ভারের উত্তর পেতে দেরি হচ্ছে। Render Free সার্ভার ঘুমিয়ে থাকলে আবার চেষ্টা করুন।');
    } on SocketException {
      return ServerReport(online: false, address: address, elapsed: sw.elapsed,
        message: 'DNS/ইন্টারনেট সমস্যা। Release APK-তে INTERNET permission এবং সঠিক সার্ভার URL যাচাই করুন।');
    } on http.ClientException catch (e) {
      return ServerReport(online: false, address: address, elapsed: sw.elapsed,
        message: e.message.contains('Failed host lookup')
          ? 'সার্ভারের নাম খুঁজে পাওয়া যাচ্ছে না। APK-এর INTERNET permission অথবা DNS যাচাই করুন।'
          : 'সার্ভারে সংযোগ হয়নি। নেটওয়ার্ক এবং HTTPS ঠিকানা যাচাই করুন।');
    } on HandshakeException {
      return ServerReport(online: false, address: address, elapsed: sw.elapsed,
        message: 'HTTPS Certificate যাচাই ব্যর্থ হয়েছে।');
    } catch (_) {
      return ServerReport(online: false, address: address, elapsed: sw.elapsed,
        message: 'সার্ভারে সংযোগ ব্যর্থ। /health লিংক ব্রাউজারে খুলে দেখুন।');
    }
  }

  Future<bool> restore() async {
    _token = await storage.read(key: 'access_token');
    if (_token == null) return false;
    try {
      await get('/me');
      return true;
    } on ApiException catch (e) {
      // A sleeping server / DNS outage must NOT silently wipe login credentials.
      if (e.statusCode == 401) await logout();
      return false;
    } catch (_) {
      return false;
    }
  }

  Future<void> logout() async {
    _token = null;
    await storage.delete(key: 'access_token');
  }

  Future<Map<String,dynamic>> login(String email, String password) async {
    final j = await post('/auth/login', {'email': email, 'password': password}, public: true);
    _token = j['token'] as String;
    await storage.write(key: 'access_token', value: _token);
    return Map<String,dynamic>.from(j['user'] as Map);
  }

  Future<Map<String,dynamic>> register(String name, String email, String password) async {
    final j = await post('/auth/register',
      {'name': name, 'email': email, 'password': password, 'ageConfirmed': true}, public: true);
    _token = j['token'] as String;
    await storage.write(key: 'access_token', value: _token);
    return Map<String,dynamic>.from(j['user'] as Map);
  }

  Future<Map<String,dynamic>> get(String path) => _request('GET', path);
  Future<Map<String,dynamic>> post(String path, Map<String,dynamic> body,
      {bool public = false}) => _request('POST', path, body: body, public: public);
  Future<Map<String,dynamic>> patch(String path, Map<String,dynamic> body) =>
      _request('PATCH', path, body: body);
  Future<Map<String,dynamic>> delete(String path) => _request('DELETE', path);

  Future<Map<String,dynamic>> _request(String method, String path,
      {Map<String,dynamic>? body, bool public = false}) async {
    if (!hasValidUrl) {
      throw const ApiException('API_BASE_URL ভুল বা খালি। GitHub Actions Variables ঠিক করে নতুন APK বানান।');
    }
    final uri = Uri.parse('$base/api$path');
    final headers = <String,String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (_token != null && !public) 'Authorization': 'Bearer $_token',
    };
    try {
      final request = http.Request(method, uri);
      request.headers.addAll(headers);
      if (body != null) request.body = jsonEncode(body);
      // Render Free instances may need roughly a minute to start after sleeping.
      final sent = await request.send().timeout(const Duration(seconds: 85));
      final response = await http.Response.fromStream(sent)
          .timeout(const Duration(seconds: 20));
      Map<String,dynamic> data;
      try {
        final decoded = jsonDecode(response.body);
        if (decoded is! Map) throw const FormatException('Not an object');
        data = Map<String,dynamic>.from(decoded);
      } catch (_) {
        throw ApiException('সার্ভার JSON ডেটা দেয়নি (HTTP ${response.statusCode})।',
          statusCode: response.statusCode);
      }
      if (response.statusCode >= 400) {
        throw ApiException('${data['error'] ?? 'Server error'}',
          statusCode: response.statusCode);
      }
      return data;
    } on ApiException {
      rethrow;
    } on TimeoutException {
      throw const ApiException('সার্ভারের উত্তর পেতে দেরি হচ্ছে। আবার চেষ্টা করুন বা Server Test খুলুন।');
    } on SocketException {
      throw const ApiException('সার্ভারের DNS খুঁজে পাওয়া যাচ্ছে না। Server Test খুলে দেখুন।');
    } on http.ClientException catch (e) {
      if (e.message.contains('Failed host lookup') ||
          e.toString().contains('Failed host lookup')) {
        throw const ApiException('DNS ব্যর্থ: APK Internet Permission ও API_BASE_URL যাচাই করুন।');
      }
      throw const ApiException('নেটওয়ার্ক সংযোগ ব্যর্থ। Server Test-এ বিস্তারিত দেখুন।');
    } on HandshakeException {
      throw const ApiException('HTTPS নিরাপত্তা যাচাই ব্যর্থ হয়েছে।');
    } catch (_) {
      throw const ApiException('নেটওয়ার্ক বা সার্ভার ত্রুটি। Server Test চালান।');
    }
  }
}
