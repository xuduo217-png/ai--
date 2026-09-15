import 'package:flutter_test/flutter_test.dart';
import 'package:pet_hospital_flutter/features/activity/domain/activity_models.dart';
import 'package:pet_hospital_flutter/features/activity/presentation/activity_controller.dart';

void main() {
  test('活动列表筛选、搜索、排序和分页保持当前条件', () async {
    final gateway = _ActivityGateway();
    final controller = ActivityListController(
      gateway: gateway,
      authenticated: false,
    );

    await controller.load();
    await controller.selectStatus(ActivityStatus.upcoming);
    await controller.search('领养');
    await controller.loadMore();

    expect(gateway.listCalls.last, (
      status: ActivityStatus.upcoming,
      keyword: '领养',
      page: 2,
    ));
    expect(controller.activities.map((item) => item.id), [8, 7]);
  });

  test('报名和投票成功后刷新活动详情', () async {
    final gateway = _ActivityGateway();
    final controller = ActivityDetailController(
      gateway: gateway,
      activityId: 7,
      authenticated: true,
    );

    await controller.load();
    await controller.register('13800138000');
    await controller.vote(11);

    expect(gateway.detailCalls, 3);
    expect(gateway.registeredPhone, '13800138000');
    expect(gateway.votedOptionId, 11);
    expect(controller.actionLoading, isFalse);
    expect(controller.votingOptionId, isNull);
  });

  test('删除选手交由上层退出详情后刷新', () async {
    final gateway = _ActivityGateway();
    final controller = ActivityDetailController(
      gateway: gateway,
      activityId: 7,
      authenticated: true,
    );

    await controller.load();
    final result = await controller.deleteVoteOption(11);

    expect(result.success, isTrue);
    expect(gateway.deletedOptionId, 11);
    expect(gateway.detailCalls, 1);
    expect(controller.actionLoading, isFalse);
  });

  test('活动评论支持回复提交并刷新列表', () async {
    final gateway = _ActivityGateway();
    final controller = ActivityCommentsController(
      gateway: gateway,
      activityId: 7,
      authenticated: true,
      voteOptionId: 11,
    );

    await controller.load();
    await controller.submit('加油', parentId: 21);

    expect(gateway.createdComment, (content: '加油', parentId: 21));
    expect(gateway.commentLoads, 2);
    expect(controller.submitting, isFalse);
  });
}

class _ActivityGateway implements ActivityGateway {
  final listCalls = <({ActivityStatus status, String keyword, int page})>[];
  int detailCalls = 0;
  int commentLoads = 0;
  String? registeredPhone;
  int? votedOptionId;
  int? deletedOptionId;
  ({String content, int? parentId})? createdComment;

  @override
  Future<ActivityPage> loadActivities({
    required bool authenticated,
    required ActivityStatus status,
    String keyword = '',
    int page = 1,
    int pageSize = 10,
  }) async {
    listCalls.add((status: status, keyword: keyword, page: page));
    return ActivityPage(
      items: page == 1
          ? [_activity]
          : [_activity, _activityWith(id: 8, daysLater: 2)],
      total: 2,
      page: page,
      pageSize: pageSize,
      totalPages: 2,
    );
  }

  @override
  Future<ActivityItem> loadActivityDetail(
    int activityId, {
    required bool authenticated,
  }) async {
    detailCalls += 1;
    return _activity;
  }

  @override
  Future<ActivityActionResult<void>> registerActivity(
    int activityId, {
    required String phone,
  }) async {
    registeredPhone = phone;
    return const ActivityActionResult(success: true, message: '报名成功');
  }

  @override
  Future<ActivityActionResult<void>> voteActivity(
    int activityId, {
    required int optionId,
  }) async {
    votedOptionId = optionId;
    return const ActivityActionResult(success: true, message: '投票成功');
  }

  @override
  Future<ActivityActionResult<void>> deleteActivityVoteOption(
    int activityId,
    int optionId,
  ) async {
    deletedOptionId = optionId;
    return const ActivityActionResult(success: true, message: '删除成功');
  }

  @override
  Future<ActivityCommentPage> loadActivityComments(
    int activityId, {
    required bool authenticated,
    int? voteOptionId,
    int page = 1,
    int pageSize = 20,
  }) async {
    commentLoads += 1;
    return ActivityCommentPage(
      items: const [_comment],
      total: 1,
      page: page,
      pageSize: pageSize,
      totalPages: 1,
    );
  }

  @override
  Future<ActivityComment> createActivityComment(
    int activityId, {
    required String content,
    int? voteOptionId,
    int? parentId,
  }) async {
    createdComment = (content: content, parentId: parentId);
    return _comment;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final _now = DateTime(2026, 7, 25);

final _activity = ActivityItem(
  id: 7,
  title: '领养开放日',
  startTime: _now,
  endTime: _now.add(const Duration(days: 1)),
  location: '谷德宠物医院',
  summary: '欢迎参与',
  description: '<p>活动详情</p>',
  coverImageUrl: '',
  sharePosterImageUrl: '',
  sharePosterTitle: '',
  sharePosterDescription: '',
  hospitalId: 1,
  hospitalName: '谷德宠物医院',
  registrationCount: 3,
  status: ActivityStatus.upcoming,
  activityType: ActivityType.offline,
  voteOptions: const [],
  isRegistered: false,
  canRegister: true,
  createdAt: _now,
  updatedAt: _now,
);

ActivityItem _activityWith({required int id, required int daysLater}) {
  final date = _now.add(Duration(days: daysLater));
  return ActivityItem(
    id: id,
    title: '第二个活动',
    startTime: date,
    endTime: date,
    location: _activity.location,
    summary: _activity.summary,
    description: _activity.description,
    coverImageUrl: '',
    sharePosterImageUrl: '',
    sharePosterTitle: '',
    sharePosterDescription: '',
    hospitalId: 1,
    hospitalName: _activity.hospitalName,
    registrationCount: 0,
    status: ActivityStatus.upcoming,
    activityType: ActivityType.offline,
    voteOptions: const [],
    isRegistered: false,
    canRegister: true,
    createdAt: date,
    updatedAt: date,
  );
}

const _comment = ActivityComment(
  id: 21,
  activityId: 7,
  userId: 8,
  content: '支持',
  likeCount: 0,
  createdAt: null,
  replies: [],
);
