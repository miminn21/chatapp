import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../models/user_model.dart';

class ContactProvider extends ChangeNotifier {
  List<Map<String, dynamic>> _contacts = [];
  List<UserModel> _searchResults = [];
  bool _loading = false;

  List<Map<String, dynamic>> get contacts => _contacts;
  List<UserModel> get searchResults => _searchResults;
  bool get loading => _loading;

  Future<void> loadContacts() async {
    _loading = true;
    notifyListeners();
    try {
      final resp = await apiService.get('/contacts');
      if (resp.data['success'] == true) {
        _contacts = List<Map<String, dynamic>>.from(resp.data['data']);
      }
    } catch (e) {
      debugPrint('loadContacts error: $e');
    }
    _loading = false;
    notifyListeners();
  }

  Future<bool> addContact(String contactUserId, {String? nickname}) async {
    try {
      final resp = await apiService.post(
        '/contacts',
        data: {
          'contact_user_id': contactUserId,
          if (nickname != null) 'nickname': nickname,
        },
      );
      if (resp.data['success'] == true) {
        await loadContacts();
        return true;
      }
    } catch (e) {
      debugPrint('addContact error: $e');
    }
    return false;
  }

  Future<bool> deleteContact(String contactId) async {
    try {
      final resp = await apiService.delete('/contacts/$contactId');
      if (resp.data['success'] == true) {
        _contacts.removeWhere((c) => c['id'] == contactId);
        notifyListeners();
        return true;
      }
    } catch (e) {
      debugPrint('deleteContact error: $e');
    }
    return false;
  }

  Future<void> searchUsers(String query) async {
    if (query.length < 2) {
      _searchResults = [];
      notifyListeners();
      return;
    }
    try {
      final resp = await apiService.get('/users/search', params: {'q': query});
      if (resp.data['success'] == true) {
        _searchResults = (resp.data['data'] as List)
            .map((e) => UserModel.fromJson(e))
            .toList();
        notifyListeners();
      }
    } catch (e) {
      debugPrint('searchUsers error: $e');
    }
  }

  void clearSearch() {
    _searchResults = [];
    notifyListeners();
  }
}
