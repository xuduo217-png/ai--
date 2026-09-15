import 'package:flutter/foundation.dart';

import '../data/friend_relations_repository.dart';
import '../domain/friend_relation_models.dart';

class FriendSearchController extends ChangeNotifier {
  FriendSearchController({
    required this.ownerUserId,
    required FriendRelationsRepositoryGateway repository,
  }) : _repository = repository;

  static final phonePattern = RegExp(r'^1[3-9]\d{9}$');

  final int ownerUserId;
  final FriendRelationsRepositoryGateway _repository;

  UserSearchResult? _result;
  String? _errorMessage;
  bool _notFound = false;
  bool _searching = false;
  bool _sending = false;

  UserSearchResult? get result => _result;
  String? get errorMessage => _errorMessage;
  bool get notFound => _notFound;
  bool get searching => _searching;
  bool get sending => _sending;
  bool get isSelfResult => _result?.id == ownerUserId;

  static String? validatePhone(String rawPhone) {
    final phone = rawPhone.trim();
    if (phone.isEmpty) return '请输入手机号';
    if (!phonePattern.hasMatch(phone)) return '请输入正确的手机号';
    return null;
  }

  Future<bool> search(String rawPhone) async {
    final phone = rawPhone.trim();
    final validationMessage = validatePhone(phone);
    if (validationMessage != null) {
      _errorMessage = validationMessage;
      _notFound = false;
      notifyListeners();
      return false;
    }
    _searching = true;
    _errorMessage = null;
    _notFound = false;
    _result = null;
    notifyListeners();
    try {
      final response = await _repository.searchUserByPhone(phone: phone);
      if (!response.found || response.user == null) {
        _notFound = true;
        _errorMessage = response.message ?? '用户不存在';
        return false;
      }
      _result = response.user;
      return true;
    } on Object catch (error) {
      _errorMessage = _readableError(error, '搜索失败，请稍后重试');
      return false;
    } finally {
      _searching = false;
      notifyListeners();
    }
  }

  Future<SendFriendRequestResult?> sendRequest(String rawMessage) async {
    final user = _result;
    if (user == null || user.id == ownerUserId || _sending) return null;
    if (rawMessage.length > 50) {
      _errorMessage = '申请附言最多 50 字';
      notifyListeners();
      return null;
    }
    _sending = true;
    _errorMessage = null;
    notifyListeners();
    try {
      return await _repository.sendFriendRequest(
        receiverId: user.id,
        message: rawMessage.trim(),
      );
    } on Object catch (error) {
      _errorMessage = _readableError(error, '发送失败，请稍后重试');
      return null;
    } finally {
      _sending = false;
      notifyListeners();
    }
  }

  void clearResult() {
    _result = null;
    _errorMessage = null;
    _notFound = false;
    notifyListeners();
  }
}

String _readableError(Object error, String fallback) {
  final text = error.toString().trim();
  if (text.isEmpty) return fallback;
  return text
      .replaceFirst('Exception: ', '')
      .replaceFirst('Invalid argument(s): ', '')
      .replaceFirst('Bad state: ', '');
}
