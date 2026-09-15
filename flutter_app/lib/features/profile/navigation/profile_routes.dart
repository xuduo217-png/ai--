import '../../mall/order/domain/order_models.dart';
import '../../mall/order/domain/after_sale_models.dart';

const profileUnsupportedDestinationMessage = '暂不支持打开该通知内容';

sealed class ProfileDestination {
  const ProfileDestination();
}

sealed class ProfileOwnedDestination extends ProfileDestination {
  const ProfileOwnedDestination();

  String get key;
}

class ProfilePetsDestination extends ProfileOwnedDestination {
  const ProfilePetsDestination();

  @override
  String get key => 'pets';
}

class ProfileMedicalOrdersDestination extends ProfileOwnedDestination {
  const ProfileMedicalOrdersDestination();

  @override
  String get key => 'medical-orders';
}

class ProfileNotificationsDestination extends ProfileOwnedDestination {
  const ProfileNotificationsDestination();

  @override
  String get key => 'notifications';
}

class ProfileLostFoundPostsDestination extends ProfileOwnedDestination {
  const ProfileLostFoundPostsDestination();

  @override
  String get key => 'lost-found-posts';
}

class ProfileCommunityDestination extends ProfileOwnedDestination {
  const ProfileCommunityDestination();

  @override
  String get key => 'community';
}

class ProfileCouponsDestination extends ProfileOwnedDestination {
  const ProfileCouponsDestination();

  @override
  String get key => 'coupons';
}

class ProfileSettingsDestination extends ProfileOwnedDestination {
  const ProfileSettingsDestination();

  @override
  String get key => 'settings';
}

class ProfileWalletDestination extends ProfileOwnedDestination {
  const ProfileWalletDestination();

  @override
  String get key => 'wallet';
}

class ProfileWalletWithdrawalDetailDestination extends ProfileOwnedDestination {
  const ProfileWalletWithdrawalDetailDestination(this.withdrawalId);

  final int withdrawalId;

  @override
  String get key => 'wallet-withdrawal-$withdrawalId';
}

class ProfileOrdersDestination extends ProfileDestination {
  const ProfileOrdersDestination();
}

class ProfileSalesDestination extends ProfileDestination {
  const ProfileSalesDestination();
}

class ProfileAddressesDestination extends ProfileDestination {
  const ProfileAddressesDestination();
}

class ProfileFavoritesDestination extends ProfileDestination {
  const ProfileFavoritesDestination();
}

class ProfilePublishedProductsDestination extends ProfileDestination {
  const ProfilePublishedProductsDestination();
}

class ProfileOrderDetailDestination extends ProfileDestination {
  const ProfileOrderDetailDestination(this.args);

  final OrderRouteArgs args;
}

class ProfileAfterSaleDestination extends ProfileDestination {
  const ProfileAfterSaleDestination(this.args);

  final AfterSaleRouteArgs args;
}

class ProfileProductDestination extends ProfileDestination {
  const ProfileProductDestination(this.args);

  final ProductRouteArgs args;
}

class ProfileAppointmentDestination extends ProfileDestination {
  const ProfileAppointmentDestination(this.appointmentId);

  final int appointmentId;
}

class ProfileHealthAppointmentDestination extends ProfileDestination {
  const ProfileHealthAppointmentDestination(this.appointmentId);

  final int appointmentId;
}

class ProfileCommunityPostDestination extends ProfileDestination {
  const ProfileCommunityPostDestination(this.postId);

  final int postId;
}

class ProfileCommunityUserDestination extends ProfileDestination {
  const ProfileCommunityUserDestination(this.userId);

  final int userId;
}

class ProfileChatDestination extends ProfileDestination {
  const ProfileChatDestination(this.conversationId);

  final String conversationId;
}

class ProfileUrlDestination extends ProfileDestination {
  const ProfileUrlDestination(this.url);

  final String url;
}

class ProfileHomeDestination extends ProfileDestination {
  const ProfileHomeDestination();
}

class ProfileNoActionDestination extends ProfileDestination {
  const ProfileNoActionDestination();
}

enum ProfileUnsupportedReason { malformedData, externalDomain, unknownAction }

class ProfileUnsupportedDestination extends ProfileDestination {
  const ProfileUnsupportedDestination(this.reason);

  final ProfileUnsupportedReason reason;
}

class ProfileNotificationAction {
  const ProfileNotificationAction({required this.actionType, this.actionData});

  final String? actionType;
  final Object? actionData;
}

ProfileDestination parseProfileNotificationDestination(
  ProfileNotificationAction action,
) {
  final actionType = action.actionType?.trim().toLowerCase() ?? '';
  if (actionType.isEmpty || actionType == 'none') {
    return const ProfileNoActionDestination();
  }

  final data = _stringKeyedMap(action.actionData);
  return switch (actionType) {
    'order' => _orderDestination(data),
    'appointment' => _appointmentDestination(data),
    'page' => _pageDestination(data),
    'url' => _urlDestination(data),
    _ => const ProfileUnsupportedDestination(
      ProfileUnsupportedReason.unknownAction,
    ),
  };
}

