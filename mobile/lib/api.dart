import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

class ApiException implements Exception {
  final String message;
  ApiException(this.message);
  @override String toString() => message;
}

class Api {
  static const base = String.fromEnvironment('API_BASE_URL', defaultValue: 'https://YOUR-RENDER-SERVICE.onrender.com');
  static const storage = FlutterSecureStorage();
  String? _token;
  String? get token => _token;
  Future<bool> restore() async {
    _token = await storage.read(key: 'access_token');
    if (_token == null) return false;
    try { await get('/me'); return true; } catch (_) { await logout(); return false; }
  }
  Future<void> logout() async { _token = null; await storage.delete(key: 'access_token'); }
  Future<Map<String,dynamic>> login(String email, String password) async {
    final j = await post('/auth/login', {'email': email, 'password': password}, public: true);
    _token = j['token'] as String;
    await storage.write(key:'access_token',value:_token);
    return Map<String,dynamic>.from(j['user'] as Map);
  }
  Future<Map<String,dynamic>> register(String name,String email,String password) async {
    final j = await post('/auth/register', {'name':name,'email':email,'password':password,'ageConfirmed':true},public:true);
    _token = j['token'] as String;
    await storage.write(key:'access_token',value:_token);
    return Map<String,dynamic>.from(j['user'] as Map);
  }
  Future<Map<String,dynamic>> get(String path) => _request('GET',path);
  Future<Map<String,dynamic>> post(String path, Map<String,dynamic> body,{bool public=false}) => _request('POST',path,body:body,public:public);
  Future<Map<String,dynamic>> patch(String path,Map<String,dynamic> body) => _request('PATCH',path,body:body);
  Future<Map<String,dynamic>> delete(String path) => _request('DELETE',path);
  Future<Map<String,dynamic>> _request(String method,String path,{Map<String,dynamic>? body, bool public=false}) async {
    if (!base.startsWith('https://') && !base.startsWith('http://10.0.2.2')) throw ApiException('Please configure the HTTPS server address.');
    final uri=Uri.parse('$base/api$path');
    final headers=<String,String>{'Content-Type':'application/json',if(_token!=null&&!public)'Authorization':'Bearer $_token'};
    try {
      final request=http.Request(method,uri);
      request.headers.addAll(headers);
      if(body!=null) request.body=jsonEncode(body);
      final s=await request.send().timeout(const Duration(seconds:20));
      final response=await http.Response.fromStream(s);
      final value=jsonDecode(response.body);
      if(value is! Map) throw ApiException('Unexpected server response');
      final data=Map<String,dynamic>.from(value);
      if(response.statusCode>=400) throw ApiException('${data['error']??'Server error'}');
      return data;
    } on ApiException {rethrow;} catch(e){throw ApiException('Network problem: $e');}
  }
}
