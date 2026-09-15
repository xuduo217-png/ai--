import 'package:flutter/foundation.dart';

import '../domain/address_models.dart';

class AddressController extends ChangeNotifier {
  AddressController(this._gateway);
  final AddressGateway _gateway;

  List<ShippingAddress> addresses = const [];
  bool loading = false;
  String? errorMessage;
  bool _disposed = false;
  int _requestRevision = 0;

  ShippingAddress? get defaultAddress {
    for (final address in addresses) {
      if (address.isDefault) return address;
    }
    return addresses.firstOrNull;
  }

  Future<void> load() async {
    if (_disposed) return;
    final revision = ++_requestRevision;
    loading = true;
    errorMessage = null;
    _notify();
    try {
      final result = await _gateway.loadAddresses();
      if (!_isCurrent(revision)) return;
      addresses = result;
    } catch (error) {
      if (!_isCurrent(revision)) return;
      errorMessage = '$error';
    } finally {
      if (_isCurrent(revision)) {
        loading = false;
        _notify();
      }
    }
  }

  Future<void> save({
    ShippingAddress? existing,
    required AddressInput input,
  }) async {
    if (_disposed) return;
    final error = input.validate();
    if (error != null) throw ArgumentError(error);
    if (existing == null) {
      await _gateway.createAddress(input);
    } else {
      await _gateway.updateAddress(existing.id, input);
    }
    if (!_disposed) await load();
  }

  Future<void> remove(int id) async {
    if (_disposed) return;
    await _gateway.deleteAddress(id);
    if (!_disposed) await load();
  }

  Future<void> setDefault(int id) async {
    if (_disposed) return;
    await _gateway.setDefaultAddress(id);
    if (!_disposed) await load();
  }

  bool _isCurrent(int revision) => !_disposed && revision == _requestRevision;

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _requestRevision += 1;
    super.dispose();
  }
}
