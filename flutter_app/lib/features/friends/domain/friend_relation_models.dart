import 'friend_messaging_models.dart';

enum FriendRequestStatus {
  pending,
  accepted,
  rejected,
  expired;

  static FriendRequestStatus fromJson(Object? value) {
    return switch ('$value') {
      'accepted' => accepted,
      'rejected' => rejected,
      'expired' => expired,
      _ => pending,
    };
  }
}

enum SendFriendRequestStatus {
  sent,
  outgoingPending,
  incomingPending,
  alreadyFriends,
  self;

  static SendFriendRequestStatus fromJson(Object? value) {
    return switch ('$value') {
      'sent' => sent,
      'outgoing_pending' => outgoingPending,
      'incoming_pending' => incomingPending,
      'already_friends' => alreadyFriends,
      'self' => self,
      _ => throw FormatException('Unknown friend request status: $value'),
    };
  }
}

class FriendRequest {
  const FriendRequest({
    required this.id,
    required this.requestId,
    required this.requesterId,
    required this.requesterName,
    required this.status,
    required this.createdAt,
    this.requesterAvatar,
    this.requesterPhone,
    this.message,
    this.rejectionReason,
    this.expiresAt,
  });

  final int id;
  final String requestId;
  final int requesterId;
  final String requesterName;
  final String? requesterAvatar;
  final String? requesterPhone;
  final String? message;
  final FriendRequestStatus status;
  final String? rejectionReason;
  final DateTime createdAt;
  final DateTime? expiresAt;

  factory FriendRequest.fromJson(Map<String, Object?> json) {
    final id = _requiredInt(json['id'] ?? json['requestId'], 'requestId');
    return FriendRequest(
      id: id,
      requestId: _nullableString(json['requestId']) ?? '$id',
      requesterId: _requiredInt(json['requesterId'], 'requesterId'),
      requesterName:
          _nullableString(json['requesterName']) ??
          '用户${_requiredInt(json['requesterId'], 'requesterId')}',
      requesterAvatar: _nullableString(json['requesterAvatar']),
      requesterPhone: _nullableString(json['requesterPhone']),
      message: _nullableString(json['message']),
      status: FriendRequestStatus.fromJson(json['status']),
      rejectionReason: _nullableString(json['rejectionReason']),
      createdAt:
          parseFriendDateTime(json['createdAt']) ?? DateTime.now().toUtc(),
      expiresAt: parseFriendDateTime(json['expiresAt']),
    );
  }
}

class UserSearchResult {
  const UserSearchResult({
    required this.id,
    required this.username,
    required this.phone,
    this.avatar,
    this.signature,
  });

  final int id;
  final String username;
  final String phone;
  final String? avatar;
  final String? signature;

  String get displayName {
    final name = username.trim();
    if (name.isNotEmpty) return name;
    final phoneValue = phone.trim();
    return phoneValue.isNotEmpty ? phoneValue : '用户$id';
  }

  factory UserSearchResult.fromJson(Map<String, Object?> json) {
    return UserSearchResult(
      id: _requiredInt(json['id'], 'id'),
      username: _nullableString(json['username']) ?? '',
      phone: _nullableString(json['phone']) ?? '',
      avatar: _nullableString(json['avatar']),
      signature: _nullableString(json['signature']),
    );
  }
}

class SearchUserResult {
  const SearchUserResult({required this.found, this.user, this.message});

  final bool found;
  final UserSearchResult? user;
  final String? message;

  factory SearchUserResult.fromJson(Map<String, Object?> json) {
    final rawUser = json['user'];
    return SearchUserResult(
      found: json['found'] == true,
      user: rawUser is Map
          ? UserSearchResult.fromJson(Map<String, Object?>.from(rawUser))
          : null,
      message: _nullableString(json['message']),
    );
  }
}

class SendFriendRequestResult {
  const SendFriendRequestResult({
    required this.success,
    required this.status,
    required this.message,
    this.requestId,
  });

  final bool success;
  final SendFriendRequestStatus status;
  final String message;
  final int? requestId;

  factory SendFriendRequestResult.fromJson(Map<String, Object?> json) {
    return SendFriendRequestResult(
      success: json['success'] == true,
      status: SendFriendRequestStatus.fromJson(json['status']),
      message: _nullableString(json['message']) ?? '好友申请请求已处理',
      requestId: _optionalInt(json['requestId']),
    );
  }
}

class FriendRelationshipSummary {
  const FriendRelationshipSummary({
    required this.isFriend,
    required this.outgoingPending,
    required this.incomingPending,
    this.blockedByMe = false,
    bool? canSendMessage,
  }) : canSendMessage = canSendMessage ?? isFriend;

