import 'package:flutter/foundation.dart';

import '../services/auth_service.dart';

class AuthProvider extends ChangeNotifier {
  final AuthService _service;

  AuthProvider(this._service);

  AuthUser? _user;
  bool _initialized = false;
  bool _loading = false;

  AuthUser? get user => _user;
  bool get isLoggedIn => _user != null;
  bool get isInitialized => _initialized;
  bool get isLoading => _loading;

  Future<void> init() async {
    if (_initialized) return;
    _user = await _service.loadUser();
    if (_user != null && !await _service.checkSession()) {
      _user = null;
    }
    _initialized = true;
    notifyListeners();
  }

  Future<AuthResult> login({
    required String email,
    required String password,
  }) async {
    _loading = true;
    notifyListeners();
    final result = await _service.login(email: email, password: password);
    if (result.ok) _user = result.user;
    _loading = false;
    notifyListeners();
    return result;
  }

  Future<AuthResult> sendVerificationCode(String email) {
    return _service.sendVerificationCode(email);
  }

  Future<AuthResult> register({
    required String email,
    required String code,
    required String password,
    String username = '',
  }) {
    return _service.register(
      email: email,
      code: code,
      password: password,
      username: username,
    );
  }

  Future<void> logout() async {
    await _service.logout();
    _user = null;
    notifyListeners();
  }
}
