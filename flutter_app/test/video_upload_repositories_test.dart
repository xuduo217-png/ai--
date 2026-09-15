import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:pet_hospital_flutter/core/network/api_client.dart';
import 'package:pet_hospital_flutter/features/activity/data/activity_repository.dart';
import 'package:pet_hospital_flutter/features/community/data/community_repository.dart';
import 'package:pet_hospital_flutter/features/lost_found/data/lost_found_repository.dart';

void main() {
  late Directory directory;
  late File video;
  late File thumbnail;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('video-repository-test-');
    video = await File(
      '${directory.path}/pet-video.mp4',
    ).writeAsBytes([1, 2, 3]);
    thumbnail = await File(
      '${directory.path}/pet-video-cover.jpg',
    ).writeAsBytes([4, 5, 6]);
  });

  tearDown(() async {
    if (await directory.exists()) await directory.delete(recursive: true);
  });

  test('社区视频通过统一上传链路携带客户端封面', () async {
    final recordingClient = _VideoUploadClient();
    final repository = CommunityRepository(
      _apiClient(recordingClient, thumbnail),
    );

    final result = await repository.uploadCommunityVideo(
      filePath: video.path,
      filename: 'community.mp4',
    );

    _expectVideoAndThumbnail(recordingClient, 'community-post');
    expect(result.url, '/uploads/pet-video.mp4');
    expect(result.thumbnailUrl, '/uploads/thumbnails/pet-video-cover.jpg');
  });

  test('活动视频通过统一上传链路携带客户端封面', () async {
    final recordingClient = _VideoUploadClient();
    final repository = ActivityRepository(
      _apiClient(recordingClient, thumbnail),
    );

    final result = await repository.uploadActivityVideo(
      filePath: video.path,
      filename: 'activity.mp4',
    );

    _expectVideoAndThumbnail(recordingClient, 'activity-vote-option-video');
    expect(result.url, endsWith('/uploads/pet-video.mp4'));
    expect(
      result.thumbnailUrl,
      endsWith('/uploads/thumbnails/pet-video-cover.jpg'),
    );
  });

  test('走失领养视频通过统一上传链路携带客户端封面', () async {
    final recordingClient = _VideoUploadClient();
    final repository = LostFoundRepository(
      _apiClient(recordingClient, thumbnail),
    );

    final result = await repository.uploadLostFoundVideo(
      filePath: video.path,
      filename: 'lost-found.mp4',
    );

    _expectVideoAndThumbnail(recordingClient, 'lost-found-video');
    expect(result.url, '/uploads/pet-video.mp4');
    expect(result.thumbnailUrl, '/uploads/thumbnails/pet-video-cover.jpg');
  });
}

ApiClient _apiClient(_VideoUploadClient client, File thumbnail) {
  return ApiClient(
    baseUrl: 'https://example.test/server-api',
    client: client,
    tokenProvider: () async => 'video-token',
    videoThumbnailGenerator: (_) async => thumbnail.path,
  );
}

void _expectVideoAndThumbnail(_VideoUploadClient client, String category) {
  expect(client.request?.url.path, '/server-api/upload/file');
  expect(client.body, contains('name="file"'));
  expect(client.body, contains('name="thumbnail"'));
  expect(client.body, contains(category));
}

class _VideoUploadClient extends http.BaseClient {
  http.BaseRequest? request;
  String body = '';

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    this.request = request;
    body = latin1.decode(await request.finalize().toBytes());
    return http.StreamedResponse(
      Stream.value(
        utf8.encode(
          jsonEncode({
            'code': 0,
            'data': {
              'url': '/uploads/pet-video.mp4',
              'thumbnail': '/uploads/thumbnails/pet-video-cover.jpg',
            },
          }),
        ),
      ),
      200,
      headers: {'content-type': 'application/json'},
    );
  }
}
