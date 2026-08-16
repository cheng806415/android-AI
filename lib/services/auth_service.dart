import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

class AuthUser {
  final String id;
  final String email;
  final String username;
  final String status;

  const AuthUser({
    required this.id,
    required this.email,
    required this.username,
    required this.status,
  });

  factory AuthUser.fromMap(Map<String, dynamic> map) {
    return AuthUser(
      id: map['id']?.toString() ?? '',
      email: map['email']?.toString() ?? '',
      username: map['username']?.toString() ?? '',
      status: map['status']?.toString() ?? 'active',
    );
  }
}

class AuthResult {
  final bool ok;
  final String message;
  final AuthUser? user;

  const AuthResult({required this.ok, required this.message, this.user});
}

class AuthService {
  static const String apiBaseUrl = 'http://103.236.70.249:8766/api';
  static const String _tokenKey = 'auth_token';
  static const String _userKey = 'auth_user';

  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage();

  Future<Map<String, dynamic>> _post(
    String path,
    Map<String, String> fields,
  ) async {
    final response = await http
        .post(
          Uri.parse('$apiBaseUrl$path'),
          headers: {'Content-Type': 'application/x-www-form-urlencoded'},
          body: fields,
        )
        .timeout(const Duration(seconds: 20));
    Map<String, dynamic> data;
    try {
      final decoded = jsonDecode(response.body);
      data = decoded is Map<String, dynamic>
          ? decoded
          : {'code': -1, 'msg': '服务器返回格式错误'};
    } catch (_) {
      data = {'code': -1, 'msg': '服务器返回格式错误'};
    }
    if (data['code'] != 0 &&
        (data['msg'] == null || data['msg'].toString().isEmpty)) {
      data['msg'] = '请求失败（HTTP ${response.statusCode}）';
    }
    return data;
  }

  Future<AuthResult> sendVerificationCode(String email) async {
    try {
      final data = await _post('/verification.php?action=send', {
        'email': email.trim(),
        'purpose': '注册',
        'format': 'numeric',
        'length': '6',
      });
      return AuthResult(
        ok: data['code'] == 0,
        message: data['msg']?.toString() ?? '请求失败',
      );
    } catch (_) {
      return const AuthResult(ok: false, message: '网络连接失败，请检查网络后重试');
    }
  }

  Future<AuthResult> register({
    required String email,
    required String code,
    required String password,
    String username = '',
  }) async {
    try {
      final data = await _post('/register.php', {
        'email': email.trim(),
        'code': code.trim(),
        'password': password,
        'username': username.trim(),
      });
      return AuthResult(
        ok: data['code'] == 0,
        message: data['msg']?.toString() ?? '注册失败',
      );
    } catch (_) {
      return const AuthResult(ok: false, message: '网络连接失败，请检查网络后重试');
    }
  }

  Future<AuthResult> login({
    required String email,
    required String password,
  }) async {
    try {
      final data = await _post('/login.php?action=user_login', {
        'email': email.trim(),
        'password': password,
      });
      if (data['code'] != 0) {
        return AuthResult(
            ok: false, message: data['msg']?.toString() ?? '登录失败');
      }
      final payload = data['data'];
      if (payload is! Map<String, dynamic>) {
        return const AuthResult(ok: false, message: '登录响应格式错误');
      }
      final token = payload['token']?.toString() ?? '';
      final userData = payload['user'];
      if (token.isEmpty || userData is! Map<String, dynamic>) {
        return const AuthResult(ok: false, message: '登录响应缺少账号信息');
      }
      final user = AuthUser.fromMap(userData);
      await _secureStorage.write(key: _tokenKey, value: token);
      await _secureStorage.write(key: _userKey, value: jsonEncode(userData));
      return AuthResult(
          ok: true, message: data['msg']?.toString() ?? '登录成功', user: user);
    } catch (_) {
      return const AuthResult(ok: false, message: '网络连接失败，请检查网络后重试');
    }
  }

  Future<AuthUser?> loadUser() async {
    final token = await _secureStorage.read(key: _tokenKey);
    final rawUser = await _secureStorage.read(key: _userKey);
    if (token == null || token.isEmpty || rawUser == null) return null;
    try {
      final data = jsonDecode(rawUser);
      if (data is Map<String, dynamic>) return AuthUser.fromMap(data);
    } catch (_) {}
    return null;
  }

  Future<bool> checkSession() async {
    final token = await _secureStorage.read(key: _tokenKey);
    if (token == null || token.isEmpty) return false;
    try {
      final response = await http.get(
        Uri.parse('$apiBaseUrl/login.php?action=user_check'),
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 15));
      final data = jsonDecode(response.body);
      if (data is Map<String, dynamic> && data['code'] == 0) {
        final payload = data['data'];
        final userData =
            payload is Map<String, dynamic> ? payload['user'] : null;
        if (userData is Map<String, dynamic>) {
          await _secureStorage.write(
              key: _userKey, value: jsonEncode(userData));
        }
        return true;
      }
    } catch (_) {}
    await clearSession();
    return false;
  }

  Future<void> logout() async {
    final token = await _secureStorage.read(key: _tokenKey);
    if (token != null && token.isNotEmpty) {
      try {
        await http.post(
          Uri.parse('$apiBaseUrl/login.php?action=user_logout'),
          headers: {'Authorization': 'Bearer $token'},
        ).timeout(const Duration(seconds: 10));
      } catch (_) {}
    }
    await clearSession();
  }

  Future<void> clearSession() async {
    await _secureStorage.delete(key: _tokenKey);
    await _secureStorage.delete(key: _userKey);
  }
}
