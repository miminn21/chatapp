import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../services/api_service.dart';
import '../models/user_model.dart';

enum AuthStatus { unknown, authenticated, unauthenticated }

class AuthProvider extends ChangeNotifier {
  AuthStatus _status = AuthStatus.unknown;
  UserModel? _user;
  String? _token;
  String? _error;
  bool _loading = false;

  AuthStatus get status => _status;
  UserModel? get user => _user;
  String? get token => _token;
  String? get error => _error;
  bool get loading => _loading;
  bool get isAuthenticated => _status == AuthStatus.authenticated;

  AuthProvider() {
    apiService.init();
    _loadFromStorage();
  }

  Future<void> _loadFromStorage() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('auth_token');
    final userId = prefs.getString('user_id');
    if (_token != null && userId != null) {
      try {
        final resp = await apiService.get('/users/me');
        if (resp.data['success'] == true) {
          _user = UserModel.fromJson(resp.data['data']);
          _status = AuthStatus.authenticated;
          syncFcmToken(); // Sync token on app start if authenticated
        } else {
          await _clearStorage();
          _status = AuthStatus.unauthenticated;
        }
      } catch (_) {
        _status = AuthStatus.unauthenticated;
      }
    } else {
      _status = AuthStatus.unauthenticated;
    }
    notifyListeners();
  }

  Future<bool> register({
    required String name,
    required String phone,
    required String password,
    String? email,
  }) async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final resp = await apiService.post(
        '/auth/register',
        data: {
          'name': name,
          'phone': phone,
          'password': password,
          if (email != null) 'email': email,
        },
      );
      if (resp.data['success'] == true) {
        final data = resp.data['data'];
        _token = data['token'];
        _user = UserModel.fromJson(data);
        await _saveToStorage();
        _status = AuthStatus.authenticated;
        _loading = false;
        notifyListeners();
        return true;
      }
      _error = resp.data['message'];
    } catch (e) {
      _error = _parseError(e);
    }
    _loading = false;
    notifyListeners();
    return false;
  }

  Future<bool> login({required String phone, required String password}) async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final resp = await apiService.post(
        '/auth/login',
        data: {'phone': phone, 'password': password},
      );
      if (resp.data['success'] == true) {
        final data = resp.data['data'];
        _token = data['token'];
        _user = UserModel.fromJson(data);
        await _saveToStorage();
        _status = AuthStatus.authenticated;
        syncFcmToken();
        _loading = false;
        notifyListeners();
        return true;
      }
      _error = resp.data['message'];
    } catch (e) {
      _error = _parseError(e);
    }
    _loading = false;
    notifyListeners();
    return false;
  }

  Future<void> logout() async {
    try {
      await apiService.post('/auth/logout');
    } catch (_) {}
    await _clearStorage();
    _user = null;
    _token = null;
    _status = AuthStatus.unauthenticated;
    notifyListeners();
  }

  /// Called after Firebase-based registration. Stores the returned token + user
  /// data directly without making a new API call.
  Future<void> loginWithToken(String token, Map<String, dynamic> data) async {
    _token = token;
    _user = UserModel.fromJson(data);
    await _saveToStorage();
    _status = AuthStatus.authenticated;
    syncFcmToken();
    notifyListeners();
  }

  Future<bool> updateProfile({
    String? name,
    String? statusMessage,
    String? email,
    String? bio,
  }) async {
    try {
      final resp = await apiService.put(
        '/users/me',
        data: {
          if (name != null) 'name': name,
          if (statusMessage != null) 'status_message': statusMessage,
          if (email != null) 'email': email,
          if (bio != null) 'bio': bio,
        },
      );
      if (resp.data['success'] == true) {
        _user = UserModel.fromJson(resp.data['data']);
        notifyListeners();
        return true;
      }
    } catch (_) {}
    return false;
  }

  /// Called after successful avatar upload to update in-memory user
  void updateAvatarLocal(String newAvatarPath) {
    _user = _user?.copyWith(avatar: newAvatarPath);
    notifyListeners();
  }

  /// Called after successful cover upload to update in-memory user
  void updateCoverLocal(String newCoverPath) {
    _user = _user?.copyWith(coverPhoto: newCoverPath);
    notifyListeners();
  }

  Future<void> _saveToStorage() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', _token ?? '');
    await prefs.setString('user_id', _user?.id ?? '');
  }

  Future<void> _clearStorage() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
    await prefs.remove('user_id');
  }

  Future<void> syncFcmToken() async {
    try {
      if (!isAuthenticated) return;

      FirebaseMessaging messaging = FirebaseMessaging.instance;
      NotificationSettings settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        String? token = await messaging.getToken();
        if (token != null) {
          await apiService.post('/users/me/fcm-token', data: {'token': token});
          // print("🚀 FCM Token Synced: $token");
        }
      }
    } catch (e) {
      debugPrint("❌ Sync FCM Error: $e");
    }
  }

  String _parseError(dynamic e) {
    if (e is Exception) return e.toString().replaceAll('Exception: ', '');
    return 'Terjadi kesalahan, coba lagi';
  }
}