ProfileDestination _appointmentDestination(Map<String, Object?>? data) {
  final appointmentId = _positiveInt(data?['appointmentId']);
  final appointmentKind = data?['appointmentKind'];
  if (appointmentId == null || appointmentKind is! String) {
    return const ProfileUnsupportedDestination(
      ProfileUnsupportedReason.malformedData,
    );
  }
  return switch (appointmentKind.trim().toLowerCase()) {
    'standard' => ProfileAppointmentDestination(appointmentId),
    'health' => ProfileHealthAppointmentDestination(appointmentId),
    _ => const ProfileUnsupportedDestination(
      ProfileUnsupportedReason.malformedData,
    ),
  };
}

ProfileDestination _urlDestination(Map<String, Object?>? data) {
  final url = data?['url'];
  if (url is! String || url.trim().isEmpty) {
    return const ProfileUnsupportedDestination(
      ProfileUnsupportedReason.malformedData,
    );
  }
  return ProfileUrlDestination(url.trim());
}

ProfileDestination _orderDestination(Map<String, Object?>? data) {
  final viewRole = OrderViewRole.fromJson(data?['viewRole']);
  final afterSaleId = _positiveInt(data?['afterSaleId']);
  if (afterSaleId != null) {
    return ProfileAfterSaleDestination(
      AfterSaleRouteArgs(afterSaleId, viewRole: viewRole),
    );
  }
  final orderId = _positiveInt(data?['orderId']);
  if (orderId == null) {
    return const ProfileUnsupportedDestination(
      ProfileUnsupportedReason.malformedData,
    );
  }
  return ProfileOrderDetailDestination(
    OrderRouteArgs(orderId, viewRole: viewRole),
  );
}

ProfileDestination _pageDestination(Map<String, Object?>? data) {
  final path = data?['path'];
  if (path is! String || path.trim().isEmpty) {
    return const ProfileUnsupportedDestination(
      ProfileUnsupportedReason.malformedData,
    );
  }

  final params = _stringKeyedMap(data?['params']);
  return switch (path.trim()) {
    'Home' => const ProfileHomeDestination(),
    'PetList' => const ProfilePetsDestination(),
    'OrderList' => const ProfileOrdersDestination(),
    'SalesOrderList' => const ProfileSalesDestination(),
    'MedicalServiceOrderList' => const ProfileMedicalOrdersDestination(),
    'AddressList' => const ProfileAddressesDestination(),
    'Notifications' => const ProfileNotificationsDestination(),
    'CommunityProfile' => const ProfileCommunityDestination(),
    'MyCoupons' => const ProfileCouponsDestination(),
    'MyFavorites' => const ProfileFavoritesDestination(),
    'MyPublishedProducts' => const ProfilePublishedProductsDestination(),
    'SystemConfig' || 'SecuritySettings' => const ProfileSettingsDestination(),
    'MyIncome' || 'MyWallet' => const ProfileWalletDestination(),
    'WalletWithdrawalDetail' => _idDestination(
      params?['withdrawalId'] ?? params?['id'] ?? data?['withdrawalId'],
      ProfileWalletWithdrawalDetailDestination.new,
    ),
    'OrderDetail' => _idDestination(
      params?['orderId'] ?? params?['id'] ?? data?['orderId'],
      (id) => ProfileOrderDetailDestination(OrderRouteArgs(id)),
    ),
    'AfterSaleDetail' => _afterSaleDestination(params ?? data),
    'ProductDetail' => _idDestination(
      params?['productId'] ?? params?['id'] ?? data?['productId'],
      (id) => ProfileProductDestination(ProductRouteArgs(id)),
    ),
    'PostDetail' => _idDestination(
      params?['postId'] ?? params?['id'] ?? data?['postId'],
      ProfileCommunityPostDestination.new,
    ),
    'UserProfile' => _idDestination(
      params?['userId'] ?? params?['id'] ?? data?['userId'],
      ProfileCommunityUserDestination.new,
    ),
    'Chat' => _chatDestination(
      params?['conversationId'] ?? data?['conversationId'],
    ),
    _ => const ProfileUnsupportedDestination(
      ProfileUnsupportedReason.externalDomain,
    ),
  };
}

ProfileDestination _afterSaleDestination(Map<String, Object?>? data) {
  final afterSaleId = _positiveInt(data?['afterSaleId'] ?? data?['id']);
  if (afterSaleId == null) {
    return const ProfileUnsupportedDestination(
      ProfileUnsupportedReason.malformedData,
    );
  }
  return ProfileAfterSaleDestination(
    AfterSaleRouteArgs(
      afterSaleId,
      viewRole: OrderViewRole.fromJson(data?['viewRole']),
    ),
  );
}

ProfileDestination _chatDestination(Object? value) {
  if (value is! String || value.trim().isEmpty) {
    return const ProfileUnsupportedDestination(
      ProfileUnsupportedReason.malformedData,
    );
  }
  return ProfileChatDestination(value.trim());
}

ProfileDestination _idDestination(
  Object? value,
  ProfileDestination Function(int id) builder,
) {
  final id = _positiveInt(value);
  if (id == null) {
    return const ProfileUnsupportedDestination(
      ProfileUnsupportedReason.malformedData,
    );
  }
  return builder(id);
}

Map<String, Object?>? _stringKeyedMap(Object? value) {
  if (value is! Map) return null;
  return <String, Object?>{
    for (final entry in value.entries)
      if (entry.key is String) entry.key as String: entry.value,
  };
}

int? _positiveInt(Object? value) {
  final parsed = switch (value) {
    final int number => number,
    final num number => number.toInt(),
    _ => int.tryParse(value?.toString().trim() ?? ''),
  };
  return parsed != null && parsed > 0 ? parsed : null;
}
