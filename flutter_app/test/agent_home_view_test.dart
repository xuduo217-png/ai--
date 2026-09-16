import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pet_hospital_flutter/features/agent/presentation/agent_home_view.dart';

void main() {
  testWidgets('agent home exposes the reused business entry points', (
    tester,
  ) async {
    var healthOpened = false;
    var shopOpened = false;
    var appointmentOpened = false;
    var communityOpened = false;
    String? submittedPrompt;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AgentHomeView(
            petName: '团团',
            onPrompt: (value) => submittedPrompt = value,
            onHealth: () => healthOpened = true,
            onShop: () => shopOpened = true,
            onAppointment: () => appointmentOpened = true,
            onCommunity: () => communityOpened = true,
          ),
        ),
      ),
    );

    expect(find.text('你好，我是小谷'), findsOneWidget);
    expect(find.text('已连接团团的健康档案'), findsOneWidget);

    await tester.tap(find.text('团团有点不舒服'));
    await tester.tap(find.text('帮团团挑选商品'));
    await tester.tap(find.text('预约医生或疫苗'));
    await tester.tap(find.text('看看附近宠友'));

    expect(healthOpened, isTrue);
    expect(shopOpened, isTrue);
    expect(appointmentOpened, isTrue);
    expect(communityOpened, isTrue);

    await tester.enterText(find.byType(TextField), '打开商城');
    await tester.testTextInput.receiveAction(TextInputAction.send);
    await tester.pump();

    expect(submittedPrompt, '打开商城');
  });
}
