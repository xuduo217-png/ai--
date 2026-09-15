import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:pet_hospital_flutter/features/friends/domain/friend_media_content.dart';

void main() {
  test('图片 JSON 往返只保留规范字段', () {
    const content = FriendMediaContent(
      url: '/uploads/a.jpg',
      thumbnail: '/uploads/thumbnails/a.jpg',
      width: 1200,
      height: 900,
      size: 42,
      fileName: 'a.jpg',
      mimeType: 'image/jpeg',
    );

    final parsed = FriendMediaContent.parse(content.toMessageContent());

    expect(parsed?.url, '/uploads/a.jpg');
    expect(parsed?.thumbnail, '/uploads/thumbnails/a.jpg');
    expect(parsed?.width, 1200);
    expect(parsed?.height, 900);
    expect(jsonDecode(content.toMessageContent()), content.toJson());
  });

  test('视频兼容毫秒和秒时长', () {
    final milliseconds = FriendMediaContent.parse(
      '{"url":"/uploads/a.mp4","duration":90500}',
      type: FriendMediaType.video,
    );
    final seconds = FriendMediaContent.parse(
      '{"url":"/uploads/a.mp4","duration":90}',
      type: FriendMediaType.video,
    );

    expect(milliseconds?.duration, 91);
    expect(seconds?.duration, 90);
  });

  test('兼容历史纯 URL、缺失缩略图和额外字段', () {
    expect(
      FriendMediaContent.parse('/uploads/old.jpg')?.url,
      '/uploads/old.jpg',
    );
    final content = FriendMediaContent.parse(
      '{"url":"/uploads/a.mp4","future":true}',
      type: FriendMediaType.video,
    );
    expect(content?.thumbnail, isNull);
    expect(content?.url, '/uploads/a.mp4');
  });

  test('无效数字转空且空内容不可展示', () {
    final content = FriendMediaContent.parse(
      '{"url":"/uploads/a.jpg","width":"bad","height":-1,"size":0}',
    );
    expect(content?.width, isNull);
    expect(content?.height, isNull);
    expect(content?.size, isNull);
    expect(FriendMediaContent.parse(''), isNull);
    expect(FriendMediaContent.parse('{"url":""}'), isNull);
  });

  test('兼容 HTML 转义的 JSON 和 mime 别名', () {
    final content = FriendMediaContent.parse(
      '{&quot;url&quot;:&quot;/uploads/a.mp4&quot;,&quot;mime&quot;:&quot;video/mp4&quot;}',
      type: FriendMediaType.video,
    );
    expect(content?.mimeType, 'video/mp4');
  });
}