  final bool isFriend;
  final bool outgoingPending;
  final bool incomingPending;
  final bool blockedByMe;
  final bool canSendMessage;

  FriendRelationshipSummary copyWith({
    bool? isFriend,
    bool? outgoingPending,
    bool? incomingPending,
    bool? blockedByMe,
    bool? canSendMessage,
  }) {
    return FriendRelationshipSummary(
      isFriend: isFriend ?? this.isFriend,
      outgoingPending: outgoingPending ?? this.outgoingPending,
      incomingPending: incomingPending ?? this.incomingPending,
      blockedByMe: blockedByMe ?? this.blockedByMe,
      canSendMessage: canSendMessage ?? this.canSendMessage,
    );
  }

  factory FriendRelationshipSummary.fromJson(Map<String, Object?> json) {
    final isFriend = json['isFriend'] == true;
    return FriendRelationshipSummary(
      isFriend: isFriend,
      outgoingPending: json['outgoingPending'] == true,
      incomingPending: json['incomingPending'] == true,
      blockedByMe: json['blockedByMe'] == true,
      canSendMessage: json.containsKey('canSendMessage')
          ? json['canSendMessage'] == true
          : isFriend,
    );
  }
}

class FriendChatBlock {
  const FriendChatBlock({
    required this.id,
    required this.blockedUserId,
    required this.blockedUserName,
    required this.blockedAt,
    this.blockedUserAvatar,
  });

  final int id;
  final int blockedUserId;
  final String blockedUserName;
  final String? blockedUserAvatar;
  final DateTime blockedAt;

  factory FriendChatBlock.fromJson(Map<String, Object?> json) {
    final blockedUserId = _requiredInt(json['blockedUserId'], 'blockedUserId');
    final rawUser = json['blockedUser'];
    final user = rawUser is Map
        ? Map<String, Object?>.from(rawUser)
        : const <String, Object?>{};
    return FriendChatBlock(
      id: _requiredInt(json['id'], 'id'),
      blockedUserId: blockedUserId,
      blockedUserName: _nullableString(user['username']) ?? '用户$blockedUserId',
      blockedUserAvatar: _nullableString(user['avatar']),
      blockedAt:
          parseFriendDateTime(json['blockedAt'] ?? json['createdAt']) ??
          DateTime.now().toUtc(),
    );
  }
}

class FriendRequestAcceptedEvent {
  const FriendRequestAcceptedEvent({
    required this.requestId,
    required this.friendId,
    required this.friendName,
    this.acceptedAt,
  });

  final String requestId;
  final int friendId;
  final String friendName;
  final DateTime? acceptedAt;

  factory FriendRequestAcceptedEvent.fromJson(Map<String, Object?> json) {
    return FriendRequestAcceptedEvent(
      requestId: _requiredString(json['requestId'], 'requestId'),
      friendId: _requiredInt(json['friendId'], 'friendId'),
      friendName:
          _nullableString(json['friendName']) ??
          '用户${_requiredInt(json['friendId'], 'friendId')}',
      acceptedAt: parseFriendDateTime(json['acceptedAt']),
    );
  }
}

class FriendRequestRejectedEvent {
  const FriendRequestRejectedEvent({
    required this.requestId,
    required this.receiverId,
    this.receiverName,
    this.reason,
    this.rejectedAt,
  });

  final String requestId;
  final int receiverId;
  final String? receiverName;
  final String? reason;
  final DateTime? rejectedAt;

  factory FriendRequestRejectedEvent.fromJson(Map<String, Object?> json) {
    return FriendRequestRejectedEvent(
      requestId: _requiredString(json['requestId'], 'requestId'),
      receiverId: _requiredInt(json['receiverId'], 'receiverId'),
      receiverName: _nullableString(json['receiverName']),
      reason: _nullableString(json['reason']),
      rejectedAt: parseFriendDateTime(json['rejectedAt']),
    );
  }
}

int _requiredInt(Object? value, String name) {
  final parsed = _optionalInt(value);
  if (parsed != null) return parsed;
  throw FormatException('$name must be an integer.');
}

int? _optionalInt(Object? value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse('$value');
}

String _requiredString(Object? value, String name) {
  final result = _nullableString(value);
  if (result != null) return result;
  throw FormatException('$name must be a non-empty string.');
}

String? _nullableString(Object? value) {
  if (value == null) return null;
  final result = '$value'.trim();
  return result.isEmpty || result == 'null' ? null : result;
}
