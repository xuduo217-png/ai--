import 'package:flutter_test/flutter_test.dart';
import 'package:pet_hospital_flutter/features/charity/domain/charity_models.dart';
import 'package:pet_hospital_flutter/features/charity/presentation/charity_controller.dart';

void main() {
  test('公益列表筛选、搜索和分页使用当前条件并去重', () async {
    final gateway = _CharityGateway();
    final controller = CharityListController(
      gateway: gateway,
      authenticated: false,
    );

    await controller.load();
    await controller.selectFilter(CharityListFilter.all);
    await controller.search('救助');
    await controller.loadMore();

    expect(gateway.listCalls.last, (status: null, keyword: '救助', page: 2));
    expect(controller.activities.map((item) => item.id), [7, 8]);
  });

  test('签到成功后刷新详情和参与记录', () async {
    final gateway = _CharityGateway();
    final controller = CharityDetailController(
      gateway: gateway,
      charityId: 7,
      authenticated: true,
    );

    await controller.load();
    expect(controller.activity?.hasCheckedToday, isFalse);

    await controller.checkIn();

    expect(controller.activity?.hasCheckedToday, isTrue);
    expect(gateway.detailCalls, 2);
    expect(controller.actionLoading, isFalse);
  });
}

class _CharityGateway implements CharityGateway {
  final listCalls = <({CharityStatus? status, String keyword, int page})>[];
  int detailCalls = 0;
  bool checked = false;

  @override
  Future<CharityPage> loadCharities({
    required bool authenticated,
    CharityStatus? status,
    String keyword = '',
    int page = 1,
    int pageSize = 10,
  }) async {
    listCalls.add((status: status, keyword: keyword, page: page));
    return CharityPage(
      items: page == 1
          ? [_activity]
          : [_activity, _activityWith(id: 8, title: '第二个公益')],
      total: 2,
      page: page,
      pageSize: pageSize,
      totalPages: 2,
    );
  }

  @override
  Future<CharityActivity> loadCharityDetail(
    int charityId, {
    required bool authenticated,
  }) async {
    detailCalls += 1;
    return _activityWith(hasCheckedToday: checked);
  }

  @override
  Future<CharityRecordPage> loadCharityRecords(
    int charityId, {
    int page = 1,
    int pageSize = 10,
  }) async => CharityRecordPage(
    items: const [],
    total: 0,
    page: page,
    pageSize: pageSize,
    totalPages: 0,
  );

  @override
  Future<CharityRecordPage> loadCharityDonations(
    int charityId, {
    required bool authenticated,
    int page = 1,
    int pageSize = 10,
  }) => loadCharityRecords(charityId, page: page, pageSize: pageSize);

  @override
  Future<CharityCheckInResult> checkInCharity(int charityId) async {
    checked = true;
    return const CharityCheckInResult(
      success: true,
      alreadyChecked: false,
      totalCheckIns: 1,
      message: '签到成功',
      isCompleted: false,
    );
  }

  @override
  Future<double> loadCharityWalletBalance() async => 100;

  @override
  Future<CharityDonationResult> donateCharity(
    int charityId, {
    required double amount,
  }) async => CharityDonationResult(
    message: '捐款成功',
    donationAmount: amount,
    donatedAmount: amount,
    balanceBefore: 100,
    balanceAfter: 100 - amount,
  );

  @override
  Future<CharityDonationPayment> createCharityDonationPayment(
    int charityId, {
    required double amount,
    required String idempotencyKey,
  }) => throw UnimplementedError();

  @override
  Future<CharityDonationPaymentStatus> loadCharityDonationPaymentStatus(
    String paymentNo,
  ) => throw UnimplementedError();
}

const _activity = CharityActivity(
  id: 7,
  title: '公益打卡',
  description: '每天打卡传递爱心',
  details: '',
  coverImageUrl: '',
  targetCheckIns: 10,
  completedCheckIns: 1,
  donatedAmount: 0,
  participantType: CharityParticipantType.checkIn,
  status: CharityStatus.active,
  hasCheckedToday: false,
);

CharityActivity _activityWith({
  int id = 7,
  String title = '公益打卡',
  bool hasCheckedToday = false,
}) {
  return CharityActivity(
    id: id,
    title: title,
    description: _activity.description,
    details: _activity.details,
    coverImageUrl: _activity.coverImageUrl,
    targetCheckIns: _activity.targetCheckIns,
    completedCheckIns: _activity.completedCheckIns,
    donatedAmount: _activity.donatedAmount,
    participantType: _activity.participantType,
    status: _activity.status,
    hasCheckedToday: hasCheckedToday,
  );
}
