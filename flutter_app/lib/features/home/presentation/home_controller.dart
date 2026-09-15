import 'package:flutter/foundation.dart';

import '../domain/home_models.dart';

class HomeController extends ChangeNotifier {
  HomeController({required HomeGateway gateway, required this.authenticated})
    : _gateway = gateway;

  final HomeGateway _gateway;
  final bool authenticated;

  HomeSnapshot snapshot = const HomeSnapshot();
  bool loading = true;
  bool refreshing = false;

  Future<void> load() async {
    loading = true;
    notifyListeners();
    try {
      snapshot = await _gateway.loadHome(authenticated: authenticated);
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> refresh() async {
    refreshing = true;
    notifyListeners();
    try {
      snapshot = await _gateway.loadHome(authenticated: authenticated);
    } finally {
      refreshing = false;
      notifyListeners();
    }
  }
}
