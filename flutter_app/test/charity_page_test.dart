import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pet_hospital_flutter/core/media/rich_text_video_player.dart';
import 'package:pet_hospital_flutter/features/charity/domain/charity_models.dart';
import 'package:pet_hospital_flutter/features/charity/presentation/charity_list_page.dart';
import 'package:pet_hospital_flutter/features/charity/presentation/charity_widgets.dart';
import 'package:pet_hospital_flutter/features/mall/payment/domain/payment_models.dart';

void main() {
  testWidgets('公益列表保留 RN 视觉结构并可进入详情', (tester) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final gateway = _PageCharityGateway();

    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: MediaQueryData.fromView(
            tester.view,
          ).copyWith(textScaler: const TextScaler.linear(1.15)),
          child: CharityListPage(
            gateway: gateway,
            authenticated: true,
            requestLogin: (_) async => false,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('charity-gradient-background')),
      findsOneWidget,
    );
    expect(find.text('公益中心'), findsOneWidget);
    expect(find.text('进行中'), findsWidgets);
    expect(find.text('已结束'), findsOneWidget);
    expect(find.text('全部'), findsOneWidget);
    expect(find.text('流浪动物救助'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byKey(const ValueKey('charity-card-7')));
    await tester.pumpAndSettle();

    expect(find.text('公益详情'), findsNWidgets(2));
    expect(
      find.byKey(const ValueKey('charity-donation-summary')),
      findsOneWidget,
    );
    expect(find.text('捐款明细'), findsOneWidget);
    expect(find.text('立即捐款'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('余额捐款面板校验金额并完成捐款后刷新详情', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final gateway = _PageCharityGateway();
    final paymentGateway = _PagePaymentGateway();

    await tester.pumpWidget(
      MaterialApp(
        home: CharityListPage(
          gateway: gateway,
          paymentGateway: paymentGateway,
          authenticated: true,
          requestLogin: (_) async => false,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('charity-card-7')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('charity-primary-action')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('charity-donation-sheet')),
      findsOneWidget,
    );
    await tester.enterText(
      find.byKey(const ValueKey('charity-donation-amount')),
      '12.345',
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('charity-donation-amount')),
        matching: find.text('12.34'),
      ),
      findsOneWidget,
    );
    final confirm = find.byKey(const ValueKey('charity-donation-confirm'));
    await tester.ensureVisible(confirm);
    await tester.tap(confirm);
    await tester.pumpAndSettle();

    expect(find.text('选择支付方式'), findsOneWidget);
    expect(find.text('支付宝 App 安全支付'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('payment-method-balance')));
    await tester.pump();
    await tester.tap(find.text('确认支付 ¥12.34'));
    await tester.pumpAndSettle();

    expect(gateway.donatedAmounts, [12.34]);
    expect(find.text('感谢您的爱心'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('捐款面板随软键盘整体上移', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);

    await tester.pumpWidget(
      MaterialApp(
        home: CharityListPage(
          gateway: _PageCharityGateway(),
          authenticated: true,
          requestLogin: (_) async => false,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('charity-card-7')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('charity-primary-action')));
    await tester.pumpAndSettle();

    final sheet = find.byKey(const ValueKey('charity-donation-sheet'));
    final initialRect = tester.getRect(sheet);
    await tester.tap(find.byKey(const ValueKey('charity-donation-amount')));
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    final keyboardInset = tester.widget<AnimatedPadding>(
      find.byKey(const ValueKey('charity-donation-keyboard-inset')),
    );
    final keyboardRect = tester.getRect(sheet);
    expect(keyboardInset.padding, const EdgeInsets.only(bottom: 300));
    expect(keyboardRect.bottom, closeTo(initialRect.bottom - 300, 0.1));
    expect(keyboardRect.height, closeTo(initialRect.height, 0.1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('余额加载失败时提示重试而不是显示零余额', (tester) async {
    final gateway = _PageCharityGateway(walletBalanceFailures: 1);

    await tester.pumpWidget(
      MaterialApp(
        home: CharityListPage(
          gateway: gateway,
          paymentGateway: _PagePaymentGateway(),
          authenticated: true,
          requestLogin: (_) async => false,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('charity-card-7')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('charity-primary-action')));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('charity-donation-amount')),
      '12',
    );
    await tester.tap(find.byKey(const ValueKey('charity-donation-confirm')));
    await tester.pumpAndSettle();

    expect(find.text('余额加载失败，点击重试'), findsOneWidget);
    expect(find.text('可用余额 ¥0.00'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('payment-method-balance')));
    await tester.pumpAndSettle();

    expect(find.text('可用余额 ¥88.60'), findsOneWidget);
  });

  testWidgets('访客浏览公益但操作时请求登录', (tester) async {
    var requestedMessage = '';
    await tester.pumpWidget(
      MaterialApp(
        home: CharityListPage(
          gateway: _PageCharityGateway(),
          authenticated: false,
          requestLogin: (message) async {
            requestedMessage = message;
            return false;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('charity-card-7')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('charity-primary-action')));
    await tester.pump();

    expect(requestedMessage, '登录后即可参与捐款');
    expect(find.byKey(const ValueKey('charity-donation-sheet')), findsNothing);
  });

  testWidgets('商城自动公益隐藏主动捐款入口并展示退款冲销', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: CharityListPage(
          gateway: _PageCharityGateway(autoDonation: true),
          authenticated: true,
          requestLogin: (_) async => false,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('charity-card-7')));
    await tester.pumpAndSettle();

    expect(find.text('商城公益流水'), findsOneWidget);
    await tester.drag(
      find.byKey(const ValueKey('charity-detail-scroll')),
      const Offset(0, -320),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('消费公益'), findsOneWidget);
    expect(find.textContaining('退款冲销'), findsOneWidget);
    expect(find.text('+¥1.50'), findsOneWidget);
    expect(find.text('-¥0.75'), findsOneWidget);
    expect(find.byKey(const ValueKey('charity-primary-action')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('公益详情可识别 wangEditor 富文本视频节点', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: CharityRichContent(
            baseUrl: 'https://api.example.com',
            content:
                '<div data-w-e-type="video" data-w-e-is-void>'
                '<video poster="" controls="true">'
                '<source src="/uploads/charity.mov" type="video/mp4"/>'
                '</video></div>',
          ),
        ),
      ),
    );
    await tester.pump();

    final video = find.byKey(const ValueKey('charity-rich-video-0'));
    expect(video, findsOneWidget);
    expect(
      tester.widget<Semantics>(video).properties.value,
      'https://gdcw-1386217335.cos.ap-chengdu.myqcloud.com/uploads/charity.mov',
    );
    expect(
      tester
          .widget<RichTextVideoPlayer>(
            find.byKey(const ValueKey('charity-rich-video-state-0')),
          )
          .autoPlayWhenVisible,
      isTrue,
    );
    expect(find.text('视频地址无效'), findsNothing);
  });

  testWidgets('公益详情对不安全的视频地址显示明确占位', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: CharityRichContent(
            content:
                '<video controls="true">'
                '<source src="javascript:alert(1)" type="video/mp4"/>'
                '</video>',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('charity-rich-video-unavailable-0')),
      findsOneWidget,
    );
    expect(find.text('视频地址无效'), findsOneWidget);
  });
}

class _PageCharityGateway implements CharityGateway {
  _PageCharityGateway({
    this.walletBalanceFailures = 0,
    this.autoDonation = false,
  });

  final int walletBalanceFailures;
  final bool autoDonation;
  final donatedAmounts = <double>[];
  double donatedTotal = 100;
  int walletBalanceLoads = 0;

  CharityActivity get activity => CharityActivity(
    id: 7,
    title: '流浪动物救助',
    description: '为流浪动物提供医疗和食物支持。',
    details: '<p>每一份帮助都很重要。</p>',
    coverImageUrl: '',
    startTime: DateTime(2026, 7, 1),
    endTime: DateTime(2026, 8, 1),
    targetCheckIns: 0,
    completedCheckIns: 0,
    donatedAmount: donatedTotal,
    participantType: CharityParticipantType.donation,
    status: CharityStatus.active,
    hasCheckedToday: false,
    isMallAutoDonation: autoDonation,
    donationRate: autoDonation ? 1.5 : 0,
    isPinned: autoDonation,
  );

  @override
  Future<CharityPage> loadCharities({
    required bool authenticated,
    CharityStatus? status,
    String keyword = '',
    int page = 1,
    int pageSize = 10,
  }) async => CharityPage(
    items: [activity],
    total: 1,
    page: 1,
    pageSize: pageSize,
    totalPages: 1,
  );

  @override
  Future<CharityActivity> loadCharityDetail(
    int charityId, {
    required bool authenticated,
  }) async => activity;

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
  }) async => CharityRecordPage(
    items: autoDonation
        ? [
            CharityRecord(
              id: 1,
              charityId: charityId,
              userId: 1,
              checkInTime: DateTime(2026, 7, 10, 10),
              donationAmount: 1.5,
              userName: '张三',
              userAvatarUrl: '',
              donationSource: 'mall_order',
              donationEntryType: 'credit',
              orderNo: 'ORD2026071001',
              donationBaseAmount: 100,
              donationRate: 1.5,
            ),
            CharityRecord(
              id: 2,
              charityId: charityId,
              userId: 1,
              checkInTime: DateTime(2026, 7, 11, 10),
              donationAmount: -0.75,
              userName: '张三',
              userAvatarUrl: '',
              donationSource: 'mall_order',
              donationEntryType: 'reversal',
              orderNo: 'ORD2026071001',
              donationBaseAmount: 50,
              donationRate: 1.5,
            ),
          ]
        : const [],
    total: autoDonation ? 2 : 0,
    page: page,
    pageSize: pageSize,
    totalPages: autoDonation ? 1 : 0,
  );

  @override
  Future<CharityCheckInResult> checkInCharity(int charityId) async {
    throw UnimplementedError();
  }

  @override
  Future<double> loadCharityWalletBalance() async {
    walletBalanceLoads += 1;
    if (walletBalanceLoads <= walletBalanceFailures) {
      throw StateError('wallet unavailable');
    }
    return 88.6;
  }

  @override
  Future<CharityDonationResult> donateCharity(
    int charityId, {
    required double amount,
  }) async {
    donatedAmounts.add(amount);
    donatedTotal += amount;
    return CharityDonationResult(
      message: '感谢您的爱心',
      donationAmount: amount,
      donatedAmount: donatedTotal,
      balanceBefore: 88.6,
      balanceAfter: 88.6 - amount,
    );
  }

  @override
  Future<CharityDonationPayment> createCharityDonationPayment(
    int charityId, {
    required double amount,
    required String idempotencyKey,
  }) async => CharityDonationPayment(
    paymentNo: 'PAY_CHARITY_1',
    amount: amount,
    alipayOrderString: 'alipay-order-string',
  );

  @override
  Future<CharityDonationPaymentStatus> loadCharityDonationPaymentStatus(
    String paymentNo,
  ) async => CharityDonationPaymentStatus.success;
}

class _PagePaymentGateway implements PaymentGateway {
  @override
  Future<PaymentSdkResult> pay(String orderInfo) async =>
      const PaymentSdkResult(status: PaymentSdkStatus.success);
}
