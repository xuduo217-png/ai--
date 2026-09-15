import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:pet_hospital_flutter/features/friends/domain/friend_messaging_models.dart';
import 'package:pet_hospital_flutter/features/friends/domain/friend_voice_content.dart';

void main() {
  group('FriendVoiceContent', () {
    test('JSON 往返保持 RN 语音协议且相对 URL 不做拼接', () {
      const content = FriendVoiceContent(
        url: '/uploads/chat/voice.m4a',
        duration: 12,
      );

      final encoded = content.toMessageContent();
      final decoded = jsonDecode(encoded) as Map<String, dynamic>;
      final parsed = FriendVoiceContent.parse(encoded);

      expect(decoded, {'url': '/uploads/chat/voice.m4a', 'duration': 12});
      expect(parsed?.url, '/uploads/chat/voice.m4a');
      expect(parsed?.duration, 12);
    });

    test('兼容历史纯 URL 与 HTML 转义 JSON', () {
      final historical = FriendVoiceContent.parse('/uploads/old.m4a');
      final escaped = FriendVoiceContent.parse(
        '{&quot;url&quot;:&quot;/uploads/new.m4a&quot;,'
        '&quot;duration&quot;:9}',
      );

      expect(historical?.url, '/uploads/old.m4a');
      expect(historical?.duration, 0);
      expect(escaped?.url, '/uploads/new.m4a');
      expect(escaped?.duration, 9);
    });

    test('毫秒时长归一化到 1 至 60 秒边界', () {
      expect(normalizeFriendVoiceDuration(0), 0);
      expect(normalizeFriendVoiceDuration(1), 1);
      expect(normalizeFriendVoiceDuration(65), 1);
      expect(normalizeFriendVoiceDuration(999), 1);
      expect(normalizeFriendVoiceDuration(1000), 1);
      expect(normalizeFriendVoiceDuration(1500), 2);
      expect(normalizeFriendVoiceDuration(60000), 60);
      expect(normalizeFriendVoiceDuration(double.nan), 0);
    });

    test('服务端 voice 消息初始化为已完成媒体状态', () {
      final message = FriendMessage.fromJson({
        'id': 18,
        'senderId': 2,
        'receiverId': 1,
        'messageType': 'voice',
        'content': '/uploads/old.m4a',
        'createdAt': '2026-07-24T08:00:00Z',
      });

      expect(message.sendStatus, MessageSendStatus.sent);
      expect(message.mediaStage, MediaTransferStage.sent);
    });
  });
}
