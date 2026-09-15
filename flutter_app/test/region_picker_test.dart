import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pet_hospital_flutter/features/mall/address/domain/region_models.dart';
import 'package:pet_hospital_flutter/features/mall/address/presentation/widgets/region_picker.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('RegionPickerData', () {
    test('生成省市区三级树并恢复已有选择', () {
      final pickerData = RegionPickerData(_regionData);
      final selection = pickerData.selectionFor(_guangdongValue);

      expect(selection.map((item) => item.code), [
        '440000',
        '440100',
        '440106',
      ]);
      expect(pickerData.valueFor(selection).displayName, '广东省 广州市 天河区');
    });

    test('将港澳两级数据标准化为三列且保留原始区级编码', () {
      final pickerData = RegionPickerData(_regionData);
      final hongKong = pickerData.tree.entries.firstWhere(
        (entry) => entry.key.code == '810000',
      );
      final virtualCity = hongKong.value.entries.single;

      expect(virtualCity.key.code, '810000');
      expect(virtualCity.key.name, '香港特别行政区');
      expect(virtualCity.value.map((item) => item.code), ['810001', '810002']);

      final value = pickerData.valueFor([
        hongKong.key,
        virtualCity.key,
        virtualCity.value.first,
      ]);
      expect(value.provinceCode, '810000');
      expect(value.cityCode, '810000');
      expect(value.districtCode, '810001');
      expect(value.displayName, '香港特别行政区 中西區');
    });
  });

  testWidgets('地区选择器显示三列滚轮并回填当前地址', (tester) async {
    RegionValue? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 52,
            child: RegionPicker(
              value: _guangdongValue,
              onChanged: (value) => result = value,
            ),
          ),
        ),
      ),
    );
    await _waitForRegionPicker(tester);

    await tester.tap(find.byKey(const ValueKey('address-region-picker')));
    await tester.pumpAndSettle();

    expect(find.byType(CupertinoPicker), findsNWidgets(3));
    expect(find.text('广东省'), findsOneWidget);
    expect(find.text('广州市'), findsOneWidget);
    expect(find.text('天河区'), findsOneWidget);

    await tester.tap(find.text('确定'));
    await tester.pumpAndSettle();

    expect(result?.provinceCode, '440000');
    expect(result?.cityCode, '440100');
    expect(result?.districtCode, '440106');
    expect(tester.takeException(), isNull);
  });
}

Future<void> _waitForRegionPicker(WidgetTester tester) async {
  final finder = find.byKey(const ValueKey('address-region-picker'));
  for (var attempt = 0; attempt < 200; attempt++) {
    await tester.pump();
    if (tester.widget<InkWell>(finder).onTap != null) return;
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    });
  }
  fail('地区数据未在 2 秒内加载完成');
}

const _guangdongValue = RegionValue(
  provinceCode: '440000',
  provinceName: '广东省',
  cityCode: '440100',
  cityName: '广州市',
  districtCode: '440106',
  districtName: '天河区',
);

const _regionData = RegionData({
  '86': {'440000': '广东省', '810000': '香港特别行政区'},
  '440000': {'440100': '广州市'},
  '440100': {'440106': '天河区'},
  '810000': {'810001': '中西區', '810002': '湾仔区'},
});
