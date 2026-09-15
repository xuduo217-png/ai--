import 'package:flutter/foundation.dart';

import '../../auth/presentation/auth_controller.dart';
import '../../profile/domain/profile_models.dart';
import '../domain/settings_models.dart';

class SettingsController extends ChangeNotifier {
  SettingsController({
    required SettingsGateway settingsGateway,
    required ProfileGateway accountGateway,
    required AuthController authController,
  }) : _settingsGateway = settingsGateway,
       _accountGateway = accountGateway,
       _authController = authController;

  final SettingsGateway _settingsGateway;
  final ProfileGateway _accountGateway;
  final AuthController _authController;

  ContactInfo _contactInfo = ContactInfo.empty;
  Object? _contactError;
  Object? _accountActionError;
  bool _loadingContact = false;
  bool _loggingOut = false;
  bool _deletingAccount = false;
  bool _disposed = false;

  ContactInfo get contactInfo => _contactInfo;
  Object? get contactError => _contactError;
  Object? get accountActionError => _accountActionError;
  bool get loadingContact => _loadingContact;
  bool get loggingOut => _loggingOut;
  bool get deletingAccount => _deletingAccount;
  bool get accountActionInProgress => _loggingOut || _deletingAccount;

  Future<void> loadContactInfo() async {
    if (_loadingContact) return;
    _loadingContact = true;
    _contactError = null;
    _notify();
    try {
      _contactInfo = await _settingsGateway.loadContactInfo();
    } on Object catch (error) {
      _contactInfo = ContactInfo.empty;
      _contactError = error;
    } finally {
      _loadingContact = false;
      _notify();
    }
  }

  Future<bool> logout() async {
    if (accountActionInProgress) return false;
    _loggingOut = true;
    _accountActionError = null;
    _notify();
    try {
      await _authController.logout();
      return true;
    } on Object catch (error) {
      _accountActionError = error;
      return false;
    } finally {
      _loggingOut = false;
      _notify();
    }
  }

  Future<bool> deleteAccount() async {
    if (accountActionInProgress) return false;
    _deletingAccount = true;
    _accountActionError = null;
    _notify();
    try {
      await _accountGateway.deleteAccount();
      await _authController.invalidateLocalSession();
      return true;
    } on Object catch (error) {
      _accountActionError = error;
      return false;
    } finally {
      _deletingAccount = false;
      _notify();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }
}

class SystemArticleController extends ChangeNotifier {
  SystemArticleController({
    required SettingsGateway gateway,
    required this.type,
  }) : _gateway = gateway;

  final SettingsGateway _gateway;
  final SystemArticleType type;

  SystemArticle? _article;
  Object? _error;
  bool _loading = false;
  bool _disposed = false;

  SystemArticle? get article => _article;
  Object? get error => _error;
  bool get loading => _loading;
  bool get isEmpty =>
      !_loading && _error == null && (_article?.isEmpty ?? true);

  Future<void> load() async {
    if (_loading) return;
    _loading = true;
    _error = null;
    _notify();
    try {
      _article = await _gateway.loadArticle(type);
    } on Object catch (error) {
      _article = null;
      _error = error;
    } finally {
      _loading = false;
      _notify();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }
}
